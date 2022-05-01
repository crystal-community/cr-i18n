require "./spec_helper"

Spectator.describe "Label loader" do
  it "loads labels" do
    CrI18n.load_labels("./spec/spec1")

    expect(CrI18n.get_label("label")).to eq "label in root"
    expect(CrI18n.get_label("label", "en")).to eq "label in english"
    expect(CrI18n.get_label("label", "en-Us")).to eq "label in american english"

    expect(label("label")).to eq "label in root"
    expect(label("label", "en")).to eq "label in english"
    expect(label("label", "en-Us")).to eq "label in american english"
  end

  it "supports nested labels" do
    labels = CrI18n.load_labels("./spec/spec1")

    expect(labels.get_label("section.nested_section.something")).to eq "yet another label in root"
    expect(labels.get_label("section.nested_section.something", "en")).to eq "yet another label in root"
    expect(labels.get_label("section.nested_section.something", "en-Us")).to eq "yet another label in root"
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

    expect { labels.get_label("nope") }.to raise_error("Label nope not found")

    labels.raise_if_missing = false

    expect(labels.get_label("nope")).to eq "nope"
    expect(labels.missed).to eq Set{"nope"}
  end

  it "supports parameterized labels" do
    labels = CrI18n.load_labels("./spec/spec1")

    expect(labels.get_label("parameters", name: "Tom", object: "log")).to eq "Tom jumped over the log"
    expect(label("parameters", name: "Tom", object: "log")).to eq "Tom jumped over the log"
  end

  it "supports setting language and locale context" do
    labels = CrI18n.load_labels("./spec/spec1")
    labels.with_locale("en") do
      expect(labels.get_label("label")).to eq "label in english"
    end

    labels.with_locale("en-Us") do
      expect(labels.get_label("label")).to eq "label in american english"
    end

    # and nesting
    labels.with_locale("nope-still-nope") do
      labels.with_locale("en-Us") do
        expect(labels.get_label("label")).to eq "label in american english"
      end
    end
  end

  it "supports exposing the current language and locale from context" do
    labels = CrI18n.load_labels("./spec/spec1")
    labels.with_locale("en") do
      expect(labels.current_locale).to eq({language: "en", locale: ""})
      expect(CrI18n.current_locale).to eq({language: "en", locale: ""})
    end

    expect(labels.current_locale).to be_nil
    expect(CrI18n.current_locale).to be_nil

    labels.with_locale("en-Us") do
      expect(labels.current_locale).to eq({language: "en", locale: "Us"})
      expect(CrI18n.current_locale).to eq({language: "en", locale: "Us"})
    end

    labels.with_locale("en") do
      expect(labels.current_locale).to eq({language: "en", locale: ""})
      expect(CrI18n.current_locale).to eq({language: "en", locale: ""})

      labels.with_locale("en-Us") do
        expect(labels.current_locale).to eq({language: "en", locale: "Us"})
        expect(CrI18n.current_locale).to eq({language: "en", locale: "Us"})
      end
      expect(labels.current_locale).to eq({language: "en", locale: ""})
      expect(CrI18n.current_locale).to eq({language: "en", locale: ""})
    end
    expect(labels.current_locale).to be_nil
    expect(CrI18n.current_locale).to be_nil
  end

  it "static methods support setting language and locale context" do
    CrI18n.load_labels("./spec/spec1")
    CrI18n.with_locale("en") do
      expect(CrI18n.get_label("label")).to eq "label in english"
    end

    CrI18n.with_locale("en-Us") do
      expect(CrI18n.get_label("label")).to eq "label in american english"
    end

    # and nesting
    CrI18n.with_locale("nope-still-nope") do
      CrI18n.with_locale("en-Us") do
        expect(CrI18n.get_label("label")).to eq "label in american english"
      end
    end
  end

  it "provides the supported locales" do
    CrI18n.load_labels("./spec/spec1")

    expect(CrI18n.supported_locales).to eq ["en", "en-Us"]
  end

  context "with compiler checking" do
    it "has the compiler check labels" do
      # This test doesn't run anything normally, but can be used to test the various compiler checks by uncommenting the lines below
      # and running specs with the '-Denforce_labels' compiler flag

      # FIRST: Uncomment these lines, then uncomment a TEST line and run specs with -Denforce_labels
      # CrI18n.compiler_load_labels("./spec/compiler_spec")
      # CrI18n::Pluralization.auto_register_rules
      # CrI18n.root_pluralization = "en"

      # TEST: compiler should only allow a single 'compiler_load_labels' macro to run
      # CrI18n.compiler_load_labels("./spec/compiler_spec")

      # TEST: Check that non-existent labels throw compiler errors
      # expect(label(does.not.exist)).to eq "does.not.exist"

      # TEST: Check that if a 'count' param is specified, that the label must be plural
      # expect(label(nonplural_label, count: 1)).to eq "nonplural_label"
    end
  end
end

# Uncomment this class when testing the compiler test above
# class CompilerRule < CrI18n::Pluralization::PluralRule
#   LOCALES = ["es", "en-nope", "es-mx"]

#   def apply(count : Int | Float) : String
#     # NO-op
#     "other"
#   end
# end
