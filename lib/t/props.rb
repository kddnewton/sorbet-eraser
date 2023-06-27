# frozen_string_literal: true

module T
  # Here is the place we don't match up to sorbet because we simply don't
  # implement as much as they do in the runtime. If there are pieces of this
  # that folks would like implemented I'd be happy to include them. This is here
  # just to get a baseline for folks using T::Struct with basic const/prop
  # calls.
  module Props
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Here we're implementing a very basic version of the prop/const methods
    # that are in sorbet-runtime. These are only here to allow consumers to call
    # them and not raise errors and for bookkeeping.
    module ClassMethods
      def props
        @props ||= []
      end

      def prop(name, rules = {})
        create_prop(name)
        attr_accessor name
      end

      def const(name, rules = {})
        create_prop(name)
        attr_reader name
      end

      private

      def create_prop(name)
        props << name
        props.sort!
      end
    end

    # Here we're going to check against the props that have been defined on the
    # class level and set appropriate values.
    def initialize(hash = {})
      if self.class.props == hash.keys.sort
        hash.each { |key, value| instance_variable_set("@#{key}", value) }
      else
        raise ArgumentError, "Expected keys #{self.class.props} but got #{hash.keys.sort}"
      end
    end

    # This module is entirely empty because we haven't implemented anything from
    # sorbet-runtime here.
    module Serializable
    end

    # This is empty for the same reason.
    module Constructor
    end
  end
end
