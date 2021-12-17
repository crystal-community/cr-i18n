module CrI18n
  macro compiler_load_labels(directory)
  {% begin %}
    CrI18n.load_labels("{{directory.id}}")
    {% CrI18n::LABEL_DIRECTORY.clear %}
    {% CrI18n::LABEL_DIRECTORY << directory %}
    {% CrI18n::DEFINED_LABELS.clear %}
    \{% {{run("./load_valid_labels", directory)}}.each_with_index do |labels, i|
      labels.each { |l| CrI18n::DEFINED_LABELS << l } if i == 0
    end
    %}
  {% end %}
  end
end

macro label(target, lang = "", locale = "", count = nil, **splat)
  {% if flag?(:enforce_labels) && !CrI18n::DEFINED_LABELS.empty? && !target.is_a?(StringInterpolation) && !CrI18n::DEFINED_LABELS.includes?("#{target.id}") %}
    {% raise "Missing label '#{target.id}' at #{target.filename.id}:#{target.line_number}, could not be found from #{CrI18n::LABEL_DIRECTORY[0]}" %}
  {% elsif flag?(:enforce_labels) && !CrI18n::DEFINED_LABELS.empty? && target.is_a?(StringInterpolation) %}
    {% puts "Skipping label validation of #{target} due to unknown string interpolation" %}
  {% end %}
  {% raise "Label targets can't contain spaces in their names" if "#{target}".includes?(" ") %}
  CrI18n.get_label({{target.is_a?(StringInterpolation) ? target : "#{target.id}"}}, {{lang}}, {{locale}}, count: {{count}}, {% for name, val in splat %}{{name.id}}: {{val}},{% end %})
end
