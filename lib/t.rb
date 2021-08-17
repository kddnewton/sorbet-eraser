# frozen_string_literal: true

require "t/enum"
require "t/struct"

# For some constructs, it doesn't make as much sense to entirely remove them
# since they're actually used to change runtime behavior. For example, T.absurd
# will always raise an error. In this case instead of removing the content, we
# can just shim it.
module T
  # These methods should really not be being called in a loop or any other kind
  # of hot path, so here we're just going to shim them.
  module Helpers
    def abstract!; end
    def interface!; end
    def final!; end
    def sealed!; end
    def mixes_in_class_methods(*); end
    def requires_ancestor(*); end
  end

  # Similar to the Helpers module, these things should only be called a couple
  # of times, so shimming them here.
  module Generic
    include Helpers
    def type_member(*, **); end
    def type_template(*, **); end
  end

  # Keeping this module as a thing so that if there's any kind of weird
  # reflection going on like is_a?(T::Sig) it will still work.
  module Sig
  end

  # Type aliases don't actually do anything, but they are usually assigned to
  # constants, so in that case we need to return something.
  def self.type_alias
    Object.new
  end

  # Absurd always raises a TypeError within Sorbet, so mirroring that behavior
  # here when T.absurd is called.
  def self.absurd(value)
    raise TypeError, value
  end
end
