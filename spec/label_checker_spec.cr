require "./spec_helper"
require "file_utils"
require "../src/cr-i18n/macro_runners/label_checker"

unless_enforce do
  Spectator.describe CrI18n::LabelChecker do
    let(dir) { "the_directory" }
    # TODO: implement tests for this
    let(pluralized_locales) { ["en", "en-us"] of String }
    # TODO: specs for these too
    let(formatter_types) { [] of String }

    def checker(visitors, labels = labels, enforce_parity = false, dir = dir)
      CrI18n::LabelChecker.new(labels, visitors, pluralized_locales, formatter_types, enforce_parity, dir)
    end

    def visitors_for(target, *, params = "", is_plural = false)
      [visitor_for(target, params: params, is_plural: is_plural)]
    end

    def visitor_for(target, *, params = "", is_plural = false)
      "#{target}:filename:4:#{is_plural}:#{params}:#{target.includes?(%q[#{]) ? "interpolated" : "literal"}"
    end

    context "with basic checks" do
      let(labels) { CrI18n.load_labels("./spec/checker_specs/basic") }

      # let(checker) { CrI18n::LabelChecker.new(labels, visited, false, dir) }
      it "returns no errors if there are none" do
        expect(checker(visitors_for("labels.exists")).perform_check).to eq [] of String
      end

      it "raises errors for unused labels" do
        expect(checker([] of String).perform_check).to eq [
          "These labels are defined in the_directory but weren't used and can be removed:\n\tlabels.exists",
        ]
      end

      it "raises errors for non-existent labels" do
        expect(checker([visitor_for("labels.does.not.exist"), visitor_for("labels.exists")]).perform_check).to eq [
          "Missing label 'labels.does.not.exist' at filename:4 wasn't found in labels loaded from the_directory",
        ]
      end

      it "raises errors for non-plural label being used as plural" do
        expect(checker(visitors_for("labels.exists", is_plural: true)).perform_check).to eq [
          "Label 'labels.exists' at filename:4 used the `count` parameter, but this label isn't plural (doesn't have the `other` sub field)",
        ]
      end

      it "correctly matches interpolated string" do
        expect(checker(visitors_for("labels.\#{whatever}")).perform_check).to eq [] of String
      end
    end

    context "with plural labels" do
      let(labels) { CrI18n.load_labels("./spec/checker_specs/basic_plural") }

      it "raises only the single plural label when not used" do
        expect(checker([] of String).perform_check).to eq [
          "These labels are defined in the_directory but weren't used and can be removed:\n\tlabels.exists",
        ]
      end

      it "raises errors for plural label not being used as plural" do
        expect(checker(visitors_for("labels.exists")).perform_check).to eq [
          "Label 'labels.exists' at filename:4 is a plural label (has an `other` sub field), but is missing the `count` parameter",
        ]
      end
    end

    context "with params" do
      let(labels) { CrI18n.load_labels("./spec/checker_specs/basic_param") }
      it "raises error when missing paramater" do
        expect(checker(visitors_for("labels.exists", params: "name")).perform_check).to eq [
          "Label 'labels.exists' at filename:4 is missing parameters 'location' (expecting 'location', 'name')",
          "These labels are defined in the_directory but weren't used and can be removed:\n\tlabels.no_params",
        ]
      end

      it "raises error when unexpected parameter gets used" do
        expect(checker(visitors_for("labels.exists", params: "name,location,nope")).perform_check).to eq [
          "Label 'labels.exists' at filename:4 has unexpected parameters 'nope' (expecting 'location', 'name')",
          "These labels are defined in the_directory but weren't used and can be removed:\n\tlabels.no_params",
        ]
      end

      it "raises no errors when all parameters are used correctly" do
        expect(checker(visitors_for("labels.exists", params: "name,location")).perform_check).to eq [
          "These labels are defined in the_directory but weren't used and can be removed:\n\tlabels.no_params",
        ]
      end

      it "ignores parameters for labels that don't exist" do
        expect(checker([visitor_for("labels.not.exists", params: "param"), visitor_for("labels.exists", params: "name,location")]).perform_check).to eq [
          "Missing label 'labels.not.exists' at filename:4 wasn't found in labels loaded from the_directory",
          "These labels are defined in the_directory but weren't used and can be removed:\n\tlabels.no_params",
        ]
      end

      it "raises error when there are no expected params and params are supplied" do
        expect(checker(visitors_for("labels.no_params", params: "something")).perform_check).to eq [
          "Label 'labels.no_params' at filename:4 has unexpected parameters 'something' ",
          "These labels are defined in the_directory but weren't used and can be removed:\n\tlabels.exists",
        ]
      end

      context "and label parity" do
        it "enforces param parity between locales" do
          checks = checker(visitors_for("labels.exists"), enforce_parity: true).perform_check

          expect(checks).to contain(
            "Locale 'en-us's label 'labels.exists' has unexpected param 'todd' (expected 'location', 'name')"
          )
          expect(checks).to contain(
            "Locale 'en-us's label 'labels.exists' is missing param 'name' (expected 'location', 'name')",
          )
        end

        it "enforces param parity between languages" do
          expect(checker(visitors_for("labels.exists"), enforce_parity: true).perform_check).to contain(
            "Language 'en's label 'labels.exists' is missing param 'name' (expected 'location', 'name')"
          )
        end
      end
    end

    context "with label parity" do
      context "when checking languages" do
        it "checks for extra labels in language" do
          labels = CrI18n.load_labels("./spec/discrepency_specs/extra_label_in_en")
          expect(checker(visitors_for("label"), labels: labels, enforce_parity: true).perform_check).to eq [
            "Language 'en' has extra non-plural label 'nope' not found in root labels",
          ]
        end

        it "checks for missing labels in language" do
          labels = CrI18n.load_labels("./spec/discrepency_specs/missing_label_in_en")
          expect(checker([visitor_for("label"), visitor_for("extra")] of String,
            labels: labels,
            enforce_parity: true).perform_check).to eq [
            "Language 'en' is missing non-plural label 'label' defined in root labels",
          ]
        end
      end
      context "when checking locales" do
        it "checks for extra labels in locale" do
          labels = CrI18n.load_labels("./spec/discrepency_specs/extra_label_in_en-us")
          expect(checker(visitors_for("label"), labels: labels, enforce_parity: true).perform_check).to eq [
            "Locale 'en-us' has extra non-plural label 'nope' not found in root labels",
          ]
        end

        it "checks for missing labels in locale" do
          labels = CrI18n.load_labels("./spec/discrepency_specs/missing_label_in_en-us")
          expect(checker([visitor_for("label"), visitor_for("extra")],
            labels: labels,
            enforce_parity: true).perform_check).to eq [
            "Language 'en' is missing non-plural label 'label' defined in root labels", "Locale 'en-us' is missing non-plural label 'label' defined in root labels",
          ]
        end
      end
    end

    context "with aliases" do
      context "basically" do
        let(labels) { CrI18n.load_labels("./spec/checker_specs/alias_basic_nested") }

        it "identifies labels as visited when only referenced through alias" do
          expect(checker(visitors_for("aliases.basic")).perform_check).to eq [
            "These labels are defined in the_directory but weren't used and can be removed:\n\taliases.nested\n\taliases.nope",
          ]
          expect(checker(visitors_for("aliases.nested")).perform_check).to eq [
            "These labels are defined in the_directory but weren't used and can be removed:\n\taliases.nope",
          ]
        end

        it "identifies non-existent aliases" do
          expect(checker(visitors_for("aliases.nope")).perform_check).to eq [
            "Label 'aliases.nope' at filename:4 references alias 'labels.nope' which isn't a valid label target",
            "These labels are defined in the_directory but weren't used and can be removed:\n\taliases.basic\n\taliases.nested\n\tlabel",
          ]
        end
      end

      context "using params" do
        let(labels) { CrI18n.load_labels("./spec/checker_specs/alias_params") }

        it "supports params alongside aliases" do
          expect(checker(visitors_for("aliases.alias_alongside_param", params: "param")).perform_check).to eq [
            "These labels are defined in the_directory but weren't used and can be removed:\n\taliases.alias_to_param\n\taliases.alias_with_params\n\tlabel_with_params",
          ]
          expect(checker(visitors_for("aliases.alias_alongside_param")).perform_check).to eq [
            "Label 'aliases.alias_alongside_param' at filename:4 is missing parameters 'param' (expecting 'param')",
            "These labels are defined in the_directory but weren't used and can be removed:\n\taliases.alias_to_param\n\taliases.alias_with_params\n\tlabel_with_params",
          ]
        end

        it "verifies params that are required by child aliases" do
          expect(checker(visitors_for("aliases.alias_to_param", params: "param1")).perform_check).to eq [
            "These labels are defined in the_directory but weren't used and can be removed:\n\taliases.alias_alongside_param\n\taliases.alias_with_params\n\tlabel",
          ]

          expect(checker(visitors_for("aliases.alias_to_param", params: "param1,param2")).perform_check).to eq [
            "Label 'aliases.alias_to_param' at filename:4 has extra parameters 'param2':\n\tFor aliases.alias_to_param -> label_with_params, expected 'param1'",
            "These labels are defined in the_directory but weren't used and can be removed:\n\taliases.alias_alongside_param\n\taliases.alias_with_params\n\tlabel",
          ]

          expect(checker(visitors_for("aliases.alias_to_param")).perform_check).to eq [
            "Label 'aliases.alias_to_param' at filename:4 is missing parameters 'param1':\n\tFor aliases.alias_to_param -> label_with_params, expected 'param1'",
            "These labels are defined in the_directory but weren't used and can be removed:\n\taliases.alias_alongside_param\n\taliases.alias_with_params\n\tlabel",
          ]
        end

        it "verifies params _and_ nested required params" do
          expect(checker(visitors_for("aliases.alias_with_params", params: "param1,param2")).perform_check).to eq [
            "These labels are defined in the_directory but weren't used and can be removed:\n\taliases.alias_alongside_param\n\tlabel",
          ]

          expect(checker(visitors_for("aliases.alias_with_params", params: "param1")).perform_check).to eq [
            "Label 'aliases.alias_with_params' at filename:4 is missing parameters 'param2':\n\tFor aliases.alias_with_params, expected 'param2'\n\tFor aliases.alias_with_params -> aliases.alias_to_param -> label_with_params, expected 'param1'",
            "These labels are defined in the_directory but weren't used and can be removed:\n\taliases.alias_alongside_param\n\tlabel",
          ]

          expect(checker(visitors_for("aliases.alias_with_params", params: "param2")).perform_check).to eq [
            "Label 'aliases.alias_with_params' at filename:4 is missing parameters 'param1':\n\tFor aliases.alias_with_params, expected 'param2'\n\tFor aliases.alias_with_params -> aliases.alias_to_param -> label_with_params, expected 'param1'",
            "These labels are defined in the_directory but weren't used and can be removed:\n\taliases.alias_alongside_param\n\tlabel",
          ]

          expect(checker(visitors_for("aliases.alias_with_params", params: "param1,param2,param3")).perform_check).to eq [
            "Label 'aliases.alias_with_params' at filename:4 has extra parameters 'param3':\n\tFor aliases.alias_with_params, expected 'param2'\n\tFor aliases.alias_with_params -> aliases.alias_to_param -> label_with_params, expected 'param1'",
            "These labels are defined in the_directory but weren't used and can be removed:\n\taliases.alias_alongside_param\n\tlabel",
          ]
        end
      end

      context "with plurality" do
        let(labels) { CrI18n.load_labels("./spec/checker_specs/alias_plurality") }

        it "supports aliasing to plural labels" do
          expect(checker(visitors_for("aliases.nonplural_alias", is_plural: true)).perform_check).to eq [
            "These labels are defined in the_directory but weren't used and can be removed:\n\taliases.plural_alias\n\taliases.plural_alias_with_params\n\taliases.plural_alias_with_plural_label\n\tnonplural_label",
          ]

          expect(checker(visitors_for("aliases.nonplural_alias", is_plural: false)).perform_check).to eq [
            "Label 'aliases.nonplural_alias' at filename:4 is a plural label, or references an alias that is plural (has an `other` sub field), but is missing the `count` parameter:\n\taliases.nonplural_alias (not plural)\n\taliases.nonplural_alias -> label (plural)",
            "These labels are defined in the_directory but weren't used and can be removed:\n\taliases.plural_alias\n\taliases.plural_alias_with_params\n\taliases.plural_alias_with_plural_label\n\tnonplural_label",
          ]
        end

        it "supports having plural aliases" do
          expect(checker(visitors_for("aliases.plural_alias", is_plural: true)).perform_check).to eq [
            "These labels are defined in the_directory but weren't used and can be removed:\n\taliases.nonplural_alias\n\taliases.plural_alias_with_params\n\taliases.plural_alias_with_plural_label\n\tlabel",
          ]

          expect(checker(visitors_for("aliases.plural_alias", is_plural: false)).perform_check).to eq [
            "Label 'aliases.plural_alias' at filename:4 is a plural label, or references an alias that is plural (has an `other` sub field), but is missing the `count` parameter:\n\taliases.plural_alias (plural)\n\taliases.plural_alias -> nonplural_label (not plural)",
            "These labels are defined in the_directory but weren't used and can be removed:\n\taliases.nonplural_alias\n\taliases.plural_alias_with_params\n\taliases.plural_alias_with_plural_label\n\tlabel",
          ]
        end

        it "supports having plural aliases with plural labels" do
          expect(checker(visitors_for("aliases.plural_alias_with_plural_label", is_plural: true)).perform_check).to eq [
            "These labels are defined in the_directory but weren't used and can be removed:\n\taliases.nonplural_alias\n\taliases.plural_alias\n\taliases.plural_alias_with_params\n\tnonplural_label",
          ]
        end

        it "still supports params and plural labels" do
          expect(checker(visitors_for("aliases.plural_alias_with_params", params: "param1", is_plural: true)).perform_check).to eq [
            "These labels are defined in the_directory but weren't used and can be removed:\n\taliases.nonplural_alias\n\taliases.plural_alias\n\taliases.plural_alias_with_plural_label\n\tlabel",
          ]

          expect(checker(visitors_for("aliases.plural_alias_with_params", is_plural: true)).perform_check).to eq [
            "Label 'aliases.plural_alias_with_params' at filename:4 is missing parameters 'param1' (expecting 'param1')",
            "These labels are defined in the_directory but weren't used and can be removed:\n\taliases.nonplural_alias\n\taliases.plural_alias\n\taliases.plural_alias_with_plural_label\n\tlabel",
          ]
        end
      end

      context "while enforcing parity" do
        let(labels) { CrI18n.load_labels("./spec/checker_specs/alias_basic_nested") }

        it "ensures alias parity across locales" do
          expect(checker(visitors_for("whatever"), enforce_parity: true).perform_check).to contain(
            "Locale 'en-us's label 'aliases.basic' is missing alias 'label'"
          )
        end

        it "ensures alias parity across languages" do
          expect(checker(visitors_for("whatever"), enforce_parity: true).perform_check).to contain(
            "Language 'en's label 'aliases.nested' is missing alias 'aliases.basic'"
          )
        end
      end
    end
  end
end
