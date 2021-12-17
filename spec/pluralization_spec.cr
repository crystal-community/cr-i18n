require "./spec_helper"

class TestEnglishSurePluralRule < CrI18n::Pluralization::PluralRule
  def for_lang_and_locale
    {language: "en", locale: "sure"}
  end

  def apply(count : Float | Int) : String
    count == 1 ? "one" : "other"
  end
end

class TestEnglishPluralRule < CrI18n::Pluralization::PluralRule
  def for_language
    "en"
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

    expect(CrI18n.get_label("label", "en", "sure", count: 1)).to eq "Yeah sure"
    expect(CrI18n.get_label("label", "en", "sure", count: 10)).to eq "Way more sures here"
    expect(label("label", "en", "sure", count: 1)).to eq "Yeah sure"
    expect(label("label", "en", "sure", count: 10)).to eq "Way more sures here"

    expect(CrI18n.get_label("label", "en", count: 1)).to eq "singular"
    expect(CrI18n.get_label("label", "en", count: 2)).to eq "two of 'em"
    expect(CrI18n.get_label("label", "en", count: 3)).to eq "way too many"
    expect(label("label", "en", count: 1)).to eq "singular"
    expect(label("label", "en", count: 2)).to eq "two of 'em"
    expect(label("label", "en", count: 3)).to eq "way too many"

    expect(CrI18n.get_label("label", count: 3)).to eq "There's a label here"
    expect(label("label", count: 3)).to eq "There's a label here"
  end
end
