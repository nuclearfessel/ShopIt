# Shop-it

Shop-it is a shopping and pantry list app for Windows and Android. The same lists, categories, prices, and tax settings work on both.

![Shop-it on Windows](docs/screenshots/windows.png)

<img src="docs/screenshots/android.png" alt="Shop-it on Android" width="280" />

## Download

**Current version: 0.0.8**

| Platform | Package |
| --- | --- |
| Windows | [Shop-it-Setup-0.0.8.exe](https://github.com/nuclearfessel/Shop-it/releases/download/v0.0.8/Shop-it-Setup-0.0.8.exe) |
| Android | [Shop-it-0.0.8.apk](https://github.com/nuclearfessel/Shop-it/releases/download/v0.0.8/Shop-it-0.0.8.apk) |

On Windows, run the installer. On Android, allow installs from the APK, then open it. Older packages stay in [Releases](https://github.com/nuclearfessel/Shop-it/releases) until a newer build replaces them; only the three newest releases are kept.

## Features

- **Shopping** — lists with categories, quantities, prices, coupons, and a cart. Categories stay in alphabetical order. Search finds items already on the open list, items in the pantry, and names you have added before.
- **Pantry** — what you already have, with counts or full/low levels. Items that expire within seven days, or that are already past that date, show in a Use soon strip.
- **Sales tax** — saved rates, optional location lookup, and per-item control. Marking every item taxable, not taxable, or back on automatic rules is in List settings.
- **Sync** — share lists on the same Wi-Fi, or over the internet with a household code. Cloud copies are encrypted with that code. Share lists shows the last Wi-Fi sync and the last cloud sync separately.

On a wide window, Shopping and Pantry sit in the left rail. On a phone, they sit in the bottom bar.

<img src="docs/icons/shopping.png" width="22" height="22" alt=""> Shopping
&nbsp;&nbsp;
<img src="docs/icons/pantry.png" width="22" height="22" alt=""> Pantry
&nbsp;&nbsp;
<img src="docs/icons/settings.png" width="22" height="22" alt=""> Settings
&nbsp;&nbsp;
<img src="docs/icons/more.png" width="22" height="22" alt=""> List options
&nbsp;&nbsp;
<img src="docs/icons/search.png" width="22" height="22" alt=""> Search
&nbsp;&nbsp;
<img src="docs/icons/history.png" width="22" height="22" alt=""> History

Open **Settings** for appearance, tax, sharing, and About. The illustrated walkthrough in [Using Shop-it](docs/usage.md) shows these controls next to each step.

## Sync

Open **Settings → Share lists** on both devices.

- **Same Wi-Fi** — turn on **Share on this Wi-Fi** while both apps are open. If Windows asks to allow Shop-it on private networks, choose allow. The Wi-Fi line says when the last sync succeeded, or that it has not synced yet.
- **Away from home** — create a cloud code on one device and enter it on the other. Both need internet while the apps are open. List contents are encrypted with that code before they are stored. Closing the app sends one last cloud snapshot. The cloud line shows its own last sync time and its own error, separate from Wi-Fi.

If you paired on a build before 0.0.8, leave the household on both devices and create a new code after updating.

If both sides already have a list with the same name, sync merges them and appends items instead of creating a duplicate list.

## Docs

Full walkthrough: [Using Shop-it](docs/usage.md).
