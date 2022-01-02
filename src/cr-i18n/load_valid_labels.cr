require "log"
require "json"
require "yaml"
require "./localization"

directory = ARGV[0]

module CrI18n
  class Labels
    getter root_labels, language_labels, locale_labels
  end
end

# Plural rules from https://cldr.unicode.org/index/cldr-spec/plural-rules
plural_endings = {"zero", "one", "two", "few", "many", "other"}

plural_labels = [] of String

labels = CrI18n.load_labels(directory).root_labels.keys

labels.each_with_index do |target, i|
  if plural_endings.includes?(target.split('.')[-1])
    labels[i] = target.rpartition('.')[0]
    plural_labels << labels[i]
  end
end

puts "[#{labels} of String, #{plural_labels} of String]"
