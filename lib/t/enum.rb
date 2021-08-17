# frozen_string_literal: true

module T
  # This is mostly copy-pasted from sorbet-runtime since we have to maintain the
  # same behavior.
  class T::Enum
    ## Enum class methods ##

    def self.values
      if @values.nil?
        raise "Attempting to access values of #{self.class} before it has been initialized." \
          " Enums are not initialized until the 'enums do' block they are defined in has finished running."
      end
      @values
    end

    # This exists for compatibility with the interface of `Hash` & mostly to support
    # the HashEachMethods Rubocop.
    def self.each_value(&blk)
      if blk
        values.each(&blk)
      else
        values.each
      end
    end

    # Convert from serialized value to enum instance
    def self.try_deserialize(serialized_val)
      if @mapping.nil?
        raise "Attempting to access serialization map of #{self.class} before it has been initialized." \
          " Enums are not initialized until the 'enums do' block they are defined in has finished running."
      end
      @mapping[serialized_val]
    end

    # Convert from serialized value to enum instance.
    #
    # @return [self]
    # @raise [KeyError] if serialized value does not match any instance.
    def self.from_serialized(serialized_val)
      res = try_deserialize(serialized_val)
      if res.nil?
        raise KeyError.new("Enum #{self} key not found: #{serialized_val.inspect}")
      end
      res
    end

    # Note: It would have been nice to make this method final before people started overriding it.
    # @return [Boolean] Does the given serialized value correspond with any of this enum's values.
    def self.has_serialized?(serialized_val)
      if @mapping.nil?
        raise "Attempting to access serialization map of #{self.class} before it has been initialized." \
          " Enums are not initialized until the 'enums do' block they are defined in has finished running."
      end
      @mapping.include?(serialized_val)
    end

    def self.serialize(instance)
      return nil if instance.nil?

      if self == T::Enum
        raise "Cannot call T::Enum.serialize directly. You must call on a specific child class."
      end
      if instance.class != self
        raise "Cannot call #serialize on a value that is not an instance of #{self}."
      end
      instance.serialize
    end

    # Note: Failed CriticalMethodsNoRuntimeTypingTest
    def self.deserialize(mongo_value)
      if self == T::Enum
        raise "Cannot call T::Enum.deserialize directly. You must call on a specific child class."
      end
      self.from_serialized(mongo_value)
    end

    ## Enum instance methods ##

    def dup
      self
    end

    def clone
      self
    end

    def serialize
      assert_bound!
      @serialized_val
    end

    def to_json(*args)
      serialize.to_json(*args)
    end

    def to_s
      inspect
    end

    def inspect
      "#<#{self.class.name}::#{@const_name || '__UNINITIALIZED__'}>"
    end

    def <=>(other)
      case other
      when self.class
        self.serialize <=> other.serialize
      else
        nil
      end
    end

    # NB: Do not call this method. This exists to allow for a safe migration path in places where enum
    # values are compared directly against string values.
    #
    # Ruby's string has a weird quirk where `'my_string' == obj` calls obj.==('my_string') if obj
    # responds to the `to_str` method. It does not actually call `to_str` however.
    #
    # See https://ruby-doc.org/core-2.4.0/String.html#method-i-3D-3D
    def to_str
      msg = 'Implicit conversion of Enum instances to strings is not allowed. Call #serialize instead.'
      raise NoMethodError.new(msg)
    end

    def ==(other)
      case other
      when String
        false
      else
        super(other)
      end
    end

    def ===(other)
      case other
      when String
        false
      else
        super(other)
      end
    end

    ## Private implementation ##

    def initialize(serialized_val=nil)
      raise 'T::Enum is abstract' if self.class == T::Enum
      if !self.class.started_initializing?
        raise "Must instantiate all enum values of #{self.class} inside 'enums do'."
      end
      if self.class.fully_initialized?
        raise "Cannot instantiate a new enum value of #{self.class} after it has been initialized."
      end

      serialized_val = serialized_val.frozen? ? serialized_val : serialized_val.dup.freeze
      @serialized_val = serialized_val
      @const_name = nil
      self.class._register_instance(self)
    end

    private def assert_bound!
      if @const_name.nil?
        raise "Attempting to access Enum value on #{self.class} before it has been initialized." \
          " Enums are not initialized until the 'enums do' block they are defined in has finished running."
      end
    end

    def _bind_name(const_name)
      @const_name = const_name
      @serialized_val = const_to_serialized_val(const_name) if @serialized_val.nil?
      freeze
    end

    private def const_to_serialized_val(const_name)
      # Historical note: We convert to lowercase names because the majority of existing calls to
      # `make_accessible` were arrays of lowercase strings. Doing this conversion allowed for the
      # least amount of repetition in migrated declarations.
      const_name.to_s.downcase.freeze
    end

    def self.started_initializing?
      @started_initializing ||= false
    end

    def self.fully_initialized?
      @fully_initialized ||= false
    end

    # Maintains the order in which values are defined
    def self._register_instance(instance)
      @values ||= []
      @values << instance
    end

    # Entrypoint for allowing people to register new enum values.
    # All enum values must be defined within this block.
    def self.enums(&blk)
      raise "enums cannot be defined for T::Enum" if self == T::Enum
      raise "Enum #{self} was already initialized" if @fully_initialized
      raise "Enum #{self} is still initializing" if @started_initializing

      @started_initializing = true

      @values = nil

      yield

      @mapping = nil
      @mapping = {}

      # Freeze the Enum class and bind the constant names into each of the instances.
      self.constants(false).each do |const_name|
        instance = self.const_get(const_name, false)
        if !instance.is_a?(self)
          raise "Invalid constant #{self}::#{const_name} on enum. " \
            "All constants defined for an enum must be instances itself (e.g. `Foo = new`)."
        end

        instance._bind_name(const_name)
        serialized = instance.serialize
        if @mapping.include?(serialized)
          raise "Enum values must have unique serializations. Value '#{serialized}' is repeated on #{self}."
        end
        @mapping[serialized] = instance
      end
      @values.freeze
      @mapping.freeze

      orphaned_instances = T.must(@values) - @mapping.values
      if !orphaned_instances.empty?
        raise "Enum values must be assigned to constants: #{orphaned_instances.map {|v| v.instance_variable_get('@serialized_val')}}"
      end

      @fully_initialized = true
    end

    def self.inherited(child_class)
      super

      raise "Inheriting from children of T::Enum is prohibited" if self != T::Enum
    end

    # Marshal support
    def _dump(_level)
      Marshal.dump(serialize)
    end

    def self._load(args)
      deserialize(Marshal.load(args))
    end
  end
end
