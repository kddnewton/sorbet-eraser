# frozen_string_literal: true

module T
  # This is a shim for the T::Struct class because since you're actually
  # inheriting from the class there's not really a way to remove it from the
  # source.
  class Struct
    # include T::Props
    # include T::Props::Serializable
    # include T::Props::Constructor
  end
end
