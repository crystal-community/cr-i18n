# Advanced Label Features

## Parameters

It's often needed to embed information within labels. If the information needing to be embeded doesn't need special formatting through [formatters](/cr-i18n/formatters.html), you can pass the value in directly as a parameter to the `label` macro:

```crystal
# Assume my.param.label = "Using %{param1} and %{param2}!"
label(my.param.label, param1: "parameters", param2: "labels") # => "Using parameters and labels!"
```

Label parameters take the form of `%{parameter_name}` within label files themselves. Take note of the `{...}`, which is specific to parameters; `%(...)` are used for aliases below.

## Aliases

If a project is large and complex enough, it might be needed to refer to labels _from labels_. Think of the generic "username" label - this could show up on the user object, a login page, a user details page, emails to that user, etc.. They could all refer to the same label target, or it might better to organize labels for the same thing (e.g. login page) together and use _aliases_ to dedupe labels.

```crystal
# Assume labels:
# user_page.username = username
# user_details.username = Your %(user_page.username) is %{username}
label(user_details.username, username: "tsornson") # => "Your username is tsornson"
```

You can also pass parameters through to label aliases too:

```crystal
# Assume:
# my.param.label = "Hello %{name}!"
# email.welcome = "%(my.param.label)\nHow are you?"
label(my.param.label, name: "Troy") # => "Hello Troy!\nHow are you?"
```

Note that aliases use `%(...)` (parentheses) and NOT `%{...}` (curly braces). Be sure to use the one you intend!