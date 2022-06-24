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

    def resolve_target_to_existing_label_target(subject = target)
      @labels.root_labels.keys.find(&.match(regex_for_target(subject)))
    end

    def regex_for_target(subject : String = target)
      /^#{subject.gsub(/\./, "\\.").gsub(/#\{.*?\}/, ".*")}(\.other)?$/
    end

    def find_params_from_label
      all_targets = resolve_aliases
      return [] of NamedTuple(alias_path: Array(String), params: Array(String)) if all_targets.empty?

      all_targets.map do |alias_path|
        label = @labels.root_labels[alias_path[-1]]
        {alias_path: alias_path, params: parse_params_from_label(label)}
      end.reject(&.[:params].nil?).map { |el| {alias_path: el[:alias_path], params: el[:params].not_nil!} }
    end

    def parse_params_from_label(label)
      parse_pattern(/%\{(.*?)\}/, label)
    end

    def parse_aliases_from_label(label)
      parse_pattern(/%\((.*?)\)/, label)
    end

    private def parse_pattern(pattern, label)
      pattern_matches = label.scan(pattern).map { |m| m[1] }
      pattern_matches.empty? ? nil : pattern_matches.uniq!
    end

    def params
      return [] of String if @params == ""
      @params.split(",")
    end

    def is_plural?
      @is_plural == "true"
    end

    def is_really_plural?(subject)
      subject.ends_with?(".other")
    end

    def is_interpolated?
      @interpolated == "interpolated"
    end

    def location
      "#{@filename.gsub(/^#{FileUtils.pwd}/, ".")}:#{@line_number}"
    end

    private def resolve_aliases(subject = resolve_target_to_existing_label_target)
      return [] of Array(String) unless subject
      queue = [[subject]]
      queue.each do |current_alias|
        tar = current_alias[-1].not_nil!
        label = @labels.root_labels[resolve_target_to_existing_label_target(tar)]
        if aliases = parse_aliases_from_label(label)
          aliases.each do |al|
            if resolved_alias = resolve_target_to_existing_label_target(al)
              queue << current_alias + [resolved_alias]
            else
              error("references alias '#{al}' which isn't a valid label target")
            end
          end
        end
      end
      queue
    end

    def add_to_verified_root
      resolve_aliases.each do |current_target_path|
        current_target = current_target_path[-1]

        @labels.root_labels.keys.each do |label|
          # current_target is guaranteed to resolve to a valid target in @labels.root_labels.keys
          # Regex that gets created should form:
          # "some.target" => /^some\.target$/
          # "some.#{interpolated}.target" => /^some\..*\.target$/
          # "some.plural.target.other" => /^some\.plural\.target\..*$/
          regex = /^#{current_target.gsub(/\./, "\\.").gsub(/.other$/, "..*").gsub(/#\{.*?\}/, ".*")}$/
          @verified_root_label_keys << label if label.match(regex)
        end
      end

      @verified_root_label_keys.uniq!
    end

    def error(msg, missing = false)
      error_msg = "#{missing ? "Missing l" : "L"}abel '#{target}' at #{location} #{msg}"
      @results << error_msg unless @results.includes?(error_msg)
    end

    def ensure_plural_use
      all_targets = resolve_aliases
      if all_targets.size == 1
        if is_plural? && !is_really_plural?(all_targets[0][0])
          error("used the `count` parameter, but this label isn't plural (doesn't have the `other` sub field)")
        elsif !is_plural? && is_really_plural?(all_targets[0][0])
          error("is a plural label (has an `other` sub field), but is missing the `count` parameter")
        end
      else
        any_plural = all_targets.map(&.last).any?(&.ends_with?(".other"))
        alias_paths = all_targets.map do |path|
          "#{path.map(&.gsub(/\.other$/, "")).join(" -> ")} #{path[-1].ends_with?(".other") ? "(plural)" : "(not plural)"}"
        end.join("\n\t")

        if is_plural? && !any_plural
          error("used the `count` parameter, but this label and none of its used aliases are plural (don't have the `other` sub field):\n\t#{alias_paths}")
        elsif !is_plural? && any_plural
          error("is a plural label, or references an alias that is plural (has an `other` sub field), but is missing the `count` parameter:\n\t#{alias_paths}")
        end
      end
    end

    def ensure_param_consistency
      expected_params = find_params_from_label

      # Nothing to do if we have no params and expected no params
      return if params.empty? && expected_params.empty?
      # Nothing to do if the params we have match exactly the params we expected
      return if params == expected_params.flat_map(&.[:params]).uniq!

      if expected_params.empty? || (expected_params.size == 1 && expected_params[0][:alias_path].size == 1)
        # Base case - we have a label with no params and params were supplied, or we have a label
        # with params and no aliases, and params were supplied but different than expected

        # We ignore the `count` param as it likely won't show up in "one" labels
        missing_params = (expected_params[0][:params] - params - ["count"])
        extra_params = (params - expected_params[0][:params])

        error("is missing parameters '#{missing_params.join("', '")}' #{expected_params.empty? ? "" : "(expecting '#{expected_params[0][:params].join("', '")}')"}") unless missing_params.empty?
        error("has unexpected parameters '#{extra_params.join("', '")}' #{expected_params.empty? ? "" : "(expecting '#{expected_params[0][:params].join("', '")}')"}") unless extra_params.empty?
      else
        # We have a label with aliases that require their own params
        all_expected_params = expected_params.flat_map(&.[:params]).uniq!

        missing_params = (all_expected_params - params - ["count"])
        extra_params = (params - all_expected_params)

        alias_param_path_map = "\n\t#{expected_params.map do |e|
                                        "For #{e[:alias_path].join(" -> ")}, expected '#{e[:params].join("', '")}'"
                                      end.join("\n\t")}"

        # We already know one of these conditions is true, otherwise we would have exited early at the beginning
        error("has extra parameters '#{extra_params.join("', '")}':#{alias_param_path_map}") unless extra_params.empty?
        error("is missing parameters '#{missing_params.join("', '")}':#{alias_param_path_map}") unless missing_params.empty?
      end
    end

    def check_label_existence
      error("wasn't found in labels loaded from #{@directory}", missing: true) unless resolve_target_to_existing_label_target
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
      expected = case root_label_params.size
                 when 0 then " (expected none)"
                 when 1 then ""
                 else        " (expected '#{root_label_params.join("', '")}')"
                 end
      @results << "#{prefix} is missing param#{missing.size > 1 ? "s" : ""} '#{missing.join("', '")}'#{expected}" unless missing.empty?
      @results << "#{prefix} has unexpected param#{extra.size > 1 ? "s" : ""} '#{extra.join("', '")}'#{expected}" unless extra.empty?
    end

    def check_alias_parity(prefix, root_label, other_label)
      root_label_aliases = parse_aliases_from_label(root_label) || [] of String
      other_label_aliases = parse_aliases_from_label(other_label) || [] of String
      return if root_label_aliases.empty? && other_label_aliases.empty?
      return if root_label_aliases == other_label_aliases
      missing = root_label_aliases - other_label_aliases
      extra = other_label_aliases - root_label_aliases
      expected = case root_label_aliases.size
                 when 0 then " (expected none)"
                 when 1 then ""
                 else        " (expected '#{root_label_aliases.join("', '")}')"
                 end
      @results << "#{prefix} is missing alias#{missing.size > 1 ? "es" : ""} '#{missing.join("', '")}'#{expected}" unless missing.empty?
      @results << "#{prefix} has unexpected alias#{extra.size > 1 ? "es" : ""} '#{extra.join("', '")}'#{expected}" unless extra.empty?
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
            check_alias_parity("Language '#{lang}'s label '#{label_key}'", root_label, lang_label)
          end
        end

        root_plural.each do |label_key|
          root_label = @labels.root_labels["#{label_key}.other"]
          labels.keys.select(&.starts_with?(label_key)).each do |check_plural_label|
            check_param_parity("Language '#{lang}' plural label '#{check_plural_label}'", root_label, labels[check_plural_label])
            check_alias_parity("Language '#{lang}' plural label '#{check_plural_label}'", root_label, labels[check_plural_label])
          end
        end

        # TODO: check parity for aliases
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
              check_alias_parity("Locale '#{lang}-#{locale}'s label '#{label_key}'", root_label, locale_label)
            end
          end

          root_plural.each do |label_key|
            root_label = @labels.root_labels["#{label_key}.other"]
            labels.keys.select(&.starts_with?(label_key)).each do |check_plural_label|
              check_param_parity("Locale '#{lang}-#{locale}' plural label '#{check_plural_label}'", root_label, labels[check_plural_label])
              check_alias_parity("Locale '#{lang}-#{locale}' plural label '#{check_plural_label}'", root_label, labels[check_plural_label])
            end
          end

          # TODO: check parity for aliases
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
        check_label_existence

        # No reason to make the other checks if the label doesn't actually exist
        next unless resolve_target_to_existing_label_target

        ensure_plural_use
        ensure_param_consistency
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

      @results << "These labels are defined in #{@directory} but weren't used and can be removed:\n\t#{(unverified_plural + unverified_non_plural).sort.join("\n\t")}" unless unverified_root_label_keys.empty?

      @results.sort!
    end
  end
end
