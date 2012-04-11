require 'yaml'

class Section < Hash
  def deep_merge(other_hash)
    self.merge(other_hash) do |key, oldval, newval|
      oldval = oldval.to_hash if oldval.respond_to?(:to_hash)
      newval = newval.to_hash if newval.respond_to?(:to_hash)
      oldval.is_a?(Hash) && newval.is_a?(Hash) ? oldval.deep_merge(newval) : newval
    end
  end

  def deep_merge!(other_hash)
    replace(deep_merge(other_hash))
  end

  def method_missing(name, *args)
    if name.to_s[-1] == ?=
      self[name.to_s[0..-2].to_sym] = args.first
    else
      value = self[name]
      self[name] = value.call if value.is_a?(Proc)
      self[name]
    end
  end
end

class Configuration < Section
  def initialize(base_config_path, mode = :development, mixin_path = nil, mixins_to_use = [])
    config = self.class.from_hash(YAML.load(File.read(base_config_path)))

    @mode = mode

    self.update(config.generic)
    self.deep_merge!(config[mode]) if config.has_key?(mode)

    @mixin_path = mixin_path
    @mixins_to_use = mixins_to_use
    load_mixins if @mixin_path and @mixins_to_use.any?
  end

  def mixin(value)
    unless value.is_a?(Hash)
      value = self.class.from_hash(YAML.load(File.read(file)))
    end

    if value.has_key?(@mode)
      self.deep_merge!(value[@mode])
    else
      self.deep_merge!(value)
    end
  end

  def self.from_hash(hsh)
    Section.new.tap do |result|
      hsh.each do |key, value|
        value = if value.is_a?(Hash)
                  from_hash(value)
                elsif value.is_a?(Array)
                  value.map do |item|
                    from_hash(item)
                  end
                else
                  value
                end

        result[key.to_sym] = value
      end
    end
  end

  private

  def mixin_files
    @mixins_to_use.map do |mixin_name|
      File.join(@mixin_path, "#{mixin_name}.yml")
    end
  end

  def load_mixins
    mixin_files.each do |mixin_file|
      mixin(mixin_file)
    end
  end
end
