# Install and update (backup)

Not linked from the User Guide. Paste back into `usage.md` when you want this section live again.

## Install and update

- **Windows** — run `ShopIt-Setup-….exe`. If this version is already installed, Setup overrides it in place. If a previous version is installed, Setup replaces it. When ShopIt is already present, Setup asks whether to keep lists and/or settings. Silent flags: `/CLEAR_LISTS`, `/CLEAR_SETTINGS`, `/CLEAR_DATA`.
- **Mac** — unzip the release zip and run **Install-ShopIt.command** next to `ShopIt.app` (or copy the app into Applications). Same version is overwritten; a previous version is replaced. The command asks whether to keep lists and/or settings when replacing.
- **Android** — open the APK, or use `Install-ShopIt-Android.sh` / `.ps1` from the android zip with a device on adb. The helpers ask whether to keep lists and/or settings when ShopIt is already installed.
- **iPhone / iPad** — TestFlight when connected to an Apple Developer account. The ios-install zip has a device helper for a signed build on a paired Mac; it can keep everything or clear everything when replacing.
