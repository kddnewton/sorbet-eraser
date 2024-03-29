# frozen_string_literal: true

require "test_helper"

module T
  class StructTest < Minitest::Test
    class TestStruct < Struct
      prop :prop1
      prop :prop2, without_accessors: true
      const :const1
      const :const2
    end

    def test_struct
      # Check that we get an argument error if we pass in too many keys.
      assert_raises(ArgumentError) do
        TestStruct.new(prop1: 1, prop2: 2, const1: 3, const2: 4, extra: 5)
      end

      # Check that we get an argument error if we pass in the wrong keys.
      assert_raises(ArgumentError) do
        TestStruct.new(prop1: 1, prop2: 2, prop3: 3)
      end

      # Check that we can't set const values.
      assert_raises(NoMethodError) do
        struct = TestStruct.new(prop1: 1, prop2: 2, const1: 3, const2: 4)
        struct.const1 = 5
      end

      # Check that we can set prop values.
      struct = TestStruct.new(prop1: 1, prop2: 2, const1: 3, const2: 4)
      struct.prop1 = 5
      assert_equal(5, struct.prop1)

      # Check that we cannot set prop values if we don't have accessors.
      assert_raises(NoMethodError) do
        struct = TestStruct.new(prop1: 1, prop2: 2, const1: 3, const2: 4)
        struct.prop2 = 5
      end
    end
  end
end
