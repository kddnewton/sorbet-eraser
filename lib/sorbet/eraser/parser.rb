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
          @repr ||= begin
            children = body.map { |child| child.is_a?(Array) ? child.map(&:to_s) : child }
            "<#{event} #{children.join(" ")}>"
          end
        end
      end

      # Raised in the case that source can't be parsed.
      class ParsingError < StandardError
      end

      attr_reader :source, :line_counts, :errors, :patterns, :heredocs

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

          last_index += line.bytesize
        end

        @errors = []
        @patterns = []
        @heredocs = []
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

      # Better location information for aref.
      def on_aref(recv, arg)
        rend = arg.range.end + source.byteslice(arg.range.end..).index("]") + 1
        Node.new(:aref, [recv, arg], recv.range.begin...rend)
      end

      # Better location information for arg_paren.
      def on_arg_paren(arg)
        if arg
          rbegin = source.byteslice(..arg.range.begin).rindex("(")
          rend = arg.range.end + source.byteslice(arg.range.end..).index(")") + 1
          Node.new(:arg_paren, [arg], rbegin...rend)
        else
          segment = source.byteslice(..loc)
          Node.new(:arg_paren, [arg], segment.rindex("(")...(segment.rindex(")") + 1))
        end
      end

      LISTS = { qsymbols: "%i", qwords: "%w", symbols: "%I", words: "%W" }.freeze
      TERMINATORS = { "[" => "]", "{" => "}", "(" => ")", "<" => ">" }.freeze

      # Better location information for array.
      def on_array(arg)
        case arg&.event
        when nil
          segment = source.byteslice(..loc)
          Node.new(:array, [arg], segment.rindex("[")...(segment.rindex("]") + 1))
        when :qsymbols, :qwords, :symbols, :words
          rbegin = source.byteslice(...arg.range.begin).rindex(LISTS.fetch(arg.event))
          rend = source.byteslice(arg.range.end..).index(TERMINATORS.fetch(source.byteslice(rbegin + 2)) { source.byteslice(rbegin + 2) }) + arg.range.end + 1
          Node.new(:array, [arg], rbegin...rend)
        else
          Node.new(:array, [arg], arg.range)
        end
      end

      # Better location information for brace_block.
      def on_brace_block(params, body)
        if params || body.range
          rbegin = source.byteslice(...(params || body).range.begin).rindex("{")

          rend = body.range&.end || params.range.end
          rend = rend + source.byteslice(rend..).index("}") + 1

          Node.new(:brace_block, [params, body], rbegin...rend)
        else
          segment = source.byteslice(..loc)
          Node.new(:brace_block, [params, body], segment.rindex("{")...(segment.rindex("}") + 1))
        end
      end

      # Better location information for do_block.
      def on_do_block(params, body)
        if params || body.range
          rbegin = source.byteslice(...(params || body).range.begin).rindex("do")

          rend = body.range&.end || params.range.end
          rend = rend + source.byteslice(rend..).index("end") + 3

          Node.new(:do_block, [params, body], rbegin...rend)
        else
          segment = source.byteslice(..loc)
          Node.new(:do_block, [params, body], segment.rindex("do")...(segment.rindex("end") + 3))
        end
      end

      # Better location information for hash.
      def on_hash(arg)
        if arg
          Node.new(:hash, [arg], arg.range)
        else
          segment = source.byteslice(..loc)
          Node.new(:hash, [arg], segment.rindex("{")...(segment.rindex("}") + 1))
        end
      end

      # Track the open heredocs so we can replace the string literal ranges with
      # the range of their declarations.
      def on_heredoc_beg(value)
        range = loc.then { |start| start...(start + value.bytesize) }
        heredocs << [range, value, nil]

        Node.new(:@heredoc_beg, [value], range)
      end

      # If a heredoc ends, then the next string literal event will be the
      # heredoc.
      def on_heredoc_end(value)
        range = loc.then { |start| start...(start + value.bytesize) }
        heredocs.find { |(_, beg_arg, end_arg)| beg_arg.include?(value.strip) && end_arg.nil? }[2] = value

        Node.new(:@heredoc_end, [value], range)
      end

      # Track the parsing errors for nicer error messages.
      def on_parse_error(error)
        errors << "line #{lineno}: #{error}"
      end

      # Better location information for string_literal taking into account
      # heredocs.
      def on_string_literal(arg)
        if heredoc = heredocs.find { |(_, _, end_arg)| end_arg }
          Node.new(:string_literal, [arg], heredocs.delete(heredoc)[0])
        else
          Node.new(:string_literal, [arg], (arg.range.begin - 1)...(arg.range.end + 1))
        end
      end

      handled = private_instance_methods(false)

      # Loop through all of the scanner events and define a basic method that
      # wraps everything into a node class.
      SCANNER_EVENTS.each do |event|
        next if handled.include?(:"on_#{event}")

        define_method(:"on_#{event}") do |value|
          range = loc.then { |start| start...(start + (value&.bytesize || 0)) }
          Node.new(:"@#{event}", [value], range)
        end
      end

      # Loop through the parser events and generate a method for each event. If
      # it's one of the _new methods, then use arrays like SexpBuilderPP. If
      # it's an _add method then just append to the array. If it's a normal
      # method, then create a new node and determine its bounds.
      PARSER_EVENT_TABLE.each do |event, arity|
        next if handled.include?(:"on_#{event}")

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
              elsif node.range && value.range
                (node.range.begin...value.range.end)
              else
                node.range || value.range
              end

            node.class.new(node.event, node.body + [value], range)
          end
        else
          define_method(:"on_#{event}") do |*args|
            Node.new(event, args, find_loc(args))
          end
        end
      end
    end
  end
end
