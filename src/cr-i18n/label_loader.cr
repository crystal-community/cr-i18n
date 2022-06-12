module CrI18n
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
        if val = new_blob.as_h?
          recursive_load("#{pref}#{key_s}", val, labels)
        elsif val = new_blob.as_s?
          labels["#{pref}#{key_s}"] = val
        elsif new_blob.raw != nil
          labels["#{pref}#{key_s}"] = new_blob.raw.to_s
        else
          raise "Incorrect format for label file #{@file_name}, found null at #{pref}#{key_s}"
        end
      end
    end
  end
end
