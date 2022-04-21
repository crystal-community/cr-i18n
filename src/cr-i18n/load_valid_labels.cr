require "log"
require "json"
require "yaml"
require "./localization"

directory = ARGV[0]
pluralized_locales = ARGV[1].split(/\s*,\s*/)

module CrI18n
  class Labels
    getter root_labels, plural_labels, language_labels, locale_labels
  end
end

labels = CrI18n.load_labels(directory)

non_plural = Set(String).new

labels.root_labels.keys.each do |label|
  non_plural << label unless labels.plural_labels.includes?(label.rpartition('.')[0])
end

# Put the error cases first, followed by the supported lists of labels
puts "[#{labels.supported_locales - pluralized_locales} of String, #{labels.label_discrepencies} of String, #{non_plural.to_a} of String, #{labels.plural_labels.to_a} of String]"
