# frozen_string_literal: true

require "ripper"

require "sorbet/eraser/parser"
require "sorbet/eraser/patterns"
require "sorbet/eraser/version"

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

# For some constructs, it doesn't make as much sense to entirely remove them
# since they're actually used to change runtime behavior. For example, T.absurd
# will always raise an error. In this case instead of removing the content, we
# can just shim it.
module T
  class TypeAlias
  end

  def self.type_alias
    TypeAlias.new
  end

  class AbsurdError < StandardError
  end

  def self.absurd(value)
    raise AbsurdError, value
  end
end
