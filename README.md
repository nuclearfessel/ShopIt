# Shop-it

Shop-it is a shopping, pantry, and recipe app for Windows and Android. The same lists, categories, prices, recipes, and tax settings work on both.

![Shop-it on Windows](docs/screenshots/windows.png)

<img src="docs/screenshots/android.png" alt="Shop-it on Android" width="280" />

## Download

**Current version: 0.1.2**

| Platform | Package |
| --- | --- |
| Windows | [Shop-it-Setup-0.1.2.exe](https://github.com/nuclearfessel/Shop-it/releases/download/v0.1.2/Shop-it-Setup-0.1.2.exe) |
| Android | [Shop-it-0.1.2.apk](https://github.com/nuclearfessel/Shop-it/releases/download/v0.1.2/Shop-it-0.1.2.apk) |

On Windows, run the installer. On Android, allow installs from the APK, then open it. Older packages stay in [Releases](https://github.com/nuclearfessel/Shop-it/releases) until a newer build replaces them; only the three newest releases are kept.

## Features

- **Shopping** — lists with categories, quantities, prices, coupons, and a cart. Categories stay in alphabetical order. Search finds items already on the open list, items in the pantry, and names you have added before. A name Shop-it does not already know is saved when you add it, so it shows up next time. On Android, scan a barcode next to Add.
- **Pantry** — what you already have, with counts or full/low levels. Items that expire within seven days, or that are already past that date, show in a Use soon strip. On Android, scan a barcode to add or increase that item.
- **Recipes** — save a meal, scale the servings, and add the missing ingredients to a shopping list. Shop-it skips what the pantry already covers. Cook subtracts those amounts from the pantry.
- **Sales tax** — saved rates, optional location lookup, and per-item control. Marking every item taxable, not taxable, or back on automatic rules is in List settings.
- **Sync** — share lists on the same Wi-Fi, or over the internet with a household code. Cloud copies are encrypted with that code. Share lists shows the last Wi-Fi sync and the last cloud sync separately.

On a wide window, Shopping, Pantry, and Recipes sit in the left rail. On a phone, they sit in the bottom bar. Open **Settings** for appearance, tax, sharing, and About. The walkthrough in [Using Shop-it](docs/usage.md) shows each button next to the step that uses it. Scanning a barcode is on the phone only. A name scanned there still appears on the computer through sync.

## Sync

Open **Settings → Share lists** on both devices.

- **Same Wi-Fi** — turn on **Share on this Wi-Fi** while both apps are open. That also turns on internet sync and passes a household code to the other device. If Windows asks to allow Shop-it on private networks, choose allow. The Wi-Fi line says when the last sync succeeded, or that it has not synced yet.
- **Wi-Fi off** — lists keep syncing over the internet while both apps are open, including on mobile data. If the devices have not met on Wi-Fi yet, create a cloud code on one and enter it on the other. List contents are encrypted with that code before they are stored. Closing the app sends one last cloud snapshot. The cloud line shows its own last sync time and its own error, separate from Wi-Fi.

If you paired on a build before 0.0.8, leave the household on both devices and create a new code after updating.

If both sides already have a list with the same name, sync merges them and appends items instead of creating a duplicate list.

## Docs

Full walkthrough: [Using Shop-it](docs/usage.md).
