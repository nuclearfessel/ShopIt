# Using Shop-it

Shop-it runs the same way on Windows and Android. Use **Shopping** for what you need to buy and **Pantry** for what you already have. On a wide window those sections are in the left rail; on a phone they are in the bottom bar.

Open **Settings** from the gear icon for appearance, sales tax, sharing, and About.

## Shopping

1. Open **Shopping**.
2. Create a list from the empty screen, or choose **New list** from the list menu.
3. If you have more than one list, use the name at the top to switch between them.
4. Type in **Search or add an item**, then press Enter or tap **+**. Use the pen to set quantity, unit, category, price, tax, and a note before you add.
5. Tap an item to edit it. Check an item to move it into the cart.

From the cart you can uncheck everything or delete the checked items.

The list menu covers a new list, move/copy, check and uncheck, categories, list settings, manage lists, CSV import and export, rename, and delete. **Rename this list** sits directly above **Delete this list**. Delete still asks you to confirm.

### Search

The field at the top looks through more than the catalog.

- **On this list** — the name is already on the open shopping list. Choosing it does not add a second copy. Shop-it shows that it is already there and moves the list to that item.
- **In pantry** — you already have it in the pantry. Choosing it does not add it to the shopping list.
- **Recent** — a name from History that is not already on this list or in the pantry. Choosing it adds the item again.
- Catalog matches come after those. Press Enter or tap **+** to add something that is not already on the list or in the pantry.

With the field focused and empty, Shop-it shows up to six recent names so repeat groceries are one tap away. The History button is still there if you want the full list.

### List settings and categories

Categories are alphabetical on every list. A new category slots into that order on its own.

**List settings** controls whether items are grouped by category, whether new items are filed automatically, and whether empty category headers stay visible. The same screen is where you change tax for the whole list:

- **Use automatic tax rules** — each item follows the rate's rules again.
- **Mark all items taxable**
- **Mark all items not taxable**

Tap a category header to change its color. Manage the full category list from the list menu: add, recolor, or delete. There is no drag-to-reorder.

## Pantry

Open **Pantry** for stock you already have. Add items the same way as on a shopping list. An item can use a count or a level (full or low), and it can include a place and an expiry date.

**Use soon** appears at the top when something expires within the next seven days, or is already past its date. Each name says **today**, **tomorrow**, **in N days**, or **expired**.

**Move/Copy items** sends items between shopping lists and pantry lists—handy when you restock or finish something.

## Sales tax

In **Settings**, under sales tax:

- Choose **No tax**, or add a saved rate.
- **Use my location** looks up a rate for where you are. In the US that lookup can use a Ziptax key saved in the same section. Nothing is sent until you tap the button.

Open Settings from a shopping list to pick which rate that list uses. Each rate has its own tax rules (what is taxed). New items start taxable. You can turn tax off for one item in the item editor. To change every item on the list, open **List settings** from the list menu.

## Sync between phone and computer

On both devices, open **Settings → Share lists**.

The summary at the top tells you which channels are on. Under it, each channel has its own line:

- **Wi-Fi: synced just now** (or a longer time), or **Wi-Fi: not synced yet.**
- **Cloud: synced just now**, or **Cloud: not synced yet.**

A failure stays on that channel. A successful Wi-Fi sync does not clear a cloud error, and the other way around. The same errors also show under **Devices** in Settings.

### Same Wi-Fi

Turn on **Share on this Wi-Fi** on both devices. Keep both apps open on the same network. Lists and items appear on the other device without typing an address or code.

If Windows asks whether to allow Shop-it on private networks, choose allow. The phone cannot reach the computer on Wi-Fi until you do.

### Over the internet

When you are not on the same Wi-Fi (for example the phone is on mobile data):

1. On one device, tap **Create cloud code**.
2. On the other, enter that eight-character code and tap **Join with code**.

Both apps need an internet connection while they are open. They do not need to be nearby, and they do not need to be online at the exact same moment. Closing the app, or sending it to the background, publishes one last cloud snapshot.

List contents are encrypted with the household code before they are stored. The sync service only keeps that encrypted copy. It does not receive item names, prices, or notes. Anyone who can see the stored message still cannot read the lists without the code.

If you paired on a build before 0.0.8, leave the household on both devices and create a new code after updating. Older cloud messages are ignored.

### Lists with the same name

If both devices already have a shopping or pantry list with the same name, sync merges them and appends items. It does not create a second list that repeats what you already have.

## Appearance and About

In **Settings**, choose **System**, **Light**, or **Dark**.

**About** is the last section in Settings on both platforms. It shows the app name and version inline—it does not open another dialog.

## Releases

Each app update merged to `main` bumps the version in `pubspec.yaml` by `0.0.1` and publishes a Windows installer and an Android APK together. The Releases page keeps only the three newest builds. Changes that only touch this guide or the GitHub README do not publish a new build.
