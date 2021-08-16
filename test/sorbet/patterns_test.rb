# frozen_string_literal: true

require "test_helper"

module Sorbet
  module Eraser
    class PatternsTest < Minitest::Test
      def test_extend_t_sig
        assert_erases(<<-INPUT, <<-OUTPUT)
          include Foo
          extend T::Sig
        INPUT
          include Foo
                       
        OUTPUT
      end

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

      def test_t_type_alias
        assert_erases(<<-INPUT, <<-OUTPUT)
          foo = T.type_alias { String }
        INPUT
          foo = ::Sorbet::Eraser::TypeAlias
        OUTPUT
      end

      private

      def assert_erases(input, output)
        assert_equal(output, Eraser.erase(+input))
      end
    end
  end
end
