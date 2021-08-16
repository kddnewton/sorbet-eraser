# frozen_string_literal: true

require "ripper"

require "sorbet/eraser/parser"
require "sorbet/eraser/patterns"
require "sorbet/eraser/version"

module Sorbet
  module Eraser
    Parser.prepend(Patterns)

    def self.erase(source)
      Parser.erase(source)
    end
  end
end
