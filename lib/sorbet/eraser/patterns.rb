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
          pre, post = 0...comma, comma..-1

          replacement[pre] =
            replacement[pre].gsub(/(T\s*\.(?:assert_type!|bind|cast|let)\(\s*)(.+)/m) do
              "#{blank($1)}#{$2}"
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

      # typed: ignore =>
      # typed: false =>
      # typed: true =>
      # typed: strict =>
      # typed: strong =>
      class TypedCommentPattern < Pattern
        def replace(segment)
          segment.gsub(/(\A#\s*typed:\s*(?:ignore|false|true|strict|strong)(\s*))\z/) do
            blank($1)
          end
        end
      end

      def on_comment(comment)
        super.tap do |node|
          if lineno == 1 && comment.match?(/\A#\s*typed:\s*(?:ignore|false|true|strict|strong)\s*\z/)
            # typed: ignore
            # typed: false
            # typed: true
            # typed: strict
            # typed: strong
            patterns << TypedCommentPattern.new(node.range)
          end
        end
      end

      def on_method_add_arg(call, arg_paren)
        if call.match?(/\A<call <var_ref <@const T>> <@period \.> <@ident (?:must|reveal_type|unsafe)>>\z/) && arg_paren.match?(/\A<arg_paren <args_add_block <args .+> false>>\z/)
          # T.must(foo)
          # T.reveal_type(foo)
          # T.unsafe(foo)
          patterns << TOneArgMethodCallParensPattern.new(call.range.begin...arg_paren.range.end)
        elsif call.match?(/\A<call <var_ref <@const T>> <@period \.> <@ident (?:assert_type!|cast|let)>>\z/) && arg_paren.match?(/\A<arg_paren <args_add_block <args .+> false>>\z/)
          # T.assert_type!(foo, bar)
          # T.cast(foo, bar)
          # T.let(foo, bar)
          patterns << TTwoArgMethodCallParensPattern.new(
            call.range.begin...arg_paren.range.end,
            comma: arg_paren.body[0].body[0].body[0].range.end - call.range.begin
          )
        elsif call.match?(/\A<call <var_ref <@const T>> <@period \.> <@ident bind>>\z/) && arg_paren.match?(/\A<arg_paren <args_add_block <args <var_ref <@kw self>> .+> false>>\z/)
          # T.bind(self, foo)
          patterns << TTwoArgMethodCallParensPattern.new(
            call.range.begin...arg_paren.range.end,
            comma: arg_paren.body[0].body[0].body[0].range.end - call.range.begin
          )
        elsif call.match?(/\A<fcall <@ident (?:abstract|final|interface)!>>\z/) && arg_paren.match?("<args >")
          # abstract!
          # final!
          # interface!
          patterns << DeclarationPattern.new(call.range)
        elsif call.match?("<fcall <@ident mixes_in_class_methods>>") && arg_paren.match?(/\A<arg_paren <args_add_block <args <.+>>> false>>\z/)
          # mixes_in_class_methods(foo)
          patterns << MixesInClassMethodsPattern.new(call.range.begin...arg_paren.range.end)
        end

        super
      end

      # prop :foo, String => prop :foo
      # const :foo, String => const :foo
      class PropWithoutOptionsPattern < Pattern
        def replace(segment)
          segment.dup.tap do |replacement|
            range = metadata.fetch(:comma)..-1
            replacement[range] = blank(replacement[range])
          end
        end
      end

      # prop :foo, String, default: "" => prop :foo, default: ""
      # const :foo, String, default: "" => const :foo, default: ""
      class PropWithOptionsPattern < Pattern
        def replace(segment)
          segment.dup.tap do |replacement|
            first_comma = metadata.fetch(:first_comma)
            second_comma = metadata.fetch(:second_comma)

            range = (first_comma + 1)..second_comma
            replacement[range] = blank(replacement[range])
          end
        end
      end

      def on_command(ident, args_add_block)
        if ident.match?(/\A<@ident (?:const|prop)>\z/)
          if args_add_block.match?(/\A<args_add_block <args <symbol_literal <symbol <@ident .+?>>> <.+> <bare_assoc_hash .+> false>\z/)
            # prop :foo, String, default: ""
            # const :foo, String, default: ""
            patterns << PropWithOptionsPattern.new(
              ident.range.begin..args_add_block.range.end,
              first_comma: args_add_block.body[0].body[0].range.end - ident.range.begin,
              second_comma: args_add_block.body[0].body[1].range.end - ident.range.begin
            )
          elsif args_add_block.match?(/\A<args_add_block <args <symbol_literal <symbol <@ident .+?>>> <.+> false>\z/)
            # prop :foo, String
            # const :foo, String
            patterns << PropWithoutOptionsPattern.new(
              ident.range.begin..args_add_block.range.end,
              comma: args_add_block.body[0].body[0].range.end - ident.range.begin
            )
          end
        end

        super
      end

      def on_command_call(var_ref, period, ident, args_add_block)
        if var_ref.match?("<var_ref <@const T>>") && period.match?("<@period .>") && ident.match?(/\A<@ident (?:must|reveal_type|unsafe)>\z/) && args_add_block.match?(/\A<args_add_block <args <.+>> false>\z/) && args_add_block.body[0].body.length == 1
          # T.must foo
          # T.reveal_type foo
          # T.unsafe foo
          patterns << TMustNoParensPattern.new(var_ref.range.begin..args_add_block.range.end)
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

      # sig do foo end =>
      class SigBlockPattern < Pattern
        def replace(segment)
          segment.gsub(/(sig\s*do.+end)(.*)/m) do
            "#{blank($1)}#{$2}"
          end
        end
      end

      def on_stmts_add(node, value)
        if value.match?(/\A<method_add_block <method_add_arg <fcall <@ident sig>> <args >> <brace_block  <stmts .+>>>\z/)
          # sig { foo }
          patterns << SigBracesPattern.new(value.range)
        elsif value.match?(/\A<method_add_block <method_add_arg <fcall <@ident sig>> <args >> <do_block  <bodystmt .+>>>\z/)
          # sig do foo end
          patterns << SigBlockPattern.new(value.range)
        end

        super
      end
    end
  end
end
