# encoding: utf-8

require 'yaml'
require 'set'

require 'liquid/ext/hash'
require 'liquid/ext/ordered_set'
require 'liquid/environment'

module Liquid
  ##
  # Am {Configuration} consists of one or more Sections. A section is a hash-like
  # object that responds to all keys in the hash as if they were methods:
  #
  #   > s = Section.from_hash({:v1 => 2, :nested => {:v2 => 1}})
  #   > s.v1
  #   => 2
  #   > s.nested.v2
  #   => 1
  #
  class Section < Hash

    class << self

      # How to handle nil values in the configuration?
      #
      # Possible values are:
      #  - :nil, nil  (return nil)
      #  - :raise  (raise an exception)
      #  - :section  (return a NilSection which can be chained)
      #
      attr_accessor :nil_action

      # Create a new section from the given hash-like object.
      #
      # @param [Hash] hsh  The hash to convert into a section.
      # @return [Section]  The new {Section} object.
      def from_hash(hsh)
        new.tap do |result|
          hsh.each do |key, value|
            result[key.to_sym] = from_value(value)
          end
        end
      end

      # Convert the given value into a Section, list of Sections or the pure
      # value. Used to recursively build the Section hash.
      #
      # @private
      def from_value(value)
        case value
        when Hash
          from_hash(value)
        when Array
          value.map do |item|
            from_value(item)
          end
        else
          value
        end
      end

    end

    # @private
    def method_missing(name, *args)
      if name.to_s =~ /(.*)=$/
        self[$1.to_sym] = Section.from_value(args.first)
      else
        value = self[name]
        if value == nil
          if self.class.nil_action == :raise
            raise "No value set for config key #{name}"
          elsif self.class.nil_action == :section
            self[name] = Section.from_value({})
          end
        else
          self[name] = value.call if value.is_a?(Proc)
        end
        self[name]
      end
    end
  end

  ##
  # The Configuration class provides a simple interface to configuration stored
  # inside of YAML files.
  #
  class Configuration < Section

    # Create a new {Configuration} object.
    #
    # @yield [config]  The new configuration object.
    def initialize
      @mixins = OrderedSet.new
      @callbacks = []
    end

    # Mixin a configuration snippet into the current section.
    #
    # @param [Hash, String] value  A hash to merge into the current
    #                              configuration. If a string is given a filename
    #                              is assumed and the given file is expected to
    #                              contain a YAML hash.
    # @return [void]
    def mixin(value)
      @mixins << value

      if value.is_a?(String)
        value = YAML.load(File.read(value))
      end

      return unless value

      value = Section.from_hash(value)

      deep_merge!(value.delete(:generic)) if value.has_key?(:generic)

      if value.has_key?(Env.to_sym)
        deep_merge!(value[Env.to_sym])
      else
        deep_merge!(value)
      end
    end

    # Reload all mixins.
    #
    # @return [void]
    def reload!
      clear

      @mixins.each do |file|
        mixin(file)
      end

      @callbacks.each do |callback|
        callback.call(self)
      end
    end

    # Register a callback for config mixins.
    #
    # @return [void]
    def callback(&block)
      @callbacks << block
    end

  end
end
