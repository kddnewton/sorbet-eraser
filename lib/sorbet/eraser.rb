# frozen_string_literal: true

require "prism"

require "sorbet/eraser/version"
require "sorbet/eraser/t"

# Check if String#bytesplice is supported, and otherwise define it. If it is
# already defined but doesn't return the receiver, override it.
if !("".respond_to?(:bytesplice))
  require "sorbet/eraser/bytesplice"
elsif (+"aa").bytesplice(0, 1, "z") != "za"
  class String
    undef bytesplice
  end

  require "sorbet/eraser/bytesplice"
end

module Sorbet
  # This module contains the logic for erasing Sorbet type annotations from
  # Ruby source code.
  module Eraser
    # This class is a YARP visitor that finds the ranges of bytes that should be
    # erased from the source code.
    class Ranges < Prism::Visitor
      attr_reader :ranges

      def initialize(ranges)
        @ranges = ranges
      end

      def visit_call_node(node)
        case node.name
        when :abstract!, :final!, :interface!
          # abstract!
          # abstract!()
          # final!
          # final!()
          # interface!
          # interface!()
          if !node.receiver && !node.arguments && !node.block
            ranges << (node.location.start_offset...node.location.end_offset)
          end
        when :assert_type!, :bind, :cast, :let
          # T.assert_type! foo, String
          # T.assert_type!(foo, String)
          # T.bind self, String
          # T.bind(self, String)
          # T.cast foo, String
          # T.cast(foo, String)
          # T.let foo, String
          # T.let(foo, String)
          if node.receiver.is_a?(Prism::ConstantReadNode) && node.receiver.name == :T && (arguments = node.arguments&.arguments) && !node.block && arguments.length == 2
            if node.opening_loc
              ranges << (node.location.start_offset...node.opening_loc.start_offset)
              ranges << (arguments.first.location.end_offset...node.closing_loc.start_offset)
            else
              ranges << (node.location.start_offset...arguments.first.location.start_offset)
              ranges << (arguments.last.location.end_offset...node.location.end_offset)
            end
          end
        when :const, :prop
          # const :foo, String
          # const :foo, String, required: true
          # const(:foo, String)
          # const(:foo, String, required: true)
          # prop :foo, String
          # prop :foo, String, required: true
          # prop(:foo, String)
          # prop(:foo, String, required: true)
          if !node.receiver && (arguments = node.arguments) && !node.block
            arguments = arguments.arguments

            case arguments.length
            when 2
              ranges << (arguments[0].location.end_offset...arguments[1].location.end_offset)
            when 3
              ranges << (arguments[1].location.start_offset...arguments[2].location.start_offset)
            end
          end
        when :mixes_in_class_methods
          # mixes_in_class_methods Foo
          # mixes_in_class_methods(Foo)
          if !node.receiver && (arguments = node.arguments&.arguments) && !node.block && arguments.length == 1
            ranges << (node.location.start_offset...node.location.end_offset)
          end
        when :must, :reveal_type, :unsafe
          # T.must foo
          # T.must(foo)
          # T.reveal_type foo
          # T.reveal_type(foo)
          # T.unsafe foo
          # T.unsafe(foo)
          if (receiver = node.receiver).is_a?(Prism::ConstantReadNode) && receiver.name == :T && (arguments = node.arguments&.arguments) && !node.block && arguments.length == 1
            argument = arguments.first

            if node.opening_loc
              ranges << (node.location.start_offset...node.opening_loc.start_offset)
              ranges << (argument.location.end_offset...node.closing_loc.start_offset)
            else
              ranges << (node.location.start_offset...argument.location.start_offset)
              ranges << (argument.location.end_offset...node.location.end_offset)
            end
          end
        when :sig
          # sig { ... }
          # sig do ... end
          if !node.receiver && !node.arguments && node.block
            ranges << (node.location.start_offset...node.location.end_offset)
          end
        end

        super
      end
    end

    class << self
      # The is one of the two entrypoints to the module. This should be called
      # with a string that contains Ruby source. It returns the modified Ruby
      # source.
      def erase(source)
        erase_result(Prism.parse(source), source)
      end

      # This is one of the two entrypoints to the module. This should be called
      # with a filepath that points to a file that contains Ruby source. It
      # returns the modified Ruby source.
      def erase_file(filepath)
        erase_result(Prism.parse_file(filepath), File.read(filepath))
      end

      private

      # Accept a YARP::ParseResult and return a list of ranges that should be
      # erased from comments that contain typed sigils.
      def comment_ranges(result, ranges)
        first = result.value.statements.body.first
        minimum = first ? first.location.start_line : result.source.offsets.length

        result.comments.each do |comment|
          # Implicitly assuming that comments are in order.
          break if comment.location.start_line >= minimum

          if comment.is_a?(Prism::InlineComment) && comment.location.slice.match?(/\A#\s*typed:\s*(?:ignore|false|true|strict|strong)\s*\z/)
            ranges << ((comment.location.start_offset + 1)...comment.location.end_offset)
          end
        end
      end

      # Accept a YARP::ParseResult and return the modified Ruby source.
      def erase_result(result, source)
        ranges = []

        result.value.accept(Ranges.new(ranges))
        comment_ranges(result, ranges)

        ranges.inject(source) do |current, range|
          # This is deceptive in that it hides that it actually replaces
          # everything with spaces _except_ newline characters, which is keeps
          # in place.
          source.bytesplice(range, source.byteslice(range).gsub(/./, " "))
        end
      end
    end
  end
end
