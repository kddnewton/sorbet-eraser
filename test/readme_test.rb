# frozen_string_literal: true

require "test_helper"

class READMETest < Minitest::Test
  def test_correct_example
    filepath = File.expand_path("../README.md", __dir__)
    before, after, * = File.read(filepath).scan(/```ruby\n(.*?)```/m).map(&:first)

    assert_equal Sorbet::Eraser.erase(before), after
  end
end
