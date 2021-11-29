module I18n
  @@instance = Labels.new

  def self.get_label(target : String, lang : String = "", locale : String = "")
    @@instance.get_label(target, lang, locale)
  end

  def self.missed
    @@instance.missed
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
    @root_labels = {} of String => String
    @language_labels = Hash(String, Hash(String, String)).new { |h, k| h[k] = {} of String => String }
    @locale_labels = Hash(String, Hash(String, Hash(String, String))).new do |h1, k1|
      h1[k1] = Hash(String, Hash(String, String)).new { |h2, k2| h2[k2] = {} of String => String }
    end
    @logger = ::Log.for(Labels)
    @missed = Set(String).new

    def add_root(labels : Hash(String, String))
      @root_labels.merge!(labels)
    end

    def add_language(labels : Hash(String, String), language : String)
      @language_labels[language].merge!(labels)
    end

    def add_locale(labels : Hash(String, String), language : String, locale : String)
      @locale_labels[language][locale].merge!(labels)
    end

    def get_label(target : String, language : String = "", locale : String = "")
      if l = @locale_labels.dig?(language, locale, target)
        @logger.debug { "Successfully resolved \"#{target}\" with language #{language} and locale #{locale} to \"#{l}\"" }
        l
      elsif l = @language_labels.dig?(language, target)
        @logger.debug { "Successfully resolved \"#{target}\" with language #{language} to \"#{l}\"" }
        l
      elsif l = @root_labels[target]?
        @logger.debug { "Successfully resolved \"#{target}\" from root to \"#{l}\"" }
        l
      else
        @logger.warn { "No label found for #{target}" }
        @missed << target
        "Label for '#{target}' not defined"
      end
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
