# frozen_string_literal: true

require "test_helper"

module Sorbet
  module Eraser
    class VersionTest < Minitest::Test
      def test_version
        refute_nil(VERSION)
      end
    end
  end
end
