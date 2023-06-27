# frozen_string_literal: true

require "test_helper"

module T
  class EnumTest < Minitest::Test
    class TestEnum < T::Enum
      enums do
        Spades = new
        Hearts = new
        Clubs = new
        Diamonds = new
      end
    end

    def test_enum
      expected = [
        TestEnum::Spades,
        TestEnum::Hearts,
        TestEnum::Clubs,
        TestEnum::Diamonds
      ]

      assert_equal(expected, TestEnum.values)
    end
  end
end
