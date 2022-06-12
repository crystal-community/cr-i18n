module CrI18n
  def self.enforce_labels
    {% begin %}
    \{%
      errors = {{run("./macro_runners/enforce_labels",
                   CrI18n::LABEL_DIRECTORY[0],
                   flag?(:enforce_label_parity),
                   CrI18n::VISITED_LABELS.join(";"),
                   CrI18n::Pluralization::PluralRule.subclasses.map(&.constant("LOCALES").join(",")).join(",").split(",").sort.join(",")
                 )}}
      raise "Found errors in compiled labels under #{CrI18n::LABEL_DIRECTORY[0]}:\n\n#{errors.join("\n").id}" unless errors.empty?
    %}
    {% end %}
  end
end

macro finished
  {% if flag?(:enforce_labels) || flag?(:enforce_label_parity) %}
  CrI18n.enforce_labels
  {% end %}
end
