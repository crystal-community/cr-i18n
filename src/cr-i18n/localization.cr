module CrI18n
  @@instance = Labels.new

  LABEL_DIRECTORY = [] of Nil
  VISITED_LABELS  = [] of Nil

  def self.get_label(target : String, lang_locale : String = "", *, count : (Float | Int)? = nil, **splat)
    @@instance.get_label(target, lang_locale, **splat, count: count)
  end

  def self.missed
    @@instance.missed
  end

  def self.root_locale
    @@instance.root_locale
  end

  def self.root_locale=(value : String)
    @@instance.root_locale = value
  end

  def self.with_locale(lang_locale : String, &)
    @@instance.with_locale(lang_locale) do
      yield
    end
  end

  def self.current_locale
    @@instance.current_locale
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
    @@instance.freeze
    @@instance
  end

  private def self.supported?(name)
    name.ends_with?("json") ||
      name.ends_with?("yml") ||
      name.ends_with?("yaml")
  end

  class Labels
    property root_locale = ""
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
    @frozen = false

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
      calc_supported_locales
      @frozen = true
    end

    def with_locale(lang_locale : String)
      lang, locale = parse_locale(lang_locale)

      # key by fiber id so we can be thread safe
      @contexts[Fiber.current.object_id] << {language: lang, locale: locale}
      yield
      @contexts[Fiber.current.object_id].size == 1 ? @contexts.delete(Fiber.current.object_id) : @contexts[Fiber.current.object_id].pop
    end

    def current_locale
      @contexts[Fiber.current.object_id]?.try(&.[-1]?)
    end

    private def parse_locale(lang_locale : String)
      if lang_locale.count('-') >= 1
        lang, locale = lang_locale.split('-', 2)
      else
        lang = lang_locale
      end

      [lang, locale || ""]
    end

    private def lang_locale(specified)
      language, locale = parse_locale(specified)
      if language.empty? && @contexts.size > 0
        curr_context = @contexts[Fiber.current.object_id][-1]
        language = curr_context[:language]
        if locale.empty?
          locale = curr_context[:locale]
        end
      end

      language, locale = parse_locale(root_locale) if language.empty? && locale.empty?

      # Don't return non-supported languages or locales (will force resolution to root labels)
      unless CrI18n.supported_locales.includes?("#{language}-#{locale}")
        unless CrI18n.supported_locales.includes?(language)
          language = ""
        end
        locale = ""
      end

      {language, locale}
    end

    private def format_label(label, language, locale, count, **splat)
      # TODO: forbid `count` as a formatted param
      label = label.gsub("%{count}", count)
      splat.each_with_index do |name, val|
        if format_type = get_label?("cri18n.formatters.#{name}.type", language, locale)
          fmt = get_label?("cri18n.formatters.#{name}.format", language, locale)
          val = FormatterManager.format(format_type, fmt, val)
        end
        label = label.gsub("%{#{name}}", val)
      end
      label
    end

    private def resolve_plural_label(target, count, language, locale)
      if plural = Pluralization.pluralize(count, language, locale)
        return get_label?("#{target}.#{plural}", language, locale) || target
      end
      target
    end

    private def resolve_non_plural_label(target, language, locale)
      get_label?(target, language, locale) || target
    end

    def get_label(target : String = "", locale : String = "", *, count : (Float | Int)? = nil, **splat)
      language, locale = lang_locale(locale)

      if target != ""
        label = count ? resolve_plural_label(target, count, language, locale) : resolve_non_plural_label(target, language, locale)
      elsif splat.size == 1 && (key = splat.keys[0]?)
        label = "%{#{key}}"
      else
        label = target
      end

      format_label(label, language, locale, count, **splat)
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
end
