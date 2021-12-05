require "./spec_helper"

Spectator.describe "Label loader" do
  it "loads labels" do
    I18n.load_labels("./spec/spec1")

    expect(I18n.get_label("label")).to eq "label in root"
    expect(I18n.get_label("label", "en")).to eq "label in english"
    expect(I18n.get_label("label", "en", "us")).to eq "label in american english"

    expect(label("label")).to eq "label in root"
    expect(label("label", "en")).to eq "label in english"
    expect(label("label", "en", "us")).to eq "label in american english"
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
    expect(labels.get_label("nope")).to eq "nope"
    expect(labels.missed).to eq Set{"nope"}
    expect(labels.get_label("still nope")).to eq "still nope"
    expect(labels.missed).to eq Set{"nope", "still nope"}
    expect(labels.get_label("nope")).to eq "nope"
    expect(labels.missed).to eq Set{"nope", "still nope"}
  end

  it "raises when missing a label" do
    labels = I18n.load_labels("./spec/spec1")

    expect(labels.get_label("nope")).to eq "nope"
    expect(labels.missed).to eq Set{"nope"}

    labels.raise_if_missing = true

    expect { labels.get_label("nope") }.to raise_error("nope")

    labels.raise_if_missing = false

    expect(labels.get_label("nope")).to eq "nope"
    expect(labels.missed).to eq Set{"nope"}
  end

  it "supports parameterized labels" do
    labels = I18n.load_labels("./spec/spec1")

    expect(labels.get_label("parameters", "", "", "Tom", "log")).to eq "Tom jumped over the log"
  end

  it "has the compiler check labels" do
    I18n.compiler_load_labels("./spec/spec1")
    # Will throw an error at compile time when the -Denforce_labels is specified
    expect(label(does.not.exist)).to eq "does.not.exist"
  end
end
