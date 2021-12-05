module CrI18n
  @@instance = Labels.new

  # LABEL_DIRECTORY will be a list of one (but we can modify this constant during compile time now)
  LABEL_DIRECTORY = [] of String
  DEFINED_LABELS  = [] of String

  def self.get_label(target : String, lang : String = "", locale : String = "")
    @@instance.get_label(target, lang, locale)
  end

  def self.missed
    @@instance.missed
  end

  def self.raise_if_missing
    @@instance.raise_if_missing
  end

  def self.raise_if_missing=(value : Bool)
    @@instance.raise_if_missing = value
  end

  def self.with_language(lang : String, &)
    @@instance.with_language(lang) do
      yield
    end
  end

  def self.with_language_and_locale(lang : String, locale : String, &)
    @@instance.with_language_and_locale(lang, locale) do
      yield
    end
  end

  def self.load_labels(root : String)
    raise "Label directory '#{root}' doesn't exist" unless Dir.exists?("#{root}")
    labels = Labels.new
    Dir.each_child ("#{root}") do |lang_or_file|
      if File.file?("#{root}/#{lang_or_file}") && supported?(lang_or_file)
        root_labels = LabelLoader.new("#{root}/#{lang_or_file}").read
        labels.add_root(root_labels)
      elsif File.directory?("#{root}/#{lang_or_file}")
        Dir.each_child("#{root}/#{lang_or_file}") do |locale_or_file|
          if File.file?("#{root}/#{lang_or_file}/#{locale_or_file}") && supported?(locale_or_file)
            lang_labels = LabelLoader.new("#{root}/#{lang_or_file}/#{locale_or_file}").read
            labels.add_language(lang_labels, lang_or_file)
          elsif File.directory?("#{root}/#{lang_or_file}/#{locale_or_file}")
            Dir.each_child("#{root}/#{lang_or_file}/#{locale_or_file}") do |locale_file|
              if File.file?("#{root}/#{lang_or_file}/#{locale_or_file}/#{locale_file}") && supported?(locale_file)
                locale_labels = LabelLoader.new("#{root}/#{lang_or_file}/#{locale_or_file}/#{locale_file}").read
                labels.add_locale(locale_labels, lang_or_file, locale_or_file)
              end
            end
          end
        end
      end
    end
    @@instance = labels
  end

  private def self.supported?(name)
    name.ends_with?("json") ||
      name.ends_with?("yml") ||
      name.ends_with?("yaml")
  end

  class Labels
    property raise_if_missing = false

    @root_labels = {} of String => String
    @language_labels = Hash(String, Hash(String, String)).new { |h, k| h[k] = {} of String => String }
    @locale_labels = Hash(String, Hash(String, Hash(String, String))).new do |h1, k1|
      h1[k1] = Hash(String, Hash(String, String)).new { |h2, k2| h2[k2] = {} of String => String }
    end
    @logger = ::Log.for(Labels)
    @missed = Set(String).new
    @contexts = Hash(UInt64, Array(NamedTuple(language: String, locale: String))).new { |h, k| h[k] = [] of NamedTuple(language: String, locale: String) }

    def add_root(labels : Hash(String, String))
      @root_labels.merge!(labels)
    end

    def add_language(labels : Hash(String, String), language : String)
      @language_labels[language].merge!(labels)
    end

    def add_locale(labels : Hash(String, String), language : String, locale : String)
      @locale_labels[language][locale].merge!(labels)
    end

    def with_language(lang : String, &)
      # key by fiber id so we can be thread safe
      @contexts[Fiber.current.object_id] << {language: lang, locale: ""}
      yield
      @contexts[Fiber.current.object_id].pop
      @contexts.delete(Fiber.current.object_id) if @contexts[Fiber.current.object_id].empty?
    end

    def with_language_and_locale(language : String, locale : String)
      # key by fiber id so we can be thread safe
      @contexts[Fiber.current.object_id] << {language: language, locale: locale}
      yield
      @contexts[Fiber.current.object_id].pop
      @contexts.delete(Fiber.current.object_id) if @contexts[Fiber.current.object_id].empty?
    end

    def get_label(target : String, language : String = "", locale : String = "", *data)
      language = @contexts[Fiber.current.object_id][-1][:language] if language.empty? && @contexts.size > 0
      locale = @contexts[Fiber.current.object_id][-1][:locale] if locale.empty? && @contexts.size > 0
      label = target
      if l = @locale_labels.dig?(language, locale, target)
        @logger.debug { "Successfully resolved \"#{target}\" with language #{language} and locale #{locale} to \"#{l}\"" }
        label = l
      elsif l = @language_labels.dig?(language, target)
        @logger.debug { "Successfully resolved \"#{target}\" with language #{language} to \"#{l}\"" }
        label = l
      elsif l = @root_labels[target]?
        @logger.debug { "Successfully resolved \"#{target}\" from root to \"#{l}\"" }
        label = l
      else
        @logger.warn { "No label found for #{target}" }
        raise label if raise_if_missing
        @missed << target
      end
      data.each_with_index do |term, i|
        label = label.gsub("{#{i}}", term)
      end
      label
    end

    def missed
      @missed
    end
  end

  class LabelLoader
    def initialize(@file_name : String)
    end

    def read
      File.open(@file_name) do |file|
        return load(JSON.parse(file)) if @file_name.ends_with?(".json")
        return load(YAML.parse(file)) if @file_name.ends_with?(".yml") || @file_name.ends_with?(".yaml")
        raise "Unknown file extension in file #{@file_name}, can only support files ending with 'json', 'yml', or 'yaml'"
      rescue e
        raise "Error while reading file #{@file_name}: #{e.message}"
      end
    end

    def load(content : JSON::Any | YAML::Any)
      labels = {} of String => String
      if h = content.as_h
        recursive_load("", h, labels)
      else
        raise "Incorrect format for label file #{@file_name}"
      end
      labels
    end

    def recursive_load(prefix : String, blob : Hash(YAML::Any, YAML::Any) | Hash(String, JSON::Any), labels : Hash(String, String))
      blob.each do |key, new_blob|
        key_s = key.is_a?(String) ? key : key.as_s
        raise "Incorrect format for label file #{@file_name}, key '#{key_s}'' contains spaces" if key_s.includes?(" ")
        pref = prefix.size > 0 ? "#{prefix}." : ""
        if val = new_blob.as_s?
          labels["#{pref}#{key_s}"] = val
        elsif val = new_blob.as_h?
          recursive_load("#{pref}#{key_s}", val, labels)
        else
          raise "Incorrect format for label file #{@file_name}, found #{new_blob.raw.class}, expected String or Hash"
        end
      end
    end
  end
end
