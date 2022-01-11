require "./spec_helper"
require "time"

Spectator.describe "Discrepencies", puts do
  it "for missing 'other' plural tag are found" do
    labels = CrI18n.load_labels("./spec/discrepency_specs/plural_missing_other")

    disc = labels.label_discrepencies
    expect(disc.size).to eq 3
    expect(disc).to contain "Plural label 'label' is missing the required 'other' plural tag in root labels"
    expect(disc).to contain "Language 'lang' with plural label 'label' is missing the required 'other' plural tag"
    expect(disc).to contain "Locale 'lang-locale' with plural label 'label' is missing the required 'other' plural tag"
  end

  it "for extra labels in language are found" do
    labels = CrI18n.load_labels("./spec/discrepency_specs/extra_label_in_en")

    disc = labels.label_discrepencies
    expect(disc.size).to eq 1
    expect(disc).to contain "Language 'en' has extra non-plural label 'nope' not found in root labels"
  end

  it "for extra labels in locale are found" do
    labels = CrI18n.load_labels("./spec/discrepency_specs/extra_label_in_en-us")

    disc = labels.label_discrepencies
    expect(disc.size).to eq 1
    expect(disc).to contain "Locale 'en-us' has extra non-plural label 'nope' not found in root labels"
  end

  it "for missing labels in language are found" do
    labels = CrI18n.load_labels("./spec/discrepency_specs/missing_label_in_en")

    disc = labels.label_discrepencies
    expect(disc.size).to eq 1
    expect(disc).to contain "Language 'en' is missing non-plural label 'label' defined in root labels"
  end

  it "for missing labels in locale are found" do
    labels = CrI18n.load_labels("./spec/discrepency_specs/missing_label_in_en-us")

    disc = labels.label_discrepencies
    expect(disc.size).to eq 1
    expect(disc).to contain "Locale 'en-us' is missing non-plural label 'label' defined in root labels"
  end
end
