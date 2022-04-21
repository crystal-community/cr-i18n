module CrI18n
  @@instance = Labels.new

  # LABEL_DIRECTORY will be a list of one (but we can modify this constant during compile time now)
  LABEL_DIRECTORY   = [] of String
  COMPILER_LOADED   = [] of String
  DEFINED_LABELS    = [] of String
  PLURAL_LABELS     = [] of String
  SUPPORTED_LOCALES = [] of String

  def self.get_label(target : String, lang_locale : String = "", count : (Float | Int)? = nil, **splat)
    @@instance.get_label(target, lang_locale, count, **splat)
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

  def self.root_locale
    @@instance.root_locale
  end

  def self.root_locale=(value : String)
    @@instance.root_locale = value
  end

  def self.root_pluralization
    @@instance.root_pluralization
  end

  def self.root_pluralization=(value : String)
    @@instance.root_pluralization = value
  end

  def self.parse_locale(lang_locale : String)
    if lang_locale.count('-') >= 1
      lang, locale = lang_locale.split('-', 2)
    else
      lang = lang_locale
    end

    [lang.downcase, locale ? locale.downcase : ""]
  end

  def self.with_locale(lang_locale : String, &)
    @@instance.with_locale(lang_locale) do
      yield
    end
  end

  def self.supported_locales
    @@instance.supported_locales
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
            labels.add_language(lang_labels, lang_or_file.downcase)
          elsif File.directory?("#{root}/#{lang_or_file}/#{locale_or_file}")
            Dir.each_child("#{root}/#{lang_or_file}/#{locale_or_file}") do |locale_file|
              if File.file?("#{root}/#{lang_or_file}/#{locale_or_file}/#{locale_file}") && supported?(locale_file)
                locale_labels = LabelLoader.new("#{root}/#{lang_or_file}/#{locale_or_file}/#{locale_file}").read
                labels.add_locale(locale_labels, lang_or_file.downcase, locale_or_file.downcase)
              end
            end
          end
        end
      end
    end
    @@instance = labels
    @@instance.freeze
    @@instance
  end

  private def self.supported?(name)
    name.ends_with?("json") ||
      name.ends_with?("yml") ||
      name.ends_with?("yaml")
  end

  class Labels
    PLURAL_ENDINGS = {"zero", "one", "two", "few", "many", "other"}

    property raise_if_missing = false
    property root_locale = ""
    property root_pluralization = ""
    property resolve_to_root = true
    getter supported_locales

    @root_labels = {} of String => String
    @language_labels = Hash(String, Hash(String, String)).new { |h, k| h[k] = {} of String => String }
    @locale_labels = Hash(String, Hash(String, Hash(String, String))).new do |h1, k1|
      h1[k1] = Hash(String, Hash(String, String)).new { |h2, k2| h2[k2] = {} of String => String }
    end
    @logger = ::Log.for(Labels)
    @missed = Set(String).new
    @contexts = Hash(UInt64, Array(NamedTuple(language: String, locale: String))).new { |h, k| h[k] = [] of NamedTuple(language: String, locale: String) }
    @plural_labels = Set(String).new
    @frozen = false
    @discrepencies : Array(String)?

    @supported_locales = [] of String

    def add_root(labels : Hash(String, String))
      raise "Can't add root labels, already finalized" if @frozen
      @root_labels.merge!(labels)
    end

    def add_language(labels : Hash(String, String), language : String)
      raise "Can't add language labels, already finalized" if @frozen
      @language_labels[language].merge!(labels)
    end

    def add_locale(labels : Hash(String, String), language : String, locale : String)
      raise "Can't add locale labels, already finalized" if @frozen
      @locale_labels[language][locale].merge!(labels)
    end

    def freeze
      raise "Already finalized" if @frozen
      @plural_labels, _ = detect_plural(@root_labels)
      calc_supported_locales
      @frozen = true
    end

    def label_discrepencies : Array(String)
      return @discrepencies.not_nil! if @discrepencies
      discs = [] of String

      # Get the non_plural labels now
      _, non_plural = detect_plural(@root_labels)

      @plural_labels.each do |target|
        unless @root_labels.has_key?("#{target}.other")
          discs << "Plural label '#{target}' is missing the required 'other' plural tag in root labels"
        end
      end

      @language_labels.each do |lang, labels|
        lang_plural, lang_non_plural = detect_plural(labels)

        lang_plural.each do |target|
          unless @language_labels[lang].has_key?("#{target}.other")
            discs << "Language '#{lang}' with plural label '#{target}' is missing the required 'other' plural tag"
          end
        end

        # compare non-plural labels for parity
        (non_plural - lang_non_plural).each do |missing_from_lang|
          discs << "Language '#{lang}' is missing non-plural label '#{missing_from_lang}' defined in root labels"
        end

        (lang_non_plural - non_plural).each do |extra_lang_label|
          discs << "Language '#{lang}' has extra non-plural label '#{extra_lang_label}' not found in root labels"
        end

        # Now compare plural labels
        (@plural_labels - lang_plural).each do |missing_from_lang|
          discs << "Language '#{lang}' is missing plural label '#{missing_from_lang}' defined in root labels"
        end

        (lang_plural - @plural_labels).each do |extra_lang_label|
          discs << "Language '#{lang}' has extra plural label '#{extra_lang_label}' not found in root labels"
        end
      end

      @locale_labels.each do |lang, locales|
        locales.each do |locale, labels|
          locale_plural, locale_non_plural = detect_plural(labels)

          locale_plural.each do |target|
            unless @locale_labels[lang][locale].has_key?("#{target}.other")
              discs << "Locale '#{lang}-#{locale}' with plural label '#{target}' is missing the required 'other' plural tag"
            end
          end

          # compare non-plural labels for parity
          (non_plural - locale_non_plural).each do |missing_from_locale|
            discs << "Locale '#{lang}-#{locale}' is missing non-plural label '#{missing_from_locale}' defined in root labels"
          end

          (locale_non_plural - non_plural).each do |extra_locale_label|
            discs << "Locale '#{lang}-#{locale}' has extra non-plural label '#{extra_locale_label}' not found in root labels"
          end

          # Now compare plural labels
          (@plural_labels - locale_plural).each do |missing_from_locale|
            discs << "Locale '#{lang}-#{locale}' is missing plural label '#{missing_from_locale}' defined in root labels"
          end

          (locale_plural - @plural_labels).each do |extra_locale_label|
            discs << "Locale '#{lang}-#{locale}' has extra plural label '#{extra_locale_label}' not found in root labels"
          end
        end
      end

      @discrepencies = discs

      discs
    end

    def with_locale(lang_locale : String)
      lang, locale = CrI18n.parse_locale(lang_locale)

      # key by fiber id so we can be thread safe
      @contexts[Fiber.current.object_id] << {language: lang, locale: locale}
      yield
      @contexts[Fiber.current.object_id].pop
      @contexts.delete(Fiber.current.object_id) if @contexts[Fiber.current.object_id].empty?
    end

    def get_label(target : String, lang_locale : String = "", count : (Float | Int)? = nil, **splat)
      raise "Label #{target} isn't pluralized, but is using the 'count' (#{count}) param" if count && raise_if_missing && !@plural_labels.includes?(target)

      language, locale = CrI18n.parse_locale(lang_locale)
      if language.empty? && @contexts.size > 0
        curr_context = @contexts[Fiber.current.object_id][-1]
        language = curr_context[:language]
        if locale.empty?
          locale = curr_context[:locale]
        end
      end

      language, locale = CrI18n.parse_locale(root_locale) if language.empty? && locale.empty?

      label = target
      if count && @plural_labels.includes?(target)
        raise "Unable to pluralize '#{label}': no language or locale detected, and root_pluralization locale has not been set" if language.empty? && locale.empty? && root_pluralization.empty?
        if plural = Pluralization.pluralize(count, language, locale)
          plural_label = "#{label}.#{plural}"
        elsif root_pluralization
          tlang, tlocale = CrI18n.parse_locale(root_pluralization)
          if plural = Pluralization.pluralize(count, tlang, tlocale)
            plural_label = "#{label}.#{plural}"
          else
            raise_unpluralizable_error(label, language, locale)
          end
        else
          raise_unpluralizable_error(label, language, locale)
        end
      end

      if plural_label
        ret = get_label?(plural_label, language, locale) || get_label?(label, language, locale) || label
      else
        ret = get_label?(label, language, locale) || label
      end

      raise "Label #{label} not found" if label == ret && raise_if_missing

      splat.each_with_index do |name, val|
        ret = ret.gsub("%{#{name}}", val)
      end
      ret
    end

    private def raise_unpluralizable_error(label, language, locale)
      errors = [] of String
      errors << "Unable to pluralize #{label}: "
      errors << "No pluralization rules for detected locale '#{language}#{locale.empty? ? "" : "-" + locale}'" if !language.empty?
      errors << "No pluralization rules for root_pluralization #{root_pluralization}" if !root_pluralization.empty?
      raise errors.join
    end

    private def get_label?(target : String, language : String, locale : String)
      if l = @locale_labels.dig?(language, locale, target)
        @logger.debug { "Successfully resolved \"#{target}\" with language #{language} and locale #{locale} to \"#{l}\"" }
        return l
      elsif l = @language_labels.dig?(language, target)
        @logger.debug { "Successfully resolved \"#{target}\" with language #{language} to \"#{l}\"" }
        return l
      elsif resolve_to_root
        if l = @root_labels[target]?
          @logger.debug { "Successfully resolved \"#{target}\" from root to \"#{l}\"" }
          return l
        else
          @logger.warn { "No label found for #{target}" }
          @missed << target
        end
      else
        @logger.warn { "No label found for #{target}" }
        @missed << target
      end

      nil
    end

    private def detect_plural(labels)
      plural = Set(String).new
      non_plural = Set(String).new
      labels.keys.each do |target|
        label, _, plural_tag = target.rpartition('.')
        PLURAL_ENDINGS.includes?(plural_tag) ? plural << label : non_plural << target
      end
      [plural, non_plural]
    end

    private def calc_supported_locales
      @supported_locales.clear

      @language_labels.keys.each { |lang| @supported_locales << lang }
      @locale_labels.each do |lang, locales|
        locales.keys.each do |locale|
          @supported_locales << "#{lang}-#{locale}"
        end
      end

      @supported_locales.uniq!
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
