# Keyline Icons

The icons in `lib/ui/keyline/keyline_icons.g.dart` come from **Keyline Icons**
(https://keylineicons.com, https://github.com/keyline-icons/keyline-icons),
generated from the `@keyline-icons/react` package (version 1.7.0, rounded stroke
style) by `tool/gen_keyline_icons.dart`.

Keyline Icons is free under the **MIT License**, including in commercial work.
The authoritative license text is the `LICENSE` file in the Keyline Icons
repository and at https://keylineicons.com/legal/license; that grant governs.
This notice is kept here so the attribution travels with the code.

## Regenerating

```
dart run tool/gen_keyline_icons.dart [path/to/@keyline-icons/react/dist/index.js]
```

The other styles (`fill.js`, `two-tone.js`, `duotone.js`, `sharp*.js`) can be
generated the same way by pointing the script at those files.
