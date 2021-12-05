require "./spec_helper"

Spectator.describe "Label loader" do
  it "loads labels" do
    CrI18n.load_labels("./spec/spec1")

    expect(CrI18n.get_label("label")).to eq "label in root"
    expect(CrI18n.get_label("label", "en")).to eq "label in english"
    expect(CrI18n.get_label("label", "en", "us")).to eq "label in american english"

    expect(label("label")).to eq "label in root"
    expect(label("label", "en")).to eq "label in english"
    expect(label("label", "en", "us")).to eq "label in american english"
  end

  it "supports nested labels" do
    labels = CrI18n.load_labels("./spec/spec1")

    expect(labels.get_label("section.nested_section.something")).to eq "yet another label in root"
    expect(labels.get_label("section.nested_section.something", "en")).to eq "yet another label in root"
    expect(labels.get_label("section.nested_section.something", "en", "us")).to eq "yet another label in root"
  end

  it "records missing labels" do
    labels = CrI18n.load_labels("./spec/spec1")

    expect(labels.missed).to eq Set(String).new
    expect(labels.get_label("nope")).to eq "nope"
    expect(labels.missed).to eq Set{"nope"}
    expect(labels.get_label("still nope")).to eq "still nope"
    expect(labels.missed).to eq Set{"nope", "still nope"}
    expect(labels.get_label("nope")).to eq "nope"
    expect(labels.missed).to eq Set{"nope", "still nope"}
  end

  it "raises when missing a label" do
    labels = CrI18n.load_labels("./spec/spec1")

    expect(labels.get_label("nope")).to eq "nope"
    expect(labels.missed).to eq Set{"nope"}

    labels.raise_if_missing = true

    expect { labels.get_label("nope") }.to raise_error("nope")

    labels.raise_if_missing = false

    expect(labels.get_label("nope")).to eq "nope"
    expect(labels.missed).to eq Set{"nope"}
  end

  it "supports parameterized labels" do
    labels = CrI18n.load_labels("./spec/spec1")

    expect(labels.get_label("parameters", "", "", "Tom", "log")).to eq "Tom jumped over the log"
  end

  it "has the compiler check labels" do
    CrI18n.compiler_load_labels("./spec/spec1")
    # Will throw an error at compile time when the -Denforce_labels is specified
    expect(label(does.not.exist)).to eq "does.not.exist"
  end

  it "supports setting language and locale context" do
    labels = CrI18n.load_labels("./spec/spec1")
    labels.with_language("en") do
      expect(labels.get_label("label")).to eq "label in english"
    end

    labels.with_language_and_locale("en", "us") do
      expect(labels.get_label("label")).to eq "label in american english"
    end

    # and nesting
    labels.with_language_and_locale("nope", "still-nope") do
      labels.with_language_and_locale("en", "us") do
        expect(labels.get_label("label")).to eq "label in american english"
      end
    end
  end

  it "static methods support setting language and locale context" do
    CrI18n.load_labels("./spec/spec1")
    CrI18n.with_language("en") do
      expect(CrI18n.get_label("label")).to eq "label in english"
    end

    CrI18n.with_language_and_locale("en", "us") do
      expect(CrI18n.get_label("label")).to eq "label in american english"
    end

    # and nesting
    CrI18n.with_language_and_locale("nope", "still-nope") do
      CrI18n.with_language_and_locale("en", "us") do
        expect(CrI18n.get_label("label")).to eq "label in american english"
      end
    end
  end
end
