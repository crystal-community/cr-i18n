# Crystal Internationalization (I18n)

This shards aims to provide a simple interface for obtaining the correct label of a specified language and locale.

This shard does not translate anything, only organizes any labels from multiple languages and locales, so obtaining the correct label
is more streamlined.

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
section:
  other_label: this is a nested label
  yet_another_label: labels can be grouped this way

> cat labels/en/en.yml
label: this is the english version of the label

> cat labels/en/us/us.yml
label: this is the american english version of the label
```

NOTE: File names don't matter, nor do all labels need to be in the same file. _All label files in the same directory will be read and combined for that language and locale_. Directory names
are how the language -> locale lookup happens.

With the above language files set up, an example of using this in crystal can be seen by:


```crystal
require "cr-i18n"

my_labels = I18n.load_labels("labels")

# Getting a label without a language or locale specified
my_labels.get_label("label") # => "this is the fallback label, in case tehre's not a language or locale version of this"

# Getting a label for a language
my_labels.get_label("label", "en") # => "this is the english version of the label"

# ... and by locale
my_labels.get_label("label", "en", "us") # => "this is the american english version of the label"

# Trying to retrieve a non-existent label doesn't throw
my_label.get_label("nope") # => "Label for 'nope' not defined"

# You can get a set of all labels that were queried for, but don't exist
my_label.missed # => Set{"nope"}

# As JSON and YAML supports maps, nested labels can be queried using dot notation
my_label.get_label("section.other_label") # => "this is a nested label"
my_label.get_label("section.yet_another_label") # => "labels can be grouped this way"

# The I18n module keeps track of the last labels read and provides static methods to access them.
# The above examples could all be run while replacing `my_labels` with `I18n`.
I18n.get_label("label", "en", "us") # => "this is the american english version of the label"
```

While writing labels, keeping label nesting to 2-3 layers deep maximum is probably best, otherwise it may get hard to keep track of which labels
are related to which other labels. Since labels may change for any number of reasons but the functioning code may not, it might be desirable
to have a separate "test only" label file for all tests that will be receiving labels as output. That way if a label does change "in production",
tests verifying output won't also need to be updated to pass again.

```crystal
Spec.before_all do
  I18n.load_labels("spec/test_labels")
end

...

  it "returns correct output" do
    something.some_method.should eq "Contrived label taken from spec/test_labels instead of production labels"
  end

...
```

## Contributors

- [Troy Sornson](https://github.com/your-github-user) - creator and maintainer
