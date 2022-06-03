module CrI18n
  macro compiler_load_labels(directory)
    {% if flag?(:enforce_labels) || flag?(:enforce_label_parity) %}
    {% raise "Compiler has already loaded labels from #{CrI18n::LABEL_DIRECTORY[1]}, and is now trying to load labels again from #{directory.filename.id}:#{directory.line_number}" unless CrI18n::LABEL_DIRECTORY.empty? %}
    {% CrI18n::LABEL_DIRECTORY << directory %}
    {% CrI18n::LABEL_DIRECTORY << "#{directory.filename.id}:#{directory.line_number}" %}
    {% end %}
    CrI18n.load_labels("{{directory.id}}")
  end
end

macro label(target, lang_locale = "", count = nil, **splat)
  {% if flag?(:enforce_labels) || flag?(:enforce_label_parity)
       resolved_target = "#{target.id}".gsub(/^"|"$/, "")
       var = "#{resolved_target.id}:#{target.filename.id}:#{target.line_number.id}:#{count != nil}:#{splat.keys.sort.join(",").id}:#{target.is_a?(StringInterpolation) ? "interpolated".id : "literal".id}"
       CrI18n::VISITED_LABELS << var unless CrI18n::VISITED_LABELS.includes?(var)
     end %}
  CrI18n.get_label({{target.is_a?(StringInterpolation) ? target : "#{target.id}"}}, {{lang_locale}}, count: {{count}}, {% for name, val in splat %}{{name.id}}: {{val}},{% end %})
end
