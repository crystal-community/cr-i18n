require "./spec_helper"

class TestNumberFormatter < CrI18n::Formatter(Int32)
  TYPE = "number_formatter"

  def format(format, value) : String
    base = format.not_nil!.to_i
    value.to_s(base)
  end
end

class TestNamedTupleFormatter < CrI18n::Formatter(NamedTuple(name: String, age: Int32, is_male: Bool))
  TYPE = "user_formatter"

  def format(format, value) : String
    "#{value[:name]}, age #{value[:age]}, is #{value[:is_male] ? "male" : "female"}"
  end
end

class TestTimeFormatter < CrI18n::Formatter(Time)
  TYPE = "time_formatter"

  def format(format : String?, value : Time) : String
    value.to_s(format.not_nil!)
  end
end

unless_enforce do
  Spectator.describe CrI18n::Formatter do
    context "with basic formatters" do
      let(labels) { CrI18n.load_labels("./spec/formatter_specs/basic") }

      it "performs basic formatting" do
        # 9 (base 10) == 11 (base 8)
        expect(labels.get_label("basic.uses_number", number: 9)).to eq "This is a test of the 11 formatter"
        expect(labels.get_label("basic.no_formatter", str: "test", int: 3)).to eq "There is no formatter for test, and here's a number: 3"
        expect(labels.get_label("basic.uses_another_number", another_number: 9)).to eq "This is a test of the 100 formatter"
        expect(labels.get_label("basic.user", user: {name: "Troy", age: 30, is_male: true})).to eq "Hello, Troy, age 30, is male!"
      end

      it "doesn't throw error if no formatter for type" do
        expect(labels.get_label("basic.uses_number", nope: "whatever")).to eq "This is a test of the %{number} formatter"
        expect(labels.get_label("basic.doesnotexist", nope: "whatever")).to eq "This label uses the doesnotexist param whatever"
      end

      it "supports outputting only param based labels (no target)" do
        expect(labels.get_label(number: 9)).to eq "11"
      end
    end

    context "with different labels" do
      let(labels) { CrI18n.load_labels("./spec/formatter_specs/different_locales") }

      it "formats dates per us locale" do
        expect(labels.get_label(date: Time.utc(2016, 2, 15, 10, 20, 30), locale: "en-us")).to eq "02-15-2016"
      end

      it "formats dates per uk locale" do
        expect(labels.get_label(date: Time.utc(2016, 2, 15, 10, 20, 30), locale: "en-uk")).to eq "15-02-2016"
      end
    end
  end
end
