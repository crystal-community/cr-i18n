module I18n
  macro compiler_load_labels(directory)
  {% begin %}
    I18n.load_labels("{{directory.id}}")
    {% I18n::LABEL_DIRECTORY.clear %}
    {% I18n::LABEL_DIRECTORY << directory %}
    {% I18n::DEFINED_LABELS.clear %}
    \{% {{run("./load_valid_labels", directory)}}.each { |l| I18n::DEFINED_LABELS << l } %}
  {% end %}
  end
end

macro label(target, lang = "", locale = "")
  {% if flag?(:enforce_labels) && !I18n::DEFINED_LABELS.empty? && !target.is_a?(StringInterpolation) && !I18n::DEFINED_LABELS.includes?("#{target.id}") %}
    {% raise "Missing label #{target.id}, could not be found from #{I18n::LABEL_DIRECTORY[0]}" %}
  {% elsif flag?(:enforce_labels) && !I18n::DEFINED_LABELS.empty? && target.is_a?(StringInterpolation) %}
    {% puts "Skipping label validation of #{target} due to unknown string interpolation" %}
  {% end %}
  {% raise "Label targets can't contain spaces in their names" if "#{target}".includes?(" ") %}
  I18n.get_label({{target.is_a?(StringInterpolation) ? target : "#{target.id}"}}, {{lang}}, {{locale}})
end
