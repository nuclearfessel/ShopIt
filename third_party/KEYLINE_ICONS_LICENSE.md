# Keyline Icons

The icons in `lib/ui/keyline/keyline_icons.g.dart` come from **Keyline Icons**
(https://keylineicons.com, https://github.com/keyline-icons/keyline-icons),
generated from the `@keyline-icons/react` package (version 1.7.0, rounded stroke
style) by `tool/gen_keyline_icons.dart`.

Keyline Icons is free under the **MIT License**, including in commercial work.
The authoritative license text is the `LICENSE` file in the Keyline Icons
repository and at https://keylineicons.com/legal/license; that grant governs.
This notice is kept here so the attribution travels with the code.

Copyright (c) Keyline Icons contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Regenerating

```
dart run tool/gen_keyline_icons.dart [path/to/@keyline-icons/react/dist/index.js]
```

The other styles (`fill.js`, `two-tone.js`, `duotone.js`, `sharp*.js`) can be
generated the same way by pointing the script at those files.
