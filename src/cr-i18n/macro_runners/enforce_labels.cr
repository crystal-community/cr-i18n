require "log"
require "json"
require "yaml"
require "file_utils"
require "../label_loader"
require "../localization"
require "./label_checker"

directory = ARGV[0]
enforce_parity = ARGV[1] == "true"
visited_labels = ARGV[2].split(";")
pluralized_locales = ARGV[3].split(",")

labels = CrI18n.load_labels(directory)

checker = CrI18n::LabelChecker.new(labels, visited_labels, pluralized_locales, enforce_parity, directory)

puts "#{checker.perform_check} of String"
