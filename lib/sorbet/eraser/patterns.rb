# frozen_string_literal: true

module Sorbet
  module Eraser
    module Patterns
      # A pattern in code that represents a call to a special Sorbet method.
      class Pattern
        attr_reader :range, :metadata

        def initialize(range, **metadata)
          @range = range
          @metadata = metadata
        end

        def erase(source)
          original = source[range]
          replaced = replace(original)

          # puts "Replacing #{original} (len=#{original.length}) " \
          #      "with #{replaced} (len=#{replaced.length})"

          source[range] = replaced
          source
        end

        def blank(segment)
          # This is deceptive in that it hides that it actually replaces
          # everything with spaces _except_ newline characters, which is keeps
          # in place.
          segment.gsub(/./, " ")
        end

        def replace(segment)
          segment
        end
      end

      # T.must(foo) => foo
      # T.reveal_type(foo) => foo
      # T.unsafe(foo) => foo
      class TOneArgMethodCallParensPattern < Pattern
        def replace(segment)
          segment.gsub(/(T\s*\.(?:must|reveal_type|unsafe)\(\s*)(.+)(\s*\))(.*)/m) do
            "#{blank($1)}#{$2}#{blank($3)}#{$4}"
          end
        end
      end

      # T.assert_type!(foo, bar) => foo
      # T.bind(self, foo) => self
      # T.cast(foo, bar) => foo
      # T.let(foo, bar) => let
      class TTwoArgMethodCallParensPattern < Pattern
        def replace(segment)
          replacement = segment.dup

          # We can't really rely on regex here because commas have semantic
          # meaning and you might have some in the value of the first argument.
          comma = metadata.fetch(:comma)
          pre, post = 0..comma, (comma + 1)..-1

          replacement[pre] =
            replacement[pre].gsub(/(T\s*\.(?:assert_type!|bind|cast|let)\(\s*)(.+)(\s*,)(.*)/m) do
              "#{blank($1)}#{$2}#{blank($3)}#{$4}"
            end

          replacement[post] = blank(replacement[post])
          replacement
        end
      end

      # abstract! =>
      # final! =>
      # interface! =>
      class DeclarationPattern < Pattern
        def replace(segment)
          segment.gsub(/((?:abstract|final|interface)!(?:\(\s*\))?)(.*)/) do
            "#{blank($1)}#{$2}"
          end
        end
      end

      # mixes_in_class_methods(foo) => foo
      class MixesInClassMethodsPattern < Pattern
        def replace(segment)
          segment.gsub(/(mixes_in_class_methods\(\s*)(.+)(\s*\))(.*)/m) do
            "#{blank($1)}#{$2}#{blank($3)}#{$4}"
          end
        end
      end

      def on_method_add_arg(call, arg_paren)
        # T.must(foo)
        # T.reveal_type(foo)
        # T.unsafe(foo)
        if call.match?(/<call <var_ref <@const T>> <@period \.> <@ident (?:must|reveal_type|unsafe)>>/) &&
          arg_paren.match?(/<arg_paren <args_add_block <args .+> false>>/)
          patterns << TOneArgMethodCallParensPattern.new(call.range.begin...arg_paren.range.end)
        end

        # T.assert_type!(foo, bar)
        # T.cast(foo, bar)
        # T.let(foo, bar)
        if call.match?(/\A<call <var_ref <@const T>> <@period \.> <@ident (?:assert_type!|cast|let)>>\z/) &&
          arg_paren.match?(/<arg_paren <args_add_block <args .+> false>>/)
          patterns <<
            TTwoArgMethodCallParensPattern.new(
              call.range.begin...arg_paren.range.end,
              comma: arg_paren.body[0].body[0].body[0].range.end - call.range.begin
            )
        end

        # T.bind(self, foo)
        if call.match?(/<call <var_ref <@const T>> <@period \.> <@ident bind>>/) &&
          arg_paren.match?(/<arg_paren <args_add_block <args <var_ref <@kw self>> .+> false>>/)
          patterns <<
            TTwoArgMethodCallParensPattern.new(
              call.range.begin...arg_paren.range.end,
              comma: arg_paren.body[0].body[0].body[0].range.end - call.range.begin
            )
        end

        # abstract!
        # final!
        # interface!
        if call.match?(/<fcall <@ident (?:abstract|final|interface)!>>/) &&
          arg_paren.match?("<args >")
          patterns << DeclarationPattern.new(call.range.begin...arg_paren.range.end)
        end

        # mixes_in_class_methods(foo)
        if call.match?("<fcall <@ident mixes_in_class_methods>>") &&
          arg_paren.match?(/<arg_paren <args_add_block <args <.+>>> false>>/)
          patterns << MixesInClassMethodsPattern.new(call.range.begin...arg_paren.range.end)
        end

        super
      end

      # T.must foo => foo
      # T.reveal_type foo => foo
      # T.unsafe foo => foo
      class TMustNoParensPattern < Pattern
        def replace(segment)
          segment.gsub(/(T\s*\.(?:must|reveal_type|unsafe)\s*)(.+)/) do
            "#{blank($1)}#{$2}"
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
            patterns << TMustNoParensPattern.new(var_ref.range.begin...args_add_block.range.end)
          end
        end

        super
      end

      # sig { foo } =>
      class SigBracesPattern < Pattern
        def replace(segment)
          segment.gsub(/(sig\s*\{.+\})(.*)/m) do
            "#{blank($1)}#{$2}"
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
