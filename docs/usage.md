# Using Shop-it

Shop-it runs the same way on Windows and Android. Use **Shopping** for what you need to buy and **Pantry** for what you already have. On a wide window those sections are in the left rail; on a phone they are in the bottom bar.

Open **Settings** from the gear icon for appearance, sales tax, sharing, and About.

## Shopping

1. Open **Shopping**.
2. Create a list from the empty screen, or choose **New list** from the list menu.
3. If you have more than one list, use the name at the top to switch between them.
4. Type in **Search or add an item**, then press Enter or tap **+**. Use the pen to set quantity, unit, category, price, tax, and a note before you add.
5. Tap an item to edit it. Check an item to move it into the cart.

From the cart you can uncheck everything or delete the checked items. **History** suggests items you have added before.

The list menu also covers categories, list settings, renaming and reordering lists, CSV import and export, applying tax to every item, and deleting a list.

### List settings and categories

List settings control whether items are grouped by category, whether new items are filed automatically, and whether empty categories stay visible. Tap a category header to change its color. Manage the full category list from the list menu.

## Pantry

Open **Pantry** for stock you already have. Add items the same way as on a shopping list. An item can use a count or a level (full or low), and it can include a place and an expiry date.

**Move/Copy items** sends items between shopping lists and pantry lists—handy when you restock or finish something.

## Sales tax

In **Settings**, under sales tax:

- Choose **No tax**, or add a saved rate.
- **Use my location** looks up a rate for where you are. In the US that lookup can use a Ziptax key saved in the same section. Nothing is sent until you tap the button.

Open Settings from a shopping list to pick which rate that list uses. Each rate has its own tax rules (what is taxed). New items start taxable; you can turn tax off for one item, or for the whole list from the list menu.

## Sync between phone and computer

On both devices, open **Settings → Share lists**.

### Same Wi-Fi

Turn on **Share on this Wi-Fi** on both devices. Keep both apps open on the same network. Lists and items appear on the other device without typing an address or code.

If Windows asks whether to allow Shop-it on private networks, choose allow. The phone cannot reach the computer on Wi-Fi until you do.

### Over the internet

When you are not on the same Wi-Fi (for example the phone is on mobile data):

1. On one device, tap **Create cloud code**.
2. On the other, enter that eight-character code and tap **Join with code**.

Both apps need an internet connection while they are open. They do not need to be nearby, and they do not need to be online at the exact same moment.

If an older build could not reach cloud sync, leave the household on both devices and create a new code after updating.

### Lists with the same name

If both devices already have a shopping or pantry list with the same name, sync merges them and appends items. It does not create a second list that repeats what you already have.

## Appearance and About

In **Settings**, choose **System**, **Light**, or **Dark**.

**About** is the last section in Settings on both platforms. It shows the app name and version inline—it does not open another dialog.

## Releases

Each app update merged to `main` bumps the version in `pubspec.yaml` by `0.0.1` and publishes a Windows installer and an Android APK together. The Releases page keeps only the three newest builds.
