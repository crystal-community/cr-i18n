require "spectator"
require "../src/cr-i18n"

macro if_enforce
  {% if flag?(:enforce_labels) || flag?(:enforce_label_parity) %}
    {{yield}}
  {% end %}
end

macro unless_enforce
  {% if !flag?(:enforce_labels) && !flag?(:enforce_label_parity) %}
    {{yield}}
  {% end %}
end
