# Plural Labels

There are times when you need to have different labels based on if there is one _thing_ vs multiple _things_. This follows the mnemonic tags defined by the [CLDR](https://cldr.unicode.org/index/cldr-spec/plural-rules), specifically `zero`, `one`, `two`, `few`, `many`, and `other`.
The architecture does not limit to only those tags for custom plural rule implementations (see below).

# Defining Plural Labels

All plural labels _must_ have the `other` tag, this is what `cr-i18n` uses to detect if a label is plural or not, which impacts how label parity is determined. Take the below label files as an example for the rest of this page:

`labels/en/us.yml`:
```yaml
food:
  cookie:
    one: cookie
    other: cookies
```

`labels/en/uk.yml`:
```yaml
food:
  cookie:
    one: biscuit
    other: biscuits
```

Plural labels are picked based on a special `count` parameter, and plural rules that map specific numbers to their plural mnemonic tag (see below). `cr-i18n` comes with plural rules for many languages and locales out of the box, and also provides a way to define your own.

# Using Plural Labels

```crystal
# This will register all plural rules
CrI18n::Pluralization.auto_register_rules

label(food.cookie, "en-us", count: 1) # => "cookie"
label(food.cookie, "en-us", count: 42) # => "cookies"
label(food.cookie, "en-uk", count: 1) # => "biscuit"
label(food.cookie, "en-uk", count: 2) # => "biscuits"
```

# Defining a Plural Rule

Plural rules must extend the `Cri18n::Pluralization::PluralRule`, define a `LOCALES` constant as a string array containing all languages and locales it supports if using the `auto_register_rules` method, and implement the abstract `apply(count : Float | Int) : String` method that returns the desired plural tag:

```crystal
class MyPluralRule < CrI18n::Pluralization::PluralRule
  # This constant is optional, but will throw an error if `auto_register_rules` is run and it doesn't exist.
  # There's already a plural rule for these locales, so this is only an example
  LOCALES = ["es-MX", "es"]

  def apply(count : Float | Int) : String
    count == 1 ? "one" : "other"
  end
end

# Register the rule for the `label` macro to pick up on it
CrI18n::Pluralization.register_locale("es-MX", MyPluralRule.new)
```

Technically, only the "other" tag is required with no other enforcement on the tags, and while not supported in any way, you can use it to perform weird hacks:

```yaml
fruits:
  apple: Apple
  orange: Orange
  banana: Banana
  other: Not a fruit
```

```crystal
@[Flags]
enum Fruit
  Apple
  Orange
  Banana
end

class MyFruitRule < CrI18n::Pluralization::PluralRule
  LOCALES = ["fruit_picker"]

  def apply(count : Float | Int) : String
    Fruit.from_value(count.as(Int)).to_s.downcase
  end
end

label("fruits", count: Fruit::Apple.value)
```

This would be a weird, but effective way to localize your enum names across locales.