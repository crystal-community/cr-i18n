require "./spec_helper"

Spectator.describe "Label loader" do
  it "loads labels" do
    Localization.load_labels("./spec/spec1")

    expect(Localization.get_label("label")).to eq "label in root"
    expect(Localization.get_label("label", "en")).to eq "label in english"
    expect(Localization.get_label("label", "en", "us")).to eq "label in american english"
  end

  it "supports nested labels" do
    labels = Localization.load_labels("./spec/spec1")

    expect(labels.get_label("section.nested_section.something")).to eq "yet another label in root"
    expect(labels.get_label("section.nested_section.something", "en")).to eq "yet another label in root"
    expect(labels.get_label("section.nested_section.something", "en", "us")).to eq "yet another label in root"
  end
end
