# Install and update (backup)

Not linked from the User Guide. Paste back into `usage.md` when you want this section live again.

## Install and update

- **Windows** — run `ShopIt-Setup-….exe`. If this version is already installed, Setup overrides it in place. If a previous version is installed, Setup removes that program install and installs the new one; lists and settings are kept.
- **Mac** — unzip the release zip and run **Install-ShopIt.command** next to `ShopIt.app` (or copy the app into Applications). Same version is overwritten; a previous version is replaced. Lists stay in Application Support.
- **Android** — open the APK, or use `Install-ShopIt-Android.sh` / `.ps1` from the android zip with a device on adb. The helpers replace the installed package in place when they can.
- **iPhone / iPad** — TestFlight when connected to an Apple Developer account. The ios-install zip has a device helper for a signed build on a paired Mac.
