module CrI18n
  class Labels
    # Make these gettable here
    getter root_labels, plural_labels, language_labels, locale_labels
  end

  class LabelChecker
    getter target

    def initialize(@labels : Labels, @visited_labels : Array(String), @enforce_parity : Bool, @directory : String)
      @results = [] of String
      @checked = false
      @target = "UNKNOWN"
      @location = "UNKNOWN"
      @filename = "UNKNOWN"
      @line_number = "-1"
      @is_plural = "false"
      @params = ""
      @interpolated = "no"
      @verified_root_label_keys = [] of String
    end

    # ============================= LINE ==============================

    def resolve_target_to_existing_label_target
      @labels.root_labels.keys.find(&.match(regex_for_target))
    end

    def regex_for_target
      /^#{target.gsub(/\./, "\\.").gsub(/#\{.*?\}/, ".*")}(\.other)?$/
    end

    def find_params_from_label
      return nil unless real_target = resolve_target_to_existing_label_target

      label = @labels.root_labels[real_target]
      params = label.scan(/%\{(.*?)\}/).map { |m| m[1] }
      params.empty? ? nil : params
    end

    def params
      return [] of String if @params == ""
      @params.split(",")
    end

    def is_plural?
      @is_plural == "true"
    end

    def is_really_plural?
      resolve_target_to_existing_label_target.try(&.ends_with?(".other"))
    end

    def is_interpolated?
      @interpolated == "interpolated"
    end

    def location
      "#{@filename.gsub(/^#{FileUtils.pwd}/, ".")}:#{@line_number}"
    end

    def add_to_verified_root
      @labels.root_labels.keys.each do |label|
        @verified_root_label_keys << label if label.match(/^#{target.gsub(/\./, "\\.").gsub(/#\{.*?\}/, ".*")}/)
      end
      @verified_root_label_keys.uniq!
    end

    def error(msg)
      @results << "Label '#{target}' at #{location} #{msg}"
    end

    def ensure_plural_use
      if is_plural? && !is_really_plural?
        error("used the `count` parameter, but this label isn't plural (doesn't have the `other` sub field)")
      end

      if !is_plural? && is_really_plural?
        error("is a plural label (has an `other` sub field), but is missing the `count` parameter")
      end
    end

    def ensure_param_consistency
      return unless (expected_params = (find_params_from_label || [] of String)) || !params.empty?

      missing_params = (expected_params - params)
      extra_params = (params - expected_params)

      error("is missing parameters '#{missing_params.join("', '")}' (expecting #{expected_params.join(", ")})") unless missing_params.empty?
      error("has unexpected parameters '#{extra_params.join("', '")}' (expecting #{expected_params.join(", ")})") unless extra_params.empty?
    end

    def check_label_existence
      error("wasn't found in labels loaded from #{@directory}") unless resolve_target_to_existing_label_target
    end

    def partition_label_keys(keys)
      plural_labels = plural_from_keys(keys)
      non_plural = keys.reject { |label| plural_labels.any? { |pl| label.starts_with?(pl) } }
      {plural_labels, non_plural}
    end

    def plural_from_keys(keys)
      keys.select(&.ends_with?(".other")).map!(&.gsub(/\.other$/, ""))
    end

    def label_discrepencies
      # Get the non_plural labels now

      root_plural, root_non_plural = partition_label_keys(@labels.root_labels.keys)

      @labels.language_labels.each do |lang, labels|
        lang_plural, lang_non_plural = partition_label_keys(labels.keys)

        # compare non-plural labels for parity
        (root_non_plural - lang_non_plural).each do |missing_from_lang|
          @results << "Language '#{lang}' is missing non-plural label '#{missing_from_lang}' defined in root labels"
        end

        (lang_non_plural - root_non_plural).each do |extra_lang_label|
          @results << "Language '#{lang}' has extra non-plural label '#{extra_lang_label}' not found in root labels"
        end

        # Now compare plural labels
        (root_plural - lang_plural).each do |missing_from_lang|
          @results << "Language '#{lang}' is missing plural label '#{missing_from_lang}' defined in root labels"
        end

        (lang_plural - root_plural).each do |extra_lang_label|
          @results << "Language '#{lang}' has extra plural label '#{extra_lang_label}' not found in root labels"
        end
      end

      @labels.locale_labels.each do |lang, locales|
        locales.each do |locale, labels|
          locale_plural, locale_non_plural = partition_label_keys(labels.keys)

          # compare non-plural labels for parity
          (root_non_plural - locale_non_plural).each do |missing_from_locale|
            @results << "Locale '#{lang}-#{locale}' is missing non-plural label '#{missing_from_locale}' defined in root labels"
          end

          (locale_non_plural - root_non_plural).each do |extra_locale_label|
            @results << "Locale '#{lang}-#{locale}' has extra non-plural label '#{extra_locale_label}' not found in root labels"
          end

          # Now compare plural labels
          (root_plural - locale_plural).each do |missing_from_locale|
            @results << "Locale '#{lang}-#{locale}' is missing plural label '#{missing_from_locale}' defined in root labels"
          end

          (locale_plural - root_plural).each do |extra_locale_label|
            @results << "Locale '#{lang}-#{locale}' has extra plural label '#{extra_locale_label}' not found in root labels"
          end
        end
      end
    end

    def perform_check
      return @results if @checked

      @visited_labels.each do |label_identifier|
        @target, @filename, @line_number, @is_plural, @params, @interpolated = label_identifier.split(":")

        add_to_verified_root

        ensure_plural_use
        ensure_param_consistency
        check_label_existence
      end

      # Perform the label parity check if applicable
      label_discrepencies if @enforce_parity

      unverified_root_label_keys = (@labels.root_labels.keys - @verified_root_label_keys)
      # Cleanup unverified so that any verified plural labels accounts for all plural labels
      verified_plural = @verified_root_label_keys.select(&.ends_with?(".other"))
      unverified_root_label_keys.reject! { |label| verified_plural.any? { |f| label.starts_with?(f) } }

      # Cleanup unverified so that plural labels only get complained about once
      unverified_plural, unverified_non_plural = partition_label_keys(unverified_root_label_keys)

      @results << "These labels are defined in #{@directory} but weren't used and can be removed:\n\t#{(unverified_plural + unverified_non_plural).join("\n\t")}" unless unverified_root_label_keys.empty?

      @results.sort!
    end
  end
end
