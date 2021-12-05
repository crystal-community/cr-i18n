require "log"
require "json"
require "yaml"
require "./localization"

directory = ARGV[0]

module I18n
  class Labels
    getter root_labels
  end
end

labels = I18n.load_labels(directory)

puts labels.root_labels.keys.to_s
