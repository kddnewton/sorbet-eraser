# frozen_string_literal: true

module Sorbet
  module Eraser
    # A Ripper parser that will replace usage of Sorbet patterns with whitespace
    # so that location information is maintained but Sorbet methods aren't
    # called.
    class Parser < Ripper
      # Represents a line in the source. If this class is being used, it means
      # that every character in the string is 1 byte in length, so we can just
      # return the start of the line + the index.
      class SingleByteString
        def initialize(start)
          @start = start
        end

        def [](byteindex)
          @start + byteindex
        end
      end

      # Represents a line in the source. If this class is being used, it means
      # that there are characters in the string that are multi-byte, so we will
      # build up an array of indices, such that array[byteindex] will be equal
      # to the index of the character within the string.
      class MultiByteString
        def initialize(start, line)
          @indices = []

          line
            .each_char
            .with_index(start) do |char, index|
              char.bytesize.times { @indices << index }
            end
        end

        def [](byteindex)
          # Why the || byteindex? I'm not sure. For some reason ripper is
          # returning very odd column values when you have a multibyte line.
          # This is the only way I could find to make it work.
          @indices[byteindex] || byteindex
        end
      end

      # Represents a node in the AST. Keeps track of the event that generated
      # it, any child nodes that descend from it, and the location in the
      # source.
      class Node
        attr_reader :event, :body, :range

        def initialize(event, body, range)
          @event = event
          @body = body
          @range = range
        end

        def match?(pattern)
          to_s.match?(pattern)
        end

        def to_s
          @to_s ||= "<#{event} #{body.map { |child| child.is_a?(Array) ? child.map(&:to_s) : child.to_s }.join(" ")}>"
        end
      end

      # Raised in the case that source can't be parsed.
      class ParsingError < StandardError
      end

      attr_reader :source, :line_counts, :errors, :patterns

      def initialize(source)
        super(source)

        @source = source
        @line_counts = []
        last_index = 0

        source.lines.each do |line|
          if line.size == line.bytesize
            @line_counts << SingleByteString.new(last_index)
          else
            @line_counts << MultiByteString.new(last_index, line)
          end

          last_index += line.size
        end

        @errors = []
        @patterns = []
      end

      def self.erase(source)
        parser = new(source)

        if parser.parse.nil? || parser.error?
          raise ParsingError, parser.errors.join("\n")
        else
          parser.patterns.inject(source) do |current, pattern|
            pattern.erase(current)
          end
        end
      end

      private

      def loc
        line_counts[lineno - 1][column]
      end

      def find_loc(args)
        ranges = []

        args.each do |arg|
          case arg
          when Node
            ranges << arg.range if arg.range
          when Array
            ranges << find_loc(arg)
          end
        end

        case ranges.length
        when 0
          nil
        when 1
          ranges.first
        else
          ranges.first.begin...ranges.last.end
        end
      end

      # Loop through all of the scanner events and define a basic method that
      # wraps everything into a node class.
      SCANNER_EVENTS.each do |event|
        define_method(:"on_#{event}") do |value|
          range = loc.then { |start| start...(start + (value&.size || 0)) }
          Node.new(:"@#{event}", [value], range)
        end
      end

      # Loop through the parser events and generate a method for each event. If
      # it's one of the _new methods, then use arrays like SexpBuilderPP. If
      # it's an _add method then just append to the array. If it's a normal
      # method, then create a new node and determine its bounds.
      PARSER_EVENT_TABLE.each do |event, arity|
        next if %i[aref arg_paren].include?(event)

        if event =~ /\A(.+)_new\z/ && event != :assoc_new
          prefix = $1.to_sym

          define_method(:"on_#{event}") do
            Node.new(prefix, [], nil)
          end
        elsif event =~ /_add\z/
          define_method(:"on_#{event}") do |node, value|
            range =
              if node.body.empty?
                value.range
              else
                (node.range.begin...value.range.end)
              end

            node.class.new(node.event, node.body + [value], range)
          end
        elsif event == :parse_error
          # skip this, as we're going to define it below
        else
          define_method(:"on_#{event}") do |*args|
            Node.new(event, args, find_loc(args))
          end
        end
      end

      # Better location information for aref.
      def on_aref(recv, arg)
        rend = arg.range.end + source[arg.range.end..].index("]") + 1
        Node.new(:aref, [recv, arg], recv.range.begin...rend)
      end

      # Better location information for arg_paren.
      def on_arg_paren(arg)
        rbegin = source[..arg.range.begin].rindex("(")
        rend = arg.range.end + source[arg.range.end..].index(")") + 1
        Node.new(:arg_paren, [arg], rbegin...rend)
      end

      # Track the parsing errors for nicer error messages.
      def on_parse_error(error)
        errors << "line #{lineno}: #{error}"
      end
    end
  end
end
