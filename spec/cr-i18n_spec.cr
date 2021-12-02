require "./spec_helper"

Spectator.describe "Label loader" do
  it "loads labels" do
    I18n.load_labels("./spec/spec1")

    expect(I18n.get_label("label")).to eq "label in root"
    expect(I18n.get_label("label", "en")).to eq "label in english"
    expect(I18n.get_label("label", "en", "us")).to eq "label in american english"
  end

  it "supports nested labels" do
    labels = I18n.load_labels("./spec/spec1")

    expect(labels.get_label("section.nested_section.something")).to eq "yet another label in root"
    expect(labels.get_label("section.nested_section.something", "en")).to eq "yet another label in root"
    expect(labels.get_label("section.nested_section.something", "en", "us")).to eq "yet another label in root"
  end

  it "records missing labels" do
    labels = I18n.load_labels("./spec/spec1")

    expect(labels.missed).to eq Set(String).new
    expect(labels.get_label("nope")).to eq "Label for 'nope' not defined"
    expect(labels.missed).to eq Set{"nope"}
    expect(labels.get_label("still nope")).to eq "Label for 'still nope' not defined"
    expect(labels.missed).to eq Set{"nope", "still nope"}
    expect(labels.get_label("nope")).to eq "Label for 'nope' not defined"
    expect(labels.missed).to eq Set{"nope", "still nope"}
  end

  it "raises when missing a label" do
    labels = I18n.load_labels("./spec/spec1")

    expect(labels.get_label("nope")).to eq "Label for 'nope' not defined"
    expect(labels.missed).to eq Set{"nope"}

    labels.raise_if_missing = true

    expect { labels.get_label("nope") }.to raise_error("Label for 'nope' not defined")

    labels.raise_if_missing = false

    expect(labels.get_label("nope")).to eq "Label for 'nope' not defined"
    expect(labels.missed).to eq Set{"nope"}
  end
end
