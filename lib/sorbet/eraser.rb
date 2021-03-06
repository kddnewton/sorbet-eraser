# frozen_string_literal: true

require "ripper"

require "sorbet/eraser/parser"
require "sorbet/eraser/patterns"
require "sorbet/eraser/version"
require "t"

module Sorbet
  module Eraser
    # Hook the patterns into the parser so that the correct methods get
    # overridden and will trigger replacements.
    Parser.prepend(Patterns)

    # The entrypoint method to this overall module. This should be called with a
    # string that represents Ruby source, and it will return the modified Ruby
    # source.
    def self.erase(source)
      Parser.erase(source)
    end
  end
end
