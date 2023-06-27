# frozen_string_literal: true

require "test_helper"

module Sorbet
  module Eraser
    class PatternsTest < Minitest::Test
      def test_sig
        assert_erases(<<-INPUT, <<-OUTPUT)
          def foo; end

          sig { void }
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
          foo =                bar         
        OUTPUT
      end

      def test_t_bind_parens
        assert_erases(<<-INPUT, <<-OUTPUT)
          foo = T.bind(self, String)
        INPUT
          foo =        self         
        OUTPUT
      end

      def test_t_cast_parens
        assert_erases(<<-INPUT, <<-OUTPUT)
          foo = T.cast(bar, String)
        INPUT
          foo =        bar         
        OUTPUT
      end

      def test_t_let_parens
        assert_erases(<<-INPUT, <<-OUTPUT)
          foo = T.let(bar, String)
        INPUT
          foo =       bar         
        OUTPUT
      end

      def test_t_must_parens
        assert_erases(<<-INPUT, <<-OUTPUT)
          foo = T.must(bar)
        INPUT
          foo =        bar 
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
                        foo 
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
                   foo 
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
            prop :foo, String
            const :bar, Integer
          end
        INPUT
          class Foo < T::Struct
            prop :foo        
            const :bar         
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
