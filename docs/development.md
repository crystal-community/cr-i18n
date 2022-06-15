# As a Developer

When building a new feature that needs labels, it's not clear what those labels will be during the beginning, and it's always a pain to go hunt them down after the fact to properly labelize them. That's why `cr-i18n` allows you to pass in basic strings from the getgo:

```crystal
require "cr-i18n"
CrI18n.compiler_load_labels("./path/to/labels")

label("This is a label") # => "This is a label"
label("Hello #{name}!") # => ...
label("You have #{count} apples") # doesn't make sense yet if count == 1
```

At some point you'll need to set what language / locale the intended user is using, and there are two approachs to doing that. One is by passing in the locale directly to `locale` as the second parameter, or alternatively (and more easily), you can set the locale for the request. The below are equivalent:

```crystal
label(some.label.path) # no locale set, will resolve from root

CrI18n.with_locale("en-Us") do
  # The below will try and resolve the label from "en-Us" locale first, then
  # "en" language if not found. If the label isn't in either "en" or "en-Us",
  # and `CrI18n.resolve_to_root` is true (default), then it will look in the root labels.
  label(some.label.path) # Search in "en-Us", then "en", then root

  label(some.label.path, "en-Uk") # Search in "en-Uk", then "en", then root. Overrides context locale
end

CrI18n.root_locale = "en-Us"
label(some.label.path) # Search in "en-Us", then "en", then root

CrI18n.resolve_to_root = false
label(some.label.path) # Search in "en-Us", then "en"
```

If a label target doesn't exist, it will record that label as missing and then return the passed in label target as is (such as a String, verbatim). To get a list of all labels that are missing and not using the compiler flag to check for them, you can check them via `CrI18n.missed`.

# After Feature Development Completes

After the feature is complete, it's time to transfer all of these labels to a proper `root.yml` (or adjacent) file. You can structure these files however you want. To discover all `label` invocations that don't use valid label path, you can build your application with the `-Denforce_labels` flag:

```
> crystal build -Denforce_labels src/my_app.cr
```

Which will throw a compiler error for any missing labels:

```
Showing last frame. Use --error-trace for full trace.

In src/cr-i18n/enforce_labels_check.cr:3:5

 3 | {% begin %}
     ^
Error: Found errors in compiled labels under "./src":

Missing label 'Hello #{name}!' at ./src/my_app.cr:7 wasn't found in labels loaded from c./path/to/labels
Missing label 'This is a label' at ./src/my_app.cr:5 wasn't found in labels loaded from c./path/to/labels
Missing label 'You have #{count} apples' at ./src/my_app.cr:9 wasn't found in labels loaded from c./path/to/labels
```

Let's say you create or add these labels to a new root label file like so:

```yaml
labels:
  intro: This is a label
  greeting: Hello %{name}!
  apple:
    # Note: the root locale only supports the "other" plural target. See Pluralization for more details
    other: You have %{count} apples
```

Then update the above `label` calls to:

```crystal
...
label("labels.intro") # Can use a String to for the label path
label(labels.greeting, name: "Troy") # Or no String (macro will convert it to one)

# You can use string interpolation for the label path as well
fruit = "apple"
label("labels.#{fruit}", count: 1) # => "You have one apple"
label("labels.#{fruit}", count: 42) # => "You have 42 apples"
```

# Translating the Label Files

Through human effort or robotic assistance, all labels from root label files should be translated to any desired supported languages and locales. To ensure that all languages and locales _do_ have all labels from the root, you can build with the `-Denforce_label_parity` which will cause `cr-i18n` to inspect all labels in all languages and locales, and make sure that all labels are present as defined in root.