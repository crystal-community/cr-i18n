module CrI18n
  # A blatant ripoff of concepts from https://crystal-i18n.github.io/pluralization_rules.html
  class Pluralization
    abstract class PluralRule
      abstract def apply(count : Float | Int) : String

      def for_language : String?
        nil
      end

      def for_lang_and_locale : NamedTuple(language: String, locale: String)?
        nil
      end
    end

    @@language_rules = {} of String => PluralRule
    @@locale_rules = {} of Tuple(String, String) => PluralRule

    def self.register_language(lang : String, rule : PluralRule)
      @@language_rules[lang] = rule
    end

    def self.register_lang_and_locale(lang : String, locale : String, rule : PluralRule)
      @@locale_rules[{lang, locale}] = rule
    end

    def self.auto_register_rules
      {% for rule in Pluralization::PluralRule.subclasses %}
      rule = {{rule}}.new
      if lang = rule.for_language
        Pluralization.register_language(lang, rule)
      end

      if lang_and_locale = rule.for_lang_and_locale
        Pluralization.register_lang_and_locale(lang_and_locale[:language], lang_and_locale[:locale], rule)
      end
      {% end %}
    end

    def self.pluralize(count : Float | Int, lang : String, locale : String) : String?
      if locale_rule = @@locale_rules[{lang, locale}]?
        return locale_rule.apply(count)
      end

      if lang_rule = @@language_rules[lang]?
        return lang_rule.apply(count)
      end

      nil
    end
  end
end
