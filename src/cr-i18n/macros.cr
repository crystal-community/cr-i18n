module I18n
  macro compiler_verify_labels(directory)
  {% begin %}
    I18n::LABEL_DIRECTORY = "{{directory.id}}"
    I18n::DEFINED_LABELS = {{ run("./load_valid_labels", directory) }}
  {% end %}
  end
end

macro label(target)
  {% if I18n.has_constant?(:DEFINED_LABELS) && !target.is_a?(StringInterpolation) && !I18n::DEFINED_LABELS.includes?("#{target.id}") %}
    {% raise "Could not find label #{target.id} in #{I18n::LABEL_DIRECTORY}" %}
  {% elsif I18n.has_constant?(:DEFINED_LABELS) && target.is_a?(StringInterpolation) %}
    {% puts "Skipping label validation of #{target} due to unknown string interpolation" %}
  {% end %}
  {% raise "Label targets can't contain spaces in their names" if "#{target}".includes?(" ") %}
  I18n.get_label({{target.is_a?(StringInterpolation) ? target : "#{target.id}"}})
end
