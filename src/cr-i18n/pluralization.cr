module CrI18n
  # A blatant ripoff of concepts from https://crystal-i18n.github.io/pluralization_rules.html
  class Pluralization
    abstract class PluralRule
      abstract def apply(count : Float | Int) : String

      abstract def for_locale : String | Array(String)
    end

    @@locale_rules = {} of String => PluralRule

    def self.register_locale(locale : String, rule : PluralRule)
      raise "Duplicate rules being registered for #{locale.downcase}: #{rule.class} and #{@@locale_rules[locale.downcase].class}" if @@locale_rules.includes?(locale.downcase)
      @@locale_rules[locale.downcase] = rule
    end

    def self.auto_register_rules
      @@locale_rules.clear

      {% for rule in Pluralization::PluralRule.subclasses %}
      rule = {{rule}}.new

      locale = rule.for_locale
      if locale.is_a?(String)
        Pluralization.register_locale(locale, rule)
      else
        locale.each do |loc|
          Pluralization.register_locale(loc, rule)
        end
      end
      {% end %}
    end

    def self.pluralize(count : Float | Int, language : String, locale : String) : String?
      if locale_rule = @@locale_rules["#{language}-#{locale}"]?
        return locale_rule.apply(count)
      end

      if lang_rule = @@locale_rules[language]?
        return lang_rule.apply(count)
      end

      nil
    end
  end
end
