# frozen_string_literal: true

module T
  # This is the actual parent class of T::Struct. It's here to match up the
  # inheritance chain in case someone is doing reflection.
  class InexactStruct
    include Props
    include Props::Serializable
    include Props::Constructor
  end

  # This is a shim for the T::Struct class because since you're actually
  # inheriting from the class there's not really a way to remove it from the
  # source.
  class Struct < InexactStruct
    def self.inherited(child)
      super(child)

      child.define_singleton_method(:inherited) do |grandchild|
        super(grandchild)
        raise "#{grandchild.name} is a subclass of T::Struct and cannot be subclassed"
      end
    end
  end

  class ImmutableStruct < InexactStruct
    def self.inherited(child)
      super(child)
  
      child.define_singleton_method(:inherited) do |grandchild|
        super(grandchild)
        raise "#{grandchild.name} is a subclass of T::ImmutableStruct and cannot be subclassed"
      end
    end
  
    def initialize(hash = {})
      super
      freeze
    end
  
    # Matches the signature in Props, but raises since this is an immutable struct and only const is allowed
    def self.prop(name, rules = {})
      return super if rules[:immutable]
  
      raise "Cannot use `prop` in #{self.name} because it is an immutable struct. Use `const` instead"
    end
  
    def with(changed_props)
      raise "Cannot use `with` in #{self.class.name} because it is an immutable struct"
    end
  end
end
