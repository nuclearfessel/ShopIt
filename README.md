# ShopIt

ShopIt is an open source shopping, pantry, and recipe app for Windows, Mac, Android, and iOS. The source is in this repository. The window title, the icon, and Windows Installed apps all say ShopIt. The same lists, categories, prices, recipes, and tax settings work on each of them.

<p align="center">
<img src="docs/screenshots/windows.png" alt="ShopIt on Windows" width="800">
</p>

<p align="center">
<img src="docs/screenshots/android.png" alt="ShopIt on an Android phone" width="280">
</p>

## Download

**Current version: 1.1.5**

| Platform | Package |
| --- | --- |
| Windows | [ShopIt-Setup-1.1.5.exe](https://github.com/nuclearfessel/ShopIt/releases/download/v1.1.5/ShopIt-Setup-1.1.5.exe) |
| Android | [ShopIt-1.1.5.apk](https://github.com/nuclearfessel/ShopIt/releases/download/v1.1.5/ShopIt-1.1.5.apk) |
| Mac | [ShopIt-1.1.5-macos.zip](https://github.com/nuclearfessel/ShopIt/releases/download/v1.1.5/ShopIt-1.1.5-macos.zip) |

On Windows, run the installer. On Android, allow installs from the APK, then open it. On a Mac, unzip the app and open ShopIt. iPhone and iPad installs go through TestFlight once an Apple Developer account is connected, so they are not a file on this page. Older packages stay in [Releases](https://github.com/nuclearfessel/ShopIt/releases) until a newer build replaces them; only the three newest releases are kept.

## Uninstall

Uninstall removes the app and its shopping lists, settings, and data folders on that device.

| Platform | How |
| --- | --- |
| Windows | Apps and Features, or **Uninstall ShopIt** in the Start Menu folder the installer created |
| Mac | Unzip the release zip if needed, then open **Uninstall-ShopIt.command** next to ShopIt.app |
| Android | Long-press the ShopIt icon and uninstall, or remove it in Settings → Apps |
| iPhone / iPad | Long-press the ShopIt icon and delete the app |

On Android and iOS, removing the app clears its sandbox. ShopIt does not back lists up to the device cloud, so a fresh install starts empty.

## Features

- **Shopping** — lists with categories, quantities, prices, coupons, and a cart. Categories stay in alphabetical order. Search finds items already on the open list, items in the pantry, and names you have added before. A name ShopIt does not already know is saved when you add it, so it shows up next time. On a phone or tablet, scan a barcode next to Add. When **Shopping and pantry** is on in Settings, the cart offers **Add to pantry**.
- **Pantry** — what you already have. Each item can be **Low** or **Full**, or an exact amount. **Amounts** in the list menu applies **Low or stocked** or **Exact amounts** to every item on that list. Items that expire within seven days, or that are already past that date, show in a Use soon strip. When **Shopping and pantry** is on, a Low item, an exact amount at zero, or a Use soon item can be added to the open shopping list. On a phone or tablet, scan a barcode to add or increase that item.
- **Recipes** — save a meal, scale the servings, and add the missing ingredients to a shopping list. ShopIt skips what the pantry already covers. Cook subtracts those amounts from the pantry.
- **Sales tax** — saved rates, optional location lookup, and per-item control. Marking every item taxable, not taxable, or back on automatic rules is in List settings.
- **Sync** — share lists after you type the same household code on both devices, or scan the QR code shown on Windows or Mac. The code is the key and is not sent over the network. Creating, joining, or scanning the code turns Share on this Wi-Fi on, including on Windows. Wi-Fi sync and internet sync both send encrypted lists. Items added on any device are added to the others. Checking an item moves it to the cart everywhere. Deleting an item removes it everywhere. Share lists shows the last Wi-Fi sync and the last cloud sync separately. While lists are shared, Shopping and Pantry show one line: synced just now, waiting to sync, or the short error. [Privacy](docs/privacy.md) says what leaves the device.

When the shortest side of the window is under 600, Shopping, Pantry, Recipes, and Settings sit in the bottom bar, and Settings is a full page. That is a phone: an Android phone or an iPhone stays in portrait. A larger window uses the side rail. Settings is a dialog when that window is at least 700 pixels wide, and a full page when it is narrower. Changing the size switches Settings while it is open. Tablets, Windows, and Mac can rotate or be resized. Close the page with the X or with Done. Settings covers appearance, tax, lists, sharing, and About. **Shopping and pantry**, under Lists, is off until you turn it on. The walkthrough in [Using ShopIt](docs/usage.md) shows each button next to the step that uses it. Scanning a barcode is on Android and iOS, including tablets. Windows and Mac do not show it. A name scanned on a phone still appears on the computer through sync.

## Sync

Open **Settings → Share lists** on both devices.

- **Same Wi-Fi** — creating or joining the code turns **Share on this Wi-Fi** on. Keep both apps open on the same network. The Windows installer allows ShopIt on private networks. The Wi-Fi line says when the last sync succeeded, or that it has not synced yet.
- **Over the internet** — create a cloud code on one device and enter it on the other, or scan the QR code from Windows or Mac. That also turns **Share on this Wi-Fi** on. Lists keep syncing over the internet while both apps are open, including on mobile data. List contents are encrypted with that code before they are stored. Closing the app sends one last cloud snapshot. The cloud line shows its own last sync time and its own error, separate from Wi-Fi.

If you paired on an earlier build, leave the household on both devices and create a new code. Older codes are ignored.

If both sides already have a list with the same name, sync keeps one list and adds every device's items onto it. A list the other device has never used does not wipe a full list on this one. Deleting an item removes it on the other devices. Checking an item moves it to the cart on the other devices. An item that exists only on one device stays until that item itself is deleted.

While sharing is on, Shopping and Pantry show that same result in one line under the list name: synced just now, waiting to sync, or the short error. Share lists still holds the code, the QR code, and the Wi-Fi switch.

## Docs

Full walkthrough: [Using ShopIt](docs/usage.md).

## License

ShopIt is open source under the [MIT License](LICENSE).
