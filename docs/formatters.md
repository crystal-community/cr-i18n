# Formatting Labels

In many cases, you'll want different formats for parameters based on the locale, such as when displaying dates or currency. For that, `cr-i18n` provides named parameter formatters that allow parameters passed into `locale` to have further processing and formatting applied based on the locale in context. There are two parts to creating a formatted parameter:

1. A definition under the `cri18n.formatters` namespace
2. A formatter implementation that's responsible for that formatter type

## Creating a Named Formatted Parameter

In your label files, create a new formatter section:

```yaml
cri18n:
  formatters:
    date:
      type: time_formatter
      format: "%m-%d-%Y"

```

This will result in any `date` parameters passed into _any_ label to be processed by the `time_formatter` (that doesn't exist yet). Whatever string value the formatter outputs will be used in place of the `%{date}` portion of the label.

## Defining a Formatter

A formatter extends the `CrI18n::Formatter(T)` generic class, where the generic term is used to enforce the type of the parameter. A runtime error gets thrown if the wrong type gets passed to `label` for the `date` that doesn't match the generic type.

For the above `time_formatter` created above, a simple definition could look like:

```crystal
class TimeFormatter < CrI18n::Formatter(Time)
  TYPE = "time_formatter"

  def format(format : String?, value : Time) : String
    value.to_s(format.not_nil!)
  end
end
```

No registration is required here, the compiler will pick up on it and wire it into `cr-i18n`s supported formatters as long as the type is `require`d somewhere.

NOTE: You can use formatters to handle any type that your application might have, such as a `User` object, or a `NamedTuple(...)` for more exotic
formatting options.

## Using Formatted Parameters

Formatted labels that show up in labels will be formatted per the formatter designated to them via the `type` value. In the event you don't want to have a full label for only calling the formatter, there's a special case where `label` can be invoked with _only_ the parameter that you want formatted:

```crystal
# This is an error if there is no named formatter called `date`
label(date: Time.utc) # => "12-22-2022"

# Or with a locale override
label(locale: "en-UK", date: Time.utc) # => "22-12-2022"
```