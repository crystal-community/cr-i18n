{% include_relative table_of_contents.md %}

# Crystal Internationalization

The `cri18n` shard provides an all inclusive library for developing internationalized crystal applications, taking advantage of crystal's macro language to help streamline development and deployment to provide confidence in the quality of your service.

Now that that boilerplate is out of the way....

## Installation

Add to your `shards.yml` file

```yaml
dependencies:
  cr-i18n:
    github: vici37/cr-i18n
```

and run `> shards install`

## Usage

### Label Files
Label files can be written as yaml or json files, and all files in the same directory are considered part of the same language / locale. A typical label directory layout could be something like:

```
labels
├── root.yml
└── en
    ├── en.yml
    └── us
        └── us.yml
```
The `root.yml` file is intended to be populated by developers and represent the first place where labels exist. Labels are then split into Languages (e.g. `en`) and Locales (e.g. `us`), found in the directory name. The names of files in these directories don't matter, and the directory name is case sensitive (i.e. `labels/en/us` corresponds to the locale `en-us`, which is _different_ from `lables/en/Us` which corresponds to `en-Us`).

Labels within label files can be organized and named anyway that makes sense. For example, a `root.yml` could contain:

```yaml
user_page:
  username: Username
  email: Email
  given_name: First Name
  surname: Last Name
  greetings: Hello, %{name}!
```

### Using in Crystal

```crystal
require "cr-i18n"

CrI18n.compiler_load_labels("./path/to/labels")
```

And then throughout your application code, use the top level `label` macro for whenever you have a string that will be displayed to the user:
```crystal
label(user_page.username) # => "Username"
label(user_page.greeting, name: "Troy") # => "Hello, Troy!"
```

From here, check out the [development](/cr-i18n/development.html) page for more details on how `cr-i18n` can help you build faster without worrying if you forgot a label somewhere or not.