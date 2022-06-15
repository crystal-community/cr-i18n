module CrI18n
  class Labels
    # Make these gettable here
    getter root_labels, plural_labels, language_labels, locale_labels
  end

  class LabelChecker
    getter target

    def initialize(@labels : Labels,
                   @visited_labels : Array(String),
                   @pluralized_locales : Array(String),
                   @formatter_types : Array(String),
                   @enforce_parity : Bool,
                   @directory : String)
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

    def resolve_target_to_existing_label_target
      @labels.root_labels.keys.find(&.match(regex_for_target))
    end

    def regex_for_target
      /^#{target.gsub(/\./, "\\.").gsub(/#\{.*?\}/, ".*")}(\.other)?$/
    end

    def find_params_from_label
      return nil unless real_target = resolve_target_to_existing_label_target

      label = @labels.root_labels[real_target]
      parse_params_from_label(label)
    end

    def parse_params_from_label(label)
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
      @results << "Missing label '#{target}' at #{location} #{msg}"
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
      expected_params = find_params_from_label
      return if params.empty? && !expected_params
      return if params == expected_params
      expected_params ||= [] of String

      # We ignore the `count` param as it likely won't show up in "one" labels
      missing_params = (expected_params - params - ["count"])
      extra_params = (params - expected_params)

      error("is missing parameters '#{missing_params.join("', '")}' #{expected_params.empty? ? "" : "(expecting #{expected_params.join(", ")})"}") unless missing_params.empty?
      error("has unexpected parameters '#{extra_params.join("', '")}' #{expected_params.empty? ? "" : "(expecting #{expected_params.join(", ")})"}") unless extra_params.empty?
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

    def check_param_parity(prefix, root_label, other_label)
      root_label_params = parse_params_from_label(root_label) || [] of String
      other_label_params = parse_params_from_label(other_label) || [] of String
      return if root_label_params.empty? && other_label_params.empty?
      return if root_label_params == other_label_params
      missing = root_label_params - other_label_params
      extra = other_label_params - root_label_params
      @results << "#{prefix} is missing param#{missing.size > 1 ? "s" : ""} #{missing.join(", ")} (expected #{root_label_params.join(", ")})" unless missing.empty?
      @results << "#{prefix} has unexpected param#{extra.size > 1 ? "s" : ""} #{extra.join(", ")} (expected #{root_label_params.join(", ")})" unless extra.empty?
    end

    def label_discrepencies
      # Get the non_plural labels now

      root_plural, root_non_plural = partition_label_keys(@labels.root_labels.keys)

      # Check that language labels match root
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

        root_non_plural.each do |label_key|
          if lang_label = labels[label_key]?
            root_label = @labels.root_labels[label_key]
            check_param_parity("Language '#{lang}'s label '#{label_key}'", root_label, lang_label)
          end
        end

        root_plural.each do |label_key|
          root_label = @labels.root_labels["#{label_key}.other"]
          labels.keys.select(&.starts_with?(label_key)).each do |check_plural_label|
            check_param_parity("Language '#{lang}' plural label '#{check_plural_label}'", root_label, labels[check_plural_label])
          end
        end
      end

      # Check that locale labels match root
      @labels.locale_labels.each do |lang, locales|
        # Locales can be missing labels as long as their parent language also has them
        lang_plural, lang_non_plural = partition_label_keys(@labels.language_labels[lang].keys)
        locales.each do |locale, labels|
          locale_plural, locale_non_plural = partition_label_keys(labels.keys)

          # compare non-plural labels for parity
          (root_non_plural - locale_non_plural - lang_non_plural).each do |missing_from_locale|
            @results << "Locale '#{lang}-#{locale}' is missing non-plural label '#{missing_from_locale}' defined in root labels"
          end

          (locale_non_plural - root_non_plural).each do |extra_locale_label|
            @results << "Locale '#{lang}-#{locale}' has extra non-plural label '#{extra_locale_label}' not found in root labels"
          end

          # Now compare plural labels
          (root_plural - locale_plural - lang_plural).each do |missing_from_locale|
            @results << "Locale '#{lang}-#{locale}' is missing plural label '#{missing_from_locale}' defined in root labels"
          end

          (locale_plural - root_plural).each do |extra_locale_label|
            @results << "Locale '#{lang}-#{locale}' has extra plural label '#{extra_locale_label}' not found in root labels"
          end

          root_non_plural.each do |label_key|
            if locale_label = labels[label_key]?
              root_label = @labels.root_labels[label_key]
              check_param_parity("Locale '#{lang}-#{locale}'s label '#{label_key}'", root_label, locale_label)
            end
          end

          root_plural.each do |label_key|
            root_label = @labels.root_labels["#{label_key}.other"]
            labels.keys.select(&.starts_with?(label_key)).each do |check_plural_label|
              check_param_parity("Locale '#{lang}-#{locale}' plural label '#{check_plural_label}'", root_label, labels[check_plural_label])
            end
          end
        end
      end
    end

    def check_formatters
      formatter_types = @labels.root_labels.keys.select(&.match(/^cri18n\.formatters\.[a-zA-Z0-9]+\.type$/)).map(&.split(".")[2])
      formatter_types.each do |name|
        if name == "count"
          @results << "Parameter `count` is used for plural labels and can't be assigned a formatter"
        else
          type = @labels.root_labels["cri18n.formatters.#{name}.type"]
          @results << "No formatter for 'cri18n.formatters.#{name}' using type '#{type}' found (supported types are #{@formatter_types.join(", ")})" unless @formatter_types.includes?(type)
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

      if @enforce_parity
        # Check that we have pluralization support for all discovered locales
        (@labels.supported_locales - @pluralized_locales.uniq).each do |unpluralized_locale|
          @results << "#{unpluralized_locale.includes?("-") ? "Locale" : "Language"} '#{unpluralized_locale}' doesn't have a plural rule that supports it"
        end

        # Perform the label parity check
        label_discrepencies
      end

      check_formatters

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
