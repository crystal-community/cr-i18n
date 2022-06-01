macro define_plural_rule(name, locales)
  class CrI18n::Pluralization::{{name}} < CrI18n::Pluralization::PluralRule
    LOCALES = {{locales}}

    def apply(count : Int | Float) : String
    {{yield}}
    end
  end
end

# https://github.com/crystal-i18n/i18n/blob/main/src/i18n/pluralization/rule/arabic.cr
define_plural_rule Arabic, ["ar"] do
  case (count % 100)
  when 0      then "zero"
  when 1      then "one"
  when 2      then "two"
  when 3..10  then "few"
  when 11..99 then "many"
  else             "other"
  end
end

# https://github.com/crystal-i18n/i18n/blob/main/src/i18n/pluralization/rule/breton.cr
define_plural_rule Breton, ["br"] do
  mod10 = count % 10
  mod100 = count % 100

  if mod10 == 1 && ![11, 71, 91].includes?(mod100)
    "one"
  elsif mod10 == 2 && ![12, 72, 92].includes?(mod100)
    "two"
  elsif [3, 4, 9].includes?(mod10) && !((10..19).to_a + (70..79).to_a + (90..99).to_a).includes?(mod100)
    "few"
  elsif count % 1_000_000 == 0 && count != 0
    "many"
  else
    "other"
  end
end

# https://github.com/crystal-i18n/i18n/blob/main/src/i18n/pluralization/rule/central_morocco_tamazight.cr
define_plural_rule CentralMoroccoTamazight, ["tzm"] do
  if ([0, 1] + (11..99).to_a).includes?(count)
    "one"
  else
    "other"
  end
end

# https://github.com/crystal-i18n/i18n/blob/main/src/i18n/pluralization/rule/colognian.cr
define_plural_rule Colognian, ["ksh"] do
  case count
  when 0 then "zero"
  when 1 then "one"
  else        "other"
  end
end

# https://github.com/crystal-i18n/i18n/blob/main/src/i18n/pluralization/rule/east_slavic.cr
define_plural_rule EastSlavic, ["be", "bs", "by", "hr", "ru", "sh", "sr", "uk"] do
  mod10 = count % 10
  mod100 = count % 100

  if mod10 == 1 && mod100 != 11
    "one"
  elsif (2..4).includes?(mod10) && !(12..14).includes?(mod100)
    "few"
  elsif mod10 == 0 || (5..9).includes?(mod10) || (11..14).includes?(mod100)
    "many"
  else
    "other"
  end
end

# https://github.com/crystal-i18n/i18n/blob/main/src/i18n/pluralization/rule/irish.cr
define_plural_rule Irish, ["ga"] do
  case count
  when 1     then "one"
  when 2     then "two"
  when 3..6  then "few"
  when 7..10 then "many"
  else            "other"
  end
end

# https://github.com/crystal-i18n/i18n/blob/main/src/i18n/pluralization/rule/langi.cr
define_plural_rule Langi, ["lag"] do
  case count
  when 0 then "zero"
  when 1 then "one"
  else        "other"
  end
end

# https://github.com/crystal-i18n/i18n/blob/main/src/i18n/pluralization/rule/latvian.cr
define_plural_rule Latvian, ["lv"] do
  if count % 10 == 1 && count % 100 != 11
    "one"
  else
    "other"
  end
end

# https://github.com/crystal-i18n/i18n/blob/main/src/i18n/pluralization/rule/lithuanian.cr
define_plural_rule Lithuanian, ["lt"] do
  mod10 = count % 10
  mod100 = count % 100

  if mod10 == 1 && !(11..19).includes?(mod100)
    "one"
  elsif (2..9).includes?(mod10) && !(11..19).includes?(mod100)
    "few"
  else
    "other"
  end
end

# https://github.com/crystal-i18n/i18n/blob/main/src/i18n/pluralization/rule/macedonian.cr
define_plural_rule Macedonian, ["mk"] do
  if count % 10 == 1 && count != 11
    "one"
  else
    "other"
  end
end

# https://github.com/crystal-i18n/i18n/blob/main/src/i18n/pluralization/rule/maltese.cr
define_plural_rule Maltese, ["mt"] do
  mod100 = count % 100

  if count == 1
    "one"
  elsif count == 0 || (2..10).includes?(mod100)
    "few"
  elsif (11..19).includes?(mod100)
    "many"
  else
    "other"
  end
end

# https://github.com/crystal-i18n/i18n/blob/main/src/i18n/pluralization/rule/manx.cr
define_plural_rule Manx, ["gv"] do
  if [1, 2].includes?(count % 10) || count % 20 == 0
    "one"
  else
    "other"
  end
end

# https://github.com/crystal-i18n/i18n/blob/main/src/i18n/pluralization/rule/one_other.cr
define_plural_rule OneOther, ["bg", "bn", "ca", "da", "de-AT", "de-CH", "de-DE", "de", "el", "en-AU", "en-CA", "en-GB", "en-IN", "en-NZ", "en", "eo", "es-419", "es-AR", "es-CL", "es-CO", "es-CR", "es-EC", "es-ES", "es-MX", "es-NI", "es-PA", "es-PE", "es-US", "es-VE", "es", "et", "eu", "fi", "gl", "he", "hu", "is", "it-CH", "it", "mn", "nb", "ne", "nl", "nn", "oc", "pt", "st", "sv-SE", "sv", "sw", "ur"] do
  count == 1 ? "one" : "other"
