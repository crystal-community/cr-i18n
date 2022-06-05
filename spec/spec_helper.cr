require "spectator"
require "../src/cr-i18n"

macro if_enforce
  {% if flag?(:enforce_labels) %}
    {{yield}}
  {% end %}
end

macro unless_enforce
  {% if !flag?(:enforce_labels) %}
    {{yield}}
  {% end %}
end
