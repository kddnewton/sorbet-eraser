# frozen_string_literal: true

require "test_helper"

module Sorbet
  module Eraser
    class PatternsTest < Minitest::Test
      def test_typed_comments
        %i[ignore false true strict strong].each do |mode|
          assert_erases(<<-INPUT, <<-OUTPUT)
            # typed: #{mode}
          INPUT
            #        #{" " * mode.length}
          OUTPUT
        end
      end

      def test_sig_braces
        assert_erases(<<-INPUT, <<-OUTPUT)
          def foo; end

          sig { void }
          def bar; end
        INPUT
          def foo; end

                      
          def bar; end
        OUTPUT
      end

      def test_sig_keywords
        assert_erases(<<-INPUT, <<-OUTPUT)
          def foo; end

          sig do
            void
          end
          def bar; end
        INPUT
          def foo; end

                
                
             
          def bar; end
        OUTPUT
      end

      def test_t_assert_type_parens
        assert_erases(<<-INPUT, <<-OUTPUT)
          foo = T.assert_type!(bar, String)
        INPUT
          foo =               (bar        )
        OUTPUT
      end

      def test_t_bind_parens
        assert_erases(<<-INPUT, <<-OUTPUT)
          foo = T.bind(self, String)
        INPUT
          foo =       (self        )
        OUTPUT
      end

      def test_t_cast_parens
        assert_erases(<<-INPUT, <<-OUTPUT)
          foo = T.cast(bar, String)
        INPUT
          foo =       (bar        )
        OUTPUT
      end

      def test_t_let_parens
        assert_erases(<<-INPUT, <<-OUTPUT)
          foo = T.let(bar, String)
        INPUT
          foo =      (bar        )
        OUTPUT

        assert_erases(<<-INPUT, <<-OUTPUT)
          T.let("World!", String)
        INPUT
               ("World!"        )
        OUTPUT
      end

      def test_t_let_array
        assert_erases(<<-INPUT, <<-OUTPUT)
          KEYWORDS = T.let(%w[__FILE__ __LINE__ alias and begin BEGIN break case class def defined? do else elsif end END ensure false for if in module next nil not or redo rescue retry return self super then true undef unless until when while yield], T::Array[String])
        INPUT
          KEYWORDS =      (%w[__FILE__ __LINE__ alias and begin BEGIN break case class def defined? do else elsif end END ensure false for if in module next nil not or redo rescue retry return self super then true undef unless until when while yield]                  )
        OUTPUT
      end

      def test_t_must_parens
        assert_erases(<<-INPUT, <<-OUTPUT)
          foo = T.must(bar)
        INPUT
          foo =       (bar)
        OUTPUT
      end

      def test_t_must_no_parens
        assert_erases(<<-INPUT, <<-OUTPUT)
          foo = T.must bar
        INPUT
          foo =        bar
        OUTPUT
      end

      def test_t_reveal_type_parens
        assert_erases(<<-INPUT, <<-OUTPUT)
          T.reveal_type(foo)
        INPUT
                       (foo)
        OUTPUT
      end

      def test_t_reveal_type_no_parens
        assert_erases(<<-INPUT, <<-OUTPUT)
          foo = T.reveal_type bar
        INPUT
          foo =               bar
        OUTPUT
      end

      def test_t_unsafe_parens
        assert_erases(<<-INPUT, <<-OUTPUT)
          T.unsafe(foo)
        INPUT
                  (foo)
        OUTPUT
      end

      def test_t_unsafe_no_parens
        assert_erases(<<-INPUT, <<-OUTPUT)
          foo = T.unsafe bar
        INPUT
          foo =          bar
        OUTPUT
      end

      def test_t_struct
        assert_erases(<<-INPUT, <<-OUTPUT)
          class Foo < T::Struct
            const :singleton, T.nilable(T::Boolean)
            const :double, T.untyped, default: nil
            const :original_type, T.nilable(T.any(T::Class[T.anything], Module))
            const :dry_type, T.nilable(T.any(T::Class[T.anything], Module))
            const :method, T.nilable(Symbol), without_accessors: true
            const :original_method, T.nilable(T.any(UnboundMethod, Method))
            const :args, T::Array[T.untyped], default: []
            const :kwargs, T::Hash[Symbol, T.untyped], default: {}
          end
        INPUT
          class Foo < T::Struct
            const :singleton                       
            const :double,            default: nil
            const :original_type                                                
            const :dry_type                                                
            const :method,                    without_accessors: true
            const :original_method                                         
            const :args,                      default: []
            const :kwargs,                             default: {}
          end
        OUTPUT
      end

      private

      def assert_erases(input, output)
        assert_equal(output, Eraser.erase(+input))
      end
    end
  end
end
