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
          @indices[byteindex]
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
          @to_s ||= "<#{event} #{body.map(&:to_s).join(" ")}>"
        end
      end

      attr_reader :line_counts, :patterns

      def initialize(source)
        super(source)

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

        @patterns = []
      end

      def self.erase(source)
        parser = new(source)

        if parser.parse.nil? || parser.error?
          raise "Invalid source"
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

      # Loop through all of the scanner events and define a basic method that
      # wraps everything into a node class.
      SCANNER_EVENTS.each do |event|
        define_method(:"on_#{event}") do |value|
          range = loc.then { |start| start..(start + (value&.size || 0)) }
          Node.new(:"@#{event}", [value], range)
        end
      end

      # Loop through the parser events and generate a method for each event. If
      # it's one of the _new methods, then use arrays like SexpBuilderPP. If
      # it's an _add method then just append to the array. If it's a normal
      # method, then create a new node and determine its bounds.
      PARSER_EVENT_TABLE.each do |event, arity|
        case event
        when /\A(.+)_new\z/
          prefix = $1.to_sym

          define_method(:"on_#{event}") do
            Node.new(prefix, [], loc.then { |start| start..start })
          end
        when /_add\z/
          define_method(:"on_#{event}") do |node, value|
            range =
              if node.body.empty?
                value.range
              else
                (node.range.begin..value.range.end)
              end

            node.class.new(node.event, node.body + [value], range)
          end
        else
          define_method(:"on_#{event}") do |*args|
            first, *, last = args.grep(Node).map(&:range)

            first ||= loc.then { |start| start..start }
            last ||= first

            Node.new(event, args, first.begin..[last.end, loc].max)
          end
        end
      end
    end
  end
end
