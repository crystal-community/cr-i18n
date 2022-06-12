# Crystal Internationalization (I18n)

This shards aims to provide a simple interface for obtaining the correct label of a specified language and locale.

This shard does not translate anything, only organizes any labels from multiple languages and locales, so obtaining the correct label
is more streamlined.

Lots of inspiration is taken from [crystal-i18n/i18n](https://crystal-i18n.github.io/) as well as [BrucePerens/internationalize](https://github.com/BrucePerens/internationalize).

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     cr-i18n:
       github: vici37/cr-i18n
   ```

2. Run `shards install`

## Usage

Labels are stored in `json` or `yaml` formatted files, in directories that represent the language and / or locale they're for.
For example, take the file structure from below:

```
labels
├── root.yml
└── en
    ├── en.yml
    └── us
        └── us.yml
```

And each file has the contents:
```
> cat labels/root.yml
label: this is the fallback label, in case there's not a language or locale version of this.
plural_label:
  one: label representing a singular thing
  other: label representing multiple things
section:
  other_label: this is a nested label
  yet_another_label: labels can be grouped this way

> cat labels/en/en.yml
label: this is the english version of the label
plural_label:
  one: a single english thing
  other: multiple english things

> cat labels/en/us/us.yml
label: this is the american english version of the label
plural_label:
  one: a single american thing
  other: multiple american things
```

NOTE: File names don't matter, nor do all labels need to be in the same file. _All label files in the same directory will be read and combined for that language and locale_. Directory names
are how the language -> locale lookup happens.

With the above language files set up, an example of using this in crystal can be seen below.

### Initializing Labels

There are two methods to initialize labels - one requires a hardcoded path and provides compiler checks for all labels, and the other one can accept a string inteprolated / configured value for the root of the label file. The former initialization also triggers the latter, so you can get both advantages when hardcoding.

```crystal
require "cr-i18n"

# Initializing method one - hardcoded path
my_labels = CrI18n.compiler_load_labels("labels")

# Initializing method two - configured or interpolated path
my_labels = CrI18n.load_labels("labels")
```

### Configuring Root Behavior

When a language / locale isn't specified anywhere, a "root" locale can be configured as the fallback. However, if you don't want to set a root locale as a global fallback (instead preferring the label lookup to fail, as this means you found some code that erroneously doesn't have a locale set), you'll still want to set a root "pluralization" locale to help determine how plural rules should be run for the root labels. Pluralization is explained father below.

```crystal
# Either through the static method or through the label instance you have
CrI18n.root_locale = "en-us"
my_labels.root_locale = "en-us"

# And for setting the pluralization rules only
CrI18n.root_pluralization = "en-us"
my_labels.root_pluralization = "en-us"
```

### Retrieving Labels

Labels follow a hierarchy, with language-locale being the first to be checked, followed by language only, and finally using the root (top level) label files for finding a label value. If the root should not be used for label retreival (e.g. in production or you otherwise don't trust the root labels'
quality), you can set `CrI18n.resolve_to_root = false`, and these labels will be treated as missing.

```crystal
# To get the benefits of compiler checking, use the new top level `label` macro. This delegates to `CrI18n.get_label` as described below
label("label") # => "this is the fallback label, in case there's not a language or locale version of this"

# Getting a label without a language or locale specified (root)
my_labels.get_label("label") # => "this is the fallback label, in case there's not a language or locale version of this"
my_labels.resolve_to_root = false
my_labels.get_label("label") # => "label"

# Getting a label for a language
my_labels.get_label("label", "en") # => "this is the english version of the label"

# ... and by locale
my_labels.get_label("label", "en-us") # => "this is the american english version of the label"

# You can also set up the context for a block of label retrievals
my_labels.with_locale("en-us") do
  my_labels.get_label("label") # => "this is the american english version of the label"
  my_labels.current_locale # => {language: "en", locale: "us"}
  CrI18n.current_locale # => {language: "en", locale: "us"}
end

# As JSON and YAML supports maps, nested labels can be queried using dot notation
my_label.get_label("section.other_label") # => "this is a nested label"
my_label.get_label("section.yet_another_label") # => "labels can be grouped this way"

# The CrI18n module keeps track of the last labels read and provides static methods to access them.
# The above examples could all be run while replacing `my_labels` with `CrI18n`.
CrI18n.get_label("label", "en-us") # => "this is the american english version of the label"
label("label", "en") # ...
label("label", "en-us") # ...
```

### Pluralization

When a label retreival includes a `count` parameter, it is assumed to be pluralizable (having multiple labels depending on the number of the _things_ there are). Pluralization largely follows the rules of (this page)[https://cldr.unicode.org/index/cldr-spec/plural-rules], but are also explained below. The gist of the behavior is, using the example labels from above:

```crystal
label("plural_label", count: 1) # => "a single american thing" (if locale is "en-us")
label("plural_label", count: 2) # => "multiple american things" (if locale is "en-us")
```

Different plural tags that are supported are:

* zero
* one
* two
* few
* many
* other

Where the "other" is a required term and a catch all for when the other plural tags don't apply. Different locales can define different pluralization rules (explained in next section) that will translate a given `count` value into a plural tag, and the plural tag will be used during label lookup. If a plural tag is returned that doesn't exist in a label file, then it will be treated as a missing label.

Many plural rules have already been created for various locales and languages. To use them out of the box, add this to your crystal:

```crystal
require "cr-i18n/plural_rules"
```

#### Defining Plural Rules

Plural rules extend the `CrI18n::Pluralization::PluralRule` class and define the `apply` method. If automatic locale registration is desired, you also need to define the `for_locale` method to provide a list of locales the plural rule should apply for.

```crystal
class MyPluralRule < CrI18n::Pluralization::PluralRule
  # Important: The LOCALES constant is what the `Pluralization.auto_register_rules` method described below uses for
  # attaching plural rules to a list of locales it supports
  LOCALES = ["en", "en-us", "en-uk"]

  def apply(count : Float | Int) : String
    case count
    when 1 then "one"
    else "other"
    end
  end
end
```

Pluralization rules can be registered explicitly or automatically, depending on if you want more control over which locales are supported or not.

Explicitly:
```crystal
CrI18n::Pluralization.register_locale("en-us", MyPluralRule.new)
```

Automatically:
```crystal
# This will detect any class extending the PluralRule class, and all rules _must_ provide
# a `LOCALES` constant providing an array of strings of the supported locales (see above)
CrI18n::Pluralization.auto_register_rules

# This will create an instance of the MyPluralRule and use it for the en-us and en-uk locales, as well as the en language
```

NOTE: Only one plural rule per language / locale is supported. Trying to register multiple rules for the same locale will cause an error.

### Looking For Missing Labels

After developing, you may have put in dummy labels in place just to get things working. To now find all those locations so you can remove the dummy values and put them in label files, you have a few options, depending on how you initialized above.

* Use the compiler flag `-Denforce_labels` to trigger compiler enforcements for all usages of the `label` macro

Examples:

```crystal
# COMPILER CHECKS
# If you wish the compiler to start throwing errors, build with the -Denforce_labels compiler flag. The `label` macro will now trigger compiler errors.
label("this is my dummy text") # => Compiler error now

# Without the -Denforce_labels flag, the `label` macro returns the string as-is
label("this is my dummy text") # => "this is my dummy text"

# RUNTIME CHECKS
# By default, trying to retrieve a non-existent label doesn't throw
my_label.get_label("nope") # => "nope"

# You can get a set of all labels that were queried for, but don't exist
my_label.missed # => Set{"nope"}
```

### Looking for Missing Labels in Language or Locale Labels
After translation has occurred, it's good to do a final check that there is parity between all label files. To that end, `cr-i18n` can leverage the compiler to make that check, or as a runtime check yourself. To make it a compiler check, compile with the `-Denforce_label_parity` flag, and be sure to initialize the labels using the `compiler_load_labels` method described above. A full example can be seen as:

```crystal
# When compiling with the -Denforce_label_parity flag
CrI18n.compiler_load_labels("my_label_directory") # Compiler error unless full label parity is found

# As a runtime check
labels = CrI18n.load_labels("my_label_directory")
labels.load_discrepencies # => Array of errors if there are problems, or an empty array otherwise
```

Things that are checked for parity:
* Non-plural labels found in the root labels are present in all language and locale labels
* Plural labels found in the root labels are present in all language and locale labels
* All plural labels have the "other" plural tag defined
* Labels _not_ present in the root labels but found in language or locale labels are flagged

## Developing Recommendations

When using this shard to develop, it's recommended that the developer use the `label("my actual label string here")` macro with their anticipated strings verbatim. This will provide the least amount of friction between development and needing to change things on the fly.

Once the feature is mostly finished and ready for finalization, the developer can start compiling with the `-Denforce_labels` flag to discover where all of these labels are. For every compiler error that shows up, the developer moves the string to the appropriate _root_ label file and defines an appropriate target path for it, and then replaces the text in the `label` macro with that path.

CI/CD would be an appropriate place to always run with the `-Denforce_labels` flag.

At some point later, after all labels in the _root_ labels have been translated for all supported locales and the directory structure set up accordingly, rebuilding with the `-Denforce_label_parity` can act as a final check that all labels look and behave accordingly.

Also, instead of hardcoding which locales your program supports and can be used, you can get a list of all languages and locales loaded by calling
`CrI18n.supported_locales` or `my_labels_object.supported_locales` to receive an array of strings denoting each language and locale.

### Testing with Labels

While writing labels, keeping label nesting to 2-3 layers deep maximum is probably best, otherwise it may get hard to keep track of which labels
are related to which other labels. Since labels may change for any number of reasons but the functioning code may not, it might be desirable
to have a separate "test only" label file for all tests that will be receiving labels as output. That way if a label does change "in production",
tests verifying output won't also need to be updated to pass again.

```crystal
Spec.before_all do
  CrI18n.compiler_load_labels("spec/test_labels")
end

...

  it "returns correct output" do
    something.some_method.should eq "Contrived label taken from spec/test_labels instead of production labels"
  end

...
```

## TODO
[x] Support basic localization (table stakes) through top-level `label` macro
[x] Support pluralization
[x] Have compiler checks for label existence
[x] Have compiler checks for label parity between locales and languages
[x] Support setting context locale
[] Support numerical localization
[] Support date format localization
[] Support replacing / setting root locale with a specific locale
[] Convert labels to structs at compile time for quicker label look up (inspired by rosetta)

## Contributors

- [Troy Sornson](https://github.com/your-github-user) - creator and maintainer
