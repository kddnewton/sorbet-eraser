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

      # T.absurd(foo) => raise ::Sorbet::Eraser::AbsurdError
      class TAbsurdParensPattern < Pattern
        def replace(segment)
          segment.gsub(/(T\s*\.absurd\(\s*.+\s*\))(.*)/) do
            replacement = "raise ::Sorbet::Eraser::AbsurdError"
            "#{replacement}#{" " * [$1.length - replacement.length, 0].max}#{$2}"
          end
        end
      end

      # T.must(foo) => foo
      # T.reveal_type(foo) => foo
      # T.unsafe(foo) => foo
      class TOneArgMethodCallParensPattern < Pattern
        def replace(segment)
          segment.gsub(/(T\s*\.(?:must|reveal_type|unsafe)\(\s*)(.+)(\s*\))(.*)/) do
            "#{" " * $1.length}#{$2}#{" " * $3.length}#{$4}"
          end
        end
      end

      # T.assert_type!(foo, bar) => foo
      # T.bind(self, foo) => self
      # T.cast(foo, bar) => foo
      # T.let(foo, bar) => let
      class TTwoArgMethodCallParensPattern < Pattern
        def replace(segment)
          segment.gsub(/(T\s*\.(?:assert_type!|bind|cast|let)\(\s*)(.+)(\s*,.+\))(.*)/) do
            "#{" " * $1.length}#{$2}#{" " * $3.length}#{$4}"
          end
        end
      end

      # abstract! =>
      # final! =>
      # interface! =>
      class DeclarationPattern < Pattern
        def replace(segment)
          segment.gsub(/((?:abstract|final|interface)!(?:\(\s*\))?)(.*)/) do
            "#{" " * $1.length}#{$2}"
          end
        end
      end

      def on_method_add_arg(call, arg_paren)
        # T.absurd(foo)
        if call.match?(/<call <var_ref <@const T>> <@period \.> <@ident absurd>>/) &&
          arg_paren.match?(/<arg_paren <args_add_block <args .+> false>>/)
          patterns << TAbsurdParensPattern.new(call.range.begin..arg_paren.range.end)
        end

        # T.must(foo)
        # T.reveal_type(foo)
        # T.unsafe(foo)
        if call.match?(/<call <var_ref <@const T>> <@period \.> <@ident (?:must|reveal_type|unsafe)>>/) &&
          arg_paren.match?(/<arg_paren <args_add_block <args .+> false>>/)
          patterns << TOneArgMethodCallParensPattern.new(call.range.begin..arg_paren.range.end)
        end

        # T.assert_type!(foo, bar)
        # T.cast(foo, bar)
        # T.let(foo, bar)
        if call.match?(/<call <var_ref <@const T>> <@period \.> <@ident (?:assert_type!|cast|let)>>/) &&
          arg_paren.match?(/<arg_paren <args_add_block <args .+> false>>/)
          patterns << TTwoArgMethodCallParensPattern.new(call.range.begin..arg_paren.range.end)
        end

        # T.bind(self, foo)
        if call.match?(/<call <var_ref <@const T>> <@period \.> <@ident bind>>/) &&
          arg_paren.match?(/<arg_paren <args_add_block <args <var_ref <@kw self>> .+> false>>/)
          patterns << TTwoArgMethodCallParensPattern.new(call.range.begin..arg_paren.range.end)
        end

        # abstract!
        # final!
        # interface!
        if call.match?(/<fcall <@ident (?:abstract|final|interface)!>>/) &&
          arg_paren.match?("<args >")
          patterns << DeclarationPattern.new(call.range.begin..arg_paren.range.end)
        end

        super
      end

      # T.type_alias { foo } => ::Sorbet::Eraser::TypeAlias
      class TTypeAliasBraceBlockPattern < Pattern
        def replace(segment)
          segment.gsub(/(T\s*\.type_alias\s*\{.*\})(.*)/) do
            replacement = "::Sorbet::Eraser::TypeAlias"
            "#{replacement}#{" " * [$1.length - replacement.length, 0].max}#{$2}"
          end
        end
      end

      def on_method_add_block(method_add_arg, block)
        # T.type_alias { foo }
        if method_add_arg.match?("<call <var_ref <@const T>> <@period .> <@ident type_alias>>") &&
          block.match?(/<brace_block  <stmts .+>>/)
          patterns << TTypeAliasBraceBlockPattern.new(method_add_arg.range.begin..block.range.end)
        end

        super
      end

      # include T::Generic =>
      # include T::Helpers =>
      class IncludeTModulePattern < Pattern
        def replace(segment)
          segment.gsub(/(include\s+T::(?:Generic|Helpers))(.*)/) do
            "#{" " * $1.length}#{$2}"
          end
        end
      end

      # extend T::Sig =>
      class ExtendTSigPattern < Pattern
        def replace(segment)
          segment.gsub(/(extend\s+T::Sig)(.*)/) do
            "#{" " * $1.length}#{$2}"
          end
        end
      end

      def on_command(ident, args_add_block)
        # include T::Generic
        # include T::Helpers
        if ident.match?("<@ident include>") &&
          args_add_block.match?(/<args_add_block <args <const_path_ref <var_ref <@const T>> <@const (?:Generic|Helpers)>>> false>/)
          patterns << IncludeTModulePattern.new(ident.range.begin..args_add_block.range.end)
        end

        # extend T::Sig
        if ident.match?("<@ident extend>") &&
          args_add_block.match?("<args_add_block <args <const_path_ref <var_ref <@const T>> <@const Sig>>> false>")
          patterns << ExtendTSigPattern.new(ident.range.begin..args_add_block.range.end)
        end

        super
      end

      # T.must foo => foo
      # T.reveal_type foo => foo
      # T.unsafe foo => foo
      class TMustNoParensPattern < Pattern
        def replace(segment)
          segment.gsub(/(T\s*\.(?:must|reveal_type|unsafe)\s*)(.+)/) do
            "#{" " * $1.length}#{$2}"
          end
        end
      end

      def on_command_call(var_ref, period, ident, args_add_block)
        if var_ref.match?("<var_ref <@const T>>") && period.match?("<@period .>")
          # T.must foo
          # T.reveal_type foo
          # T.unsafe foo
          if ident.match?(/<@ident (?:must|reveal_type|unsafe)>/) &&
            args_add_block.match?(/<args_add_block <args <.+>> false>/) &&
            args_add_block.body[0].body.length == 1
            patterns << TMustNoParensPattern.new(var_ref.range.begin..args_add_block.range.end)
          end
        end

        super
      end

      # sig { foo } =>
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
