# frozen_string_literal: true

require "sorbet/eraser/t/enum"
require "sorbet/eraser/t/props"
require "sorbet/eraser/t/struct"

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

  # I really don't want to be shimming this, but there are places where people
  # try to reference these values.
  module Private
    module RuntimeLevels
      def self.default_checked_level; :never; end
    end
  
    module Methods
      module MethodHooks
      end

      module SingletonMethodHooks
      end

      def self.signature_for_method(method); nil; end
    end
  end

  # I also don't want to shim this, but there are places where people will
  # reference it.
  module Configuration
    class << self
      attr_accessor :inline_type_error_handler,
                    :call_validation_error_handler,
                    :sig_builder_error_handler
    end
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
