# Using Shop-it

Shop-it keeps a shopping list and a pantry list. The Windows app and the Android app are the same program. On a wide window the sections sit in a rail on the left. On a phone they sit in a bar along the bottom.

## Shopping

Open **Shopping**.

- **Create a list** from the empty screen, or from the list menu choose **New list**.
- With more than one list, the name at the top is a pull-down. Choose the list you want.
- Type in **Search or add an item**, then press Enter or tap **+** to add it. Tap the pen to set quantity, unit, category, price, tax, and a note before adding.
- Tap an item to edit it. Check an item to move it into the cart. From the cart you can uncheck everything or delete the checked items.
- **History** offers items you have added before.
- The list menu also covers categories, list settings, renaming and reordering lists, CSV export and import, tax for every item, and deleting a list.

**List settings** choose whether items are grouped by category, whether a new item is filed into a category on its own, and whether empty categories stay visible. Tap a category header to change its color.

## Pantry

Open **Pantry**.

A pantry list is what you already have. Add items the same way as on a shopping list. An item can be a count or a level such as full or low, and it can have a place and an expiry date.

**Move/Copy items** sends items between shopping lists and pantry lists.

## Sales tax

Open **Settings** from the gear icon.

Under sales tax, pick **No tax** or add a rate. **Use my location** looks up a rate for where you are. In the US that lookup can use a Ziptax key, which you can save from the same section. Nothing is sent until you tap the button.

Open Settings from a shopping list to choose which rate that list uses. Tax rules, meaning what is taxed, are chosen on each rate. New items start out taxable. You can turn tax off for one item, or for the whole list from the list menu.

## Share a list between the phone and the computer

On both devices, open **Settings**, then **Share lists**.

### On this Wi-Fi

Turn on **Share on this Wi-Fi** on both devices. Both apps need to be open on the same network. A list you add on one shows up on the other. There is no address to type.

If Windows asks whether to allow Shop-it on private networks, choose allow. The phone cannot reach the computer on Wi-Fi until you do.

### Over the internet

When the phone is on mobile data, or the two are not on the same Wi-Fi, use cloud sync. On one device tap **Create cloud code**, then on the other enter that eight-character code and tap **Join with code**. Both apps need an internet connection while they are open. Lists still sync even when the devices are not near each other. Cloud sync uses a public MQTT mailbox; leave the household and create a new code if an older release could not reach the mailbox.

### Same list name

If both devices already have a shopping or pantry list with the same name, sync appends the items into that list. It does not create a second list that repeats the same items.

## Appearance and About

**Settings** also has appearance: System, Light, or Dark.

**About** is the last section in Settings, on Windows and on Android. It names the app and shows the version. It does not open another screen.

## Versions and releases

Each update of the app that is merged to `main` raises the version in `pubspec.yaml` by 0.0.1, for example 0.0.4 then 0.0.5. That merge builds a Windows installer and an Android APK and publishes them together under that version.

The release section keeps only the three newest releases. Older releases are removed when a new one is published.
