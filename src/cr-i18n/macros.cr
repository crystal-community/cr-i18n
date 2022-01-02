module CrI18n
  macro compiler_load_labels(directory)
  {% begin %}
    CrI18n.load_labels("{{directory.id}}")
    {% CrI18n::LABEL_DIRECTORY.clear %}
    {% CrI18n::LABEL_DIRECTORY << directory %}
    {% CrI18n::DEFINED_LABELS.clear %}
    \{% {{run("./load_valid_labels", directory)}}.each_with_index do |labels, i|
      labels.each { |l| CrI18n::DEFINED_LABELS << l } if i == 0
      labels.each { |l| CrI18n::PLURAL_LABELS << l } if i == 1
    end
    %}
  {% end %}
  end
end

macro label(target, lang_locale = "", count = nil, **splat)
  {% if flag?(:enforce_labels) %}
    {% if !CrI18n::DEFINED_LABELS.empty? && !target.is_a?(StringInterpolation) && !CrI18n::DEFINED_LABELS.includes?("#{target.id}") %}
      {% raise "Missing label '#{target.id}' at #{target.filename.id}:#{target.line_number}, could not be found from #{CrI18n::LABEL_DIRECTORY[0]}" %}
    {% elsif count != nil && !CrI18n::PLURAL_LABELS.includes?("#{target.id}") %}
      {% raise "Label #{target.id} includes a count value '#{count}' but isn't pluralized in the root label file" %}
    {% elsif !CrI18n::DEFINED_LABELS.empty? && target.is_a?(StringInterpolation) %}
      {% puts "Skipping label validation of #{target} due to unknown string interpolation" %}
    {% end %}
  {% end %}
  CrI18n.get_label({{target.is_a?(StringInterpolation) ? target : "#{target.id}"}}, {{lang_locale}}, count: {{count}}, {% for name, val in splat %}{{name.id}}: {{val}},{% end %})
end
