module CrI18n
  macro compiler_load_labels(directory)
  {% begin %}
    {% raise "Compiler has already loaded labels from #{CrI18n::COMPILER_LOADED[0]}, and is now trying to load labels again from #{directory.filename.id}:#{directory.line_number}" unless CrI18n::COMPILER_LOADED.empty? %}
    {% CrI18n::LABEL_DIRECTORY << directory %}
    \{% {{run("./load_valid_labels", directory, Pluralization::PluralRule.subclasses.map { |s| s.constant("LOCALES").join(",") }.select { |s| s.size > 0 }.join(","))}}.each_with_index do |labels, i|
      # Poor man's flatten in macros when macros don't support `flatten`
      valid_locales = CrI18n::Pluralization::PluralRule.subclasses.map { |m| m.constant("LOCALES").join(",") }.join(",").split(",").sort.join(", ")
      raise "Found locales or languages that don't have plural rules: #{labels.sort.join(", ").id}. Current plural rules support these languages and locales: #{valid_locales.id}" if labels.size > 0 && i == 0 && (flag?(:enforce_labels) || flag?(:enforce_label_parity))
      raise "Found label discrepencies:\n#{labels.join("\n").id}" if labels.size > 0 && i == 1 && flag?(:enforce_label_parity)
      labels.each { |l| CrI18n::DEFINED_LABELS << l } if i == 2
      labels.each { |l| CrI18n::PLURAL_LABELS << l } if i == 3
    end
    %}
    {% CrI18n::COMPILER_LOADED.clear %}
    # Record where we loaded labels from for the compiler
    {% CrI18n::COMPILER_LOADED << "#{directory.filename.id}:#{directory.line_number}" %}
    # And then officially load the labels, letting the returned labels be the returned object
    CrI18n.load_labels("{{directory.id}}")
  {% end %}
  end
end

macro label(target, lang_locale = "", count = nil, **splat)
  {% if flag?(:enforce_labels) %}
    {% if !CrI18n::DEFINED_LABELS.empty? && !target.is_a?(StringInterpolation) && count == nil && !CrI18n::DEFINED_LABELS.includes?("#{target.id}") %}
      {% raise "Missing label '#{target.id}' at #{target.filename.id}:#{target.line_number}, could not be found from #{CrI18n::LABEL_DIRECTORY[0]}" %}
    {% elsif count != nil && !CrI18n::PLURAL_LABELS.includes?("#{target.id}") %}
      {% raise "Label #{target.id} includes a count value '#{count}' but isn't pluralized in the root label file" %}
    {% elsif !CrI18n::DEFINED_LABELS.empty? && target.is_a?(StringInterpolation) %}
      {% puts "Skipping label validation of #{target} due to unknown string interpolation" %}
    {% end %}
  {% end %}
  CrI18n.get_label({{target.is_a?(StringInterpolation) ? target : "#{target.id}"}}, {{lang_locale}}, count: {{count}}, {% for name, val in splat %}{{name.id}}: {{val}},{% end %})
end
