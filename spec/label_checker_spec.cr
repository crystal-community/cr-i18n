require "./spec_helper"
require "file_utils"
require "../src/cr-i18n/macro_runners/label_checker"

unless_enforce do
  Spectator.describe CrI18n::LabelChecker do
    let(dir) { "the_directory" }
    let(line_number) { "4" }
    # TODO: implement tests for this
    let(pluralized_locales) { ["en", "en-us"] of String }
    # TODO: specs for these too
    let(formatter_types) { [] of String }

    def checker(visitors, labels = labels, enforce_parity = false, dir = dir)
      CrI18n::LabelChecker.new(labels, visitors, pluralized_locales, formatter_types, enforce_parity, dir)
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
        expect(checker(["labels.does.not.exist:filename:4:false::literal", "labels.exists:filename:4:false::literal"]).perform_check).to eq ["Missing label 'labels.does.not.exist' at filename:4 wasn't found in labels loaded from the_directory"]
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
      context "when checki]ng languages" do
        it "checks for extra labels in language" do
          labels = CrI18n.load_labels("./spec/discrepency_specs/extra_label_in_en")
          expect(checker(["label:filename:4:false::literal"] of String, labels: labels, enforce_parity: true).perform_check).to eq ["Language 'en' has extra non-plural label 'nope' not found in root labels"]
        end

        it "checks for missing labels in language" do
          labels = CrI18n.load_labels("./spec/discrepency_specs/missing_label_in_en")
          expect(checker(["label:filename:4:false::literal", "extra:filename:4:false::literal"] of String,
            labels: labels,
            enforce_parity: true).perform_check).to eq ["Language 'en' is missing non-plural label 'label' defined in root labels"]
        end
      end
      context "when checking locales" do
        it "checks for extra labels in locale" do
          labels = CrI18n.load_labels("./spec/discrepency_specs/extra_label_in_en-us")
          expect(checker(["label:filename:4:false::literal"] of String, labels: labels, enforce_parity: true).perform_check).to eq ["Locale 'en-us' has extra non-plural label 'nope' not found in root labels"] of String
        end

        it "checks for missing labels in locale" do
          labels = CrI18n.load_labels("./spec/discrepency_specs/missing_label_in_en-us")
          expect(checker(["label:filename:4:false::literal", "extra:filename:4:false::literal"] of String,
            labels: labels,
            enforce_parity: true).perform_check).to eq ["Language 'en' is missing non-plural label 'label' defined in root labels", "Locale 'en-us' is missing non-plural label 'label' defined in root labels"] of String
        end
      end
    end
  end
end
