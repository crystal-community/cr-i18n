require "./spec_helper"
require "file_utils"
require "../src/cr-i18n/macro_runners/label_checker"

unless_enforce do
  Spectator.describe CrI18n::LabelChecker do
    let(dir) { "the_directory" }
    let(line_number) { "4" }

    def checker(visitors)
      CrI18n::LabelChecker.new(labels, visitors, false, dir)
    end

    context "with basic checks" do
      let(labels) { CrI18n.load_labels("./spec/checker_specs/basic") }

      # let(checker) { CrI18n::LabelChecker.new(labels, visited, false, dir) }
      it "returns no errors if there are none" do
        expect(checker(["labels.exists:filename:4:false::literal"]).perform_check).to eq [] of String
      end

      it "raises errors for unused labels" do
        expect(checker([] of String).perform_check).to eq ["These labels are defined in the_directory but weren't used and can be removed:\n\tlabels.exists"]
      end

      it "raises errors for non-existent labels" do
        expect(checker(["labels.does.not.exist:filename:4:false::literal", "labels.exists:filename:4:false::literal"]).perform_check).to eq ["Label 'labels.does.not.exist' at filename:4 wasn't found in labels loaded from the_directory"]
      end

      it "raises errors for non-plural label being used as plural" do
        expect(checker(["labels.exists:filename:4:true::literal"]).perform_check).to eq ["Label 'labels.exists' at filename:4 used the `count` parameter, but this label isn't plural (doesn't have the `other` sub field)"] of String
      end

      it "correctly matches interpolated string" do
        expect(checker(["labels.\#{whatever}:filename:4:false::interpolated"]).perform_check).to eq [] of String
      end
    end

    context "with plural labels" do
      let(labels) { CrI18n.load_labels("./spec/checker_specs/basic_plural") }

      it "raises only the single plural label when not used" do
        expect(checker([] of String).perform_check).to eq ["These labels are defined in the_directory but weren't used and can be removed:\n\tlabels.exists"]
      end
      it "raises errors for plural label not being used as plural" do
        expect(checker(["labels.exists:filename:4:false::literal"]).perform_check).to eq ["Label 'labels.exists' at filename:4 is a plural label (has an `other` sub field), but is missing the `count` parameter"]
      end
    end

    context "with params" do
      let(labels) { CrI18n.load_labels("./spec/checker_specs/basic_param") }
      it "raises error when missing paramater" do
        expect(checker(["labels.exists:filename:4:false:name:literal"]).perform_check).to eq ["Label 'labels.exists' at filename:4 is missing parameters 'location' (expecting location, name)"]
      end

      it "raises error when unexpected parameter gets used" do
        expect(checker(["labels.exists:filename:4:false:name,location,nope:literal"]).perform_check).to eq ["Label 'labels.exists' at filename:4 has unexpected parameters 'nope' (expecting location, name)"]
      end

      it "raises no errors when all parameters are used correctly" do
        expect(checker(["labels.exists:filename:4:false:name,location:literal"]).perform_check).to eq [] of String
      end
    end

    context "with label parity" do
      context "when checking languages" do
      end
      context "when checking locales" do
      end
    end
  end
end
