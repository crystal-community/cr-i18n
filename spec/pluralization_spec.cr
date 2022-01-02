require "./spec_helper"

class TestEnglishSurePluralRule < CrI18n::Pluralization::PluralRule
  def for_locale : String
    "en-sure"
  end

  def apply(count : Float | Int) : String
    count == 1 ? "one" : "other"
  end
end

class TestEnglishPluralRule < CrI18n::Pluralization::PluralRule
  def for_locale : Array(String)
    ["en", "en-us"]
  end

  def apply(count : Float | Int) : String
    case count
    when 1 then "one"
    when 2 then "two"
    else        "other"
    end
  end
end

Spectator.describe "Pluralization" do
  it "Pluralizes" do
    CrI18n.load_labels("./spec/plural_spec")
    CrI18n.root_locale = "en"

    CrI18n::Pluralization.auto_register_rules

    expect(CrI18n.get_label("label", "en-sure", count: 1)).to eq "Yeah sure"
    expect(CrI18n.get_label("label", "en-sure", count: 10)).to eq "Way more sures here"
    expect(label("label", "en-sure", count: 1)).to eq "Yeah sure"
    expect(label("label", "en-sure", count: 10)).to eq "Way more sures here"

    expect(CrI18n.get_label("label", "en", count: 1)).to eq "singular"
    expect(CrI18n.get_label("label", "en", count: 2)).to eq "two of 'em"
    expect(CrI18n.get_label("label", "en", count: 3)).to eq "way too many"
    expect(label("label", "en", count: 1)).to eq "singular"
    expect(label("label", "en", count: 2)).to eq "two of 'em"
    expect(label("label", "en", count: 3)).to eq "way too many"

    expect(CrI18n.get_label("label", count: 3)).to eq "way too many"
    expect(CrI18n.get_label("new_label", count: 3)).to eq "The other one"
    expect(label("label", count: 3)).to eq "way too many"
    expect(label("new_label", count: 3)).to eq "The other one"
  end

  it "Pluralizes and falls back to language" do
    CrI18n.load_labels("./spec/plural_spec")
    CrI18n.root_pluralization = "en-us"
    CrI18n::Pluralization.auto_register_rules

    expect(CrI18n.get_label("label", "en", count: 2)).to eq "two of 'em"
    expect(CrI18n.get_label("label", "en-us", count: 2)).to eq "two of 'em"
    expect(CrI18n.get_label("label", "en-uk", count: 2)).to eq "two of 'em"
    expect(CrI18n.get_label("label", "es-uk", count: 5)).to eq "No idea what this is"
  end
end