module Localization
  def self.get_label(target : String, lang : String = "", locale : String = "")
    label_logger = ::Log.for(Localization)
    if l = LOCALE_LABELS.dig?(lang, locale, target)
      label_logger.debug { "Successfully resolved \"#{target}\" with lang #{lang} and locale #{locale} to \"#{l}\"" }
      l
    elsif l = LANGUAGE_LABELS.dig?(lang, target)
      label_logger.debug { "Successfully resolved \"#{target}\" with lang #{lang} to \"#{l}\"" }
      l
    elsif l = ROOT_LABELS[target]?
      label_logger.debug { "Successfully resolved \"#{target}\" from root to \"#{l}\"" }
      l
    else
      label_logger.warn { "No label found for #{target}" }
      target
    end
  end

  ROOT_LABELS     = {} of String => String
  LANGUAGE_LABELS = Hash(String, Hash(String, String)).new { |h, k| h[k] = {} of String => String }
  LOCALE_LABELS   = Hash(String, Hash(String, Hash(String, String))).new do |h1, k1|
    h1[k1] = Hash(String, Hash(String, String)).new { |h2, k2| h2[k2] = {} of String => String }
  end

  def self.load_labels(root : String)
    ROOT_LABELS.clear
    LANGUAGE_LABELS.clear
    LOCALE_LABELS.clear
    label_logger = ::Log.for(Localization)
    unless Dir.exists?("#{root}")
      label_logger.info { "Label directory '#{root}' doesn't exist, loading nothing" }
      return
    end
    Dir.each_child ("#{root}") do |lang_or_file|
      if File.file?("#{root}/#{lang_or_file}") && supported?(lang_or_file)
        loader = LabelLoader.new("#{root}/#{lang_or_file}")
        labels = loader.read
        ROOT_LABELS.merge!(labels)
      elsif File.directory?("#{root}/#{lang_or_file}")
        Dir.each_child("#{root}/#{lang_or_file}") do |locale_or_file|
          if File.file?("#{root}/#{lang_or_file}/#{locale_or_file}") && supported?(locale_or_file)
            loader = LabelLoader.new("#{root}/#{lang_or_file}/#{locale_or_file}")
            labels = loader.read
            LANGUAGE_LABELS[lang_or_file].merge!(labels)
          elsif File.directory?("#{root}/#{lang_or_file}/#{locale_or_file}")
            Dir.each_child("#{root}/#{lang_or_file}/#{locale_or_file}") do |locale_file|
              if File.file?("#{root}/#{lang_or_file}/#{locale_or_file}/#{locale_file}") && supported?(locale_file)
                loader = LabelLoader.new("#{root}/#{lang_or_file}/#{locale_or_file}/#{locale_file}")
                labels = loader.read
                LOCALE_LABELS[lang_or_file][locale_or_file].merge!(labels)
              end
            end
          end
        end
      end
    end
  end

  private def self.supported?(name)
    name.ends_with?("json") ||
      name.ends_with?("yml") ||
      name.ends_with?("yaml")
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
