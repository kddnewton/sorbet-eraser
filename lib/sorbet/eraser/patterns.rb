# frozen_string_literal: true

module Sorbet
  module Eraser
    module Patterns
      # A pattern in code that represents a call to a special Sorbet method.
      class Pattern
        attr_reader :range

        def initialize(range)
          @range = range
        end

        def erase(source)
          original = source[range]
          replaced = replace(original)

          # puts "Replacing #{original} (len=#{original.length}) " \
          #      "with #{replaced} (len=#{replaced.length})"

          source[range] = replaced
          source
        end

        def replace(segment)
          segment
        end
      end

      # T.must(foo)
      class TMustParensPattern < Pattern
        def replace(segment)
          segment.gsub(/(T\s*\.must\(\s*)(.+)(\s*\))(.*)/) do
            "#{" " * $1.length}#{$2}#{" " * $3.length}#{$4}"
          end
        end
      end

      # T.let(foo, bar)
      class TLetParensPattern < Pattern
        def replace(segment)
          segment.gsub(/(T\s*\.let\(\s*)(.+)(\s*,.+\))(.*)/) do
            "#{" " * $1.length}#{$2}#{" " * $3.length}#{$4}"
          end
        end
      end

      def on_method_add_arg(call, arg_paren)
        # T.must(foo)
        if call.match?("<call <var_ref <@const T>> <@period .> <@ident must>>") &&
          arg_paren.match?(/<arg_paren <args_add_block <args .+> false>>/)
          patterns << TMustParensPattern.new(call.range.begin..arg_paren.range.end)
        end

        # T.let(foo, bar)
        if call.match?("<call <var_ref <@const T>> <@period .> <@ident let>>") &&
          arg_paren.match?(/<arg_paren <args_add_block <args .+> false>>/)
          patterns << TLetParensPattern.new(call.range.begin..arg_paren.range.end)
        end

        super
      end

      # extend T::Sig
      class ExtendTSigPattern < Pattern
        def replace(segment)
          segment.gsub(/(extend\s+T::Sig)(.*)/) do
            "#{" " * $1.length}#{$2}"
          end
        end
      end

      def on_command(ident, args_add_block)
        # extend T::Sig
        if ident.match?("<@ident extend>") &&
          args_add_block.match?("<args_add_block <args <const_path_ref <var_ref <@const T>> <@const Sig>>> false>")
          patterns << ExtendTSigPattern.new(ident.range.begin..args_add_block.range.end)
        end

        super
      end

      # T.must foo
      class TMustNoParensPattern < Pattern
        def replace(segment)
          segment.gsub(/(T\s*\.must\s*)(.+)/) do
            "#{" " * $1.length}#{$2}"
          end
        end
      end

      def on_command_call(var_ref, period, ident, args_add_block)
        if var_ref.match?("<var_ref <@const T>>") && period.match?("<@period .>")
          # T.must foo
          if ident.match?("<@ident must>") &&
            args_add_block.match?(/<args_add_block <args <.+>> false>/) &&
            args_add_block.body[0].body.length == 1
            patterns << TMustNoParensPattern.new(var_ref.range.begin..args_add_block.range.end)
          end
        end

        super
      end

      # sig { foo }
      class SigBracesPattern < Pattern
        def replace(segment)
          segment.gsub(/(sig\s*\{.+\})(.*)/) do
            "#{" " * $1.length}#{$2}"
          end
        end
      end

      def on_stmts_add(node, value)
        # sig { foo }
        if value.match?(/<method_add_block <method_add_arg <fcall <@ident sig>> <args >> <brace_block  <stmts .+>>>/)
          patterns << SigBracesPattern.new(value.range)
        end

        super
      end
    end
  end
end
