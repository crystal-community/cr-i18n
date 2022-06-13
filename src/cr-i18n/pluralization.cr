module CrI18n
  # A blatant ripoff of concepts from https://crystal-i18n.github.io/pluralization_rules.html
  class Pluralization
    abstract class PluralRule
      abstract def apply(count : Float | Int) : String

      def for_locale : Array(String)
        [] of String
      end
    end

    @@locale_rules = {} of String => PluralRule

    def self.supported_locales
      @@locale_rules.keys
    end

    def self.register_locale(locale : String, rule : PluralRule)
      raise "Duplicate rules being registered for #{locale}: #{rule.class} and #{@@locale_rules[locale].class}" if @@locale_rules.includes?(locale)
      @@locale_rules[locale] = rule
    end

    def self.auto_register_rules
      @@locale_rules.clear

      {% for rule in Pluralization::PluralRule.subclasses %}
      rule = {{rule}}.new

      {% raise "Pluralization rule #{rule} is missing the LOCALES constant and can't be auto registered; please define the LOCALES constant for this rule as an array of support locales (e.g. LOCALES = [\"en\", \"en-us\"])" unless rule.constants.includes?("LOCALES".id) %}
      locale = {{rule}}::LOCALES

      locale.each do |loc|
        Pluralization.register_locale(loc, rule)
      end
      {% end %}
    end

    def self.pluralize(count : Float | Int, language : String, locale : String) : String?
      # Special case: if we explicitly don't have a language or locale to use, treat it as if we're developing and using the
      # root labels, and only need to use a pluralization of "other"
      return "other" if language.empty? && locale.empty?

      if locale_rule = @@locale_rules["#{language}-#{locale}"]?
        return locale_rule.apply(count)
      end

      if lang_rule = @@locale_rules[language]?
        return lang_rule.apply(count)
      end

      # We received a locale / language, but couldn't find any pluralization rules for it. Compiler check should find these,
      # runtime we'll let slide
      nil
    end
  end
end