end

# https://github.com/crystal-i18n/i18n/blob/main/src/i18n/pluralization/rule/one_two_other.cr
# Pluralization rule used for: Cornish, Inari Sami, Inuktitut, Lule Sami, Nama, Northern Sami, Sami Language,
# Skolt Sami, Southern Sami.
define_plural_rule OneTwoOther, ["iu", "kw", "naq", "se", "sma", "smi", "smj", "smn", "sms"] do
  case count
  when 1 then "one"
  when 2 then "two"
  else        "other"
  end
end

# https://github.com/crystal-i18n/i18n/blob/main/src/i18n/pluralization/rule/one_up_to_two_other.cr
# Pluralization rule used for: French, Fulah, Kabyle.
define_plural_rule OneUpToTwoOther, ["ff", "fr-CA", "fr-CH", "fr-FR", "fr", "kab"] do
  count >= 0 && count < 2 ? "one" : "other"
end

# https://github.com/crystal-i18n/i18n/blob/main/src/i18n/pluralization/rule/one_with_zero_other.cr
# Pluralization rule used for: Akan, Amharic, Bihari, Filipino, guw, Hindi, Lingala, Malagasy, Northen Sotho,
# Tachelhit, Tagalog, Tigrinya, Walloon.
define_plural_rule OneWithZeroOther, ["ak", "am", "bh", "guw", "hi-IN", "hi", "ln", "mg", "ml", "mr-IN", "nso", "or", "pa", "shi", "ti", "wa"] do
  count == 0 || count == 1 ? "one" : "other"
end

# https://github.com/crystal-i18n/i18n/blob/main/src/i18n/pluralization/rule/other.cr
define_plural_rule Other, ["az", "bm", "bo", "dz", "fa", "id", "ig", "ii", "ja", "jv", "ka", "kde", "kea", "km", "kn", "ko", "lo", "ms", "my", "pap-AW", "pap-CW", "root", "sah", "ses", "sg", "th", "to", "tr", "vi", "wo", "yo", "zh-CN", "zh-HK", "zh-TW", "zh-YUE", "zh"] do
  "other"
end

# https://github.com/crystal-i18n/i18n/blob/main/src/i18n/pluralization/rule/polish.cr
define_plural_rule Polish, ["pl"] do
  mod10 = count % 10
  mod100 = count % 100

  if count == 1
    "one"
  elsif [2, 3, 4].includes?(mod10) && ![12, 13, 14].includes?(mod100)
    "few"
  elsif ([0, 1] + (5..9).to_a).includes?(mod10) || [12, 13, 14].includes?(mod100)
    "many"
  else
    "other"
  end
end

# https://github.com/crystal-i18n/i18n/blob/main/src/i18n/pluralization/rule/romanian.cr
define_plural_rule Romanian, ["ro"] do
  if count == 1
    "one"
  elsif count == 0 || (1..19).to_a.includes?(count % 100)
    "few"
  else
    "other"
  end
end

# https://github.com/crystal-i18n/i18n/blob/main/src/i18n/pluralization/rule/scottish_gaelic.cr
define_plural_rule ScottishGaelic, ["gd"] do
  if count == 1 || count == 11
    "one"
  elsif count == 2 || count == 12
    "two"
  elsif ((3..10).to_a + (13..19).to_a).includes?(count)
    "few"
  else
    "other"
  end
end

# https://github.com/crystal-i18n/i18n/blob/main/src/i18n/pluralization/rule/slovenian.cr
define_plural_rule Slovenian, ["sl"] do
  mod100 = count % 100

  if mod100 == 1
    "one"
  elsif mod100 == 2
    "two"
  elsif mod100 == 3 || mod100 == 4
    "few"
  else
    "other"
  end
end

# https://github.com/crystal-i18n/i18n/blob/main/src/i18n/pluralization/rule/upper_sorbian.cr
define_plural_rule UpperSorbian, ["hsb"] do
  mod100 = count % 100

  if mod100 == 1
    "one"
  elsif mod100 == 2
    "two"
  elsif mod100 == 3 || mod100 == 4
    "few"
  else
    "other"
  end
end

# https://github.com/crystal-i18n/i18n/blob/main/src/i18n/pluralization/rule/welsh.cr
define_plural_rule Welsh, ["cy"] do
  case count
  when 0 then "zero"
  when 1 then "one"
  when 2 then "two"
  when 3 then "few"
  when 6 then "many"
  else        "other"
  end
end

# https://github.com/crystal-i18n/i18n/blob/main/src/i18n/pluralization/rule/west_slavic.cr
define_plural_rule WestSlavic, ["cs", "sk"] do
  case count
  when 1    then "one"
  when 2..4 then "few"
  else           "other"
  end
end
