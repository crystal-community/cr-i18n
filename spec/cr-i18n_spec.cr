require "./spec_helper"

Spectator.describe "Label loader" do
  it "loads labels" do
    Localization.load_labels("./spec/spec1")

    expect(Localization.get_label("label")).to eq "label in root"
    expect(Localization.get_label("label", "en")).to eq "label in english"
    expect(Localization.get_label("label", "en", "us")).to eq "label in american english"
  end
end
