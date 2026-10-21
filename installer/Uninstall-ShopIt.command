#!/bin/bash
# Removes ShopIt.app and the lists, settings, and folders it created on this Mac.
set -euo pipefail

APP_NAME="ShopIt"
BUNDLE_ID="com.nuclearfessel.shopit"

echo "This removes $APP_NAME from this Mac,"
echo "including shopping lists, settings, and data folders."
echo
read -r -p "Uninstall $APP_NAME completely? [y/N] " reply
case "$reply" in
  y|Y|yes|YES) ;;
  *)
    echo "Cancelled."
    exit 0
    ;;
esac

# Stop a running copy so files are not locked.
if pgrep -xq "$APP_NAME" >/dev/null 2>&1; then
  osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
  sleep 1
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
fi

remove_path() {
  local path="$1"
  if [ -e "$path" ] || [ -L "$path" ]; then
    rm -rf "$path"
    echo "Removed $path"
  fi
}

# Common places the unzipped app is kept.
remove_path "/Applications/${APP_NAME}.app"
remove_path "$HOME/Applications/${APP_NAME}.app"
remove_path "$HOME/Desktop/${APP_NAME}.app"
remove_path "$HOME/Downloads/${APP_NAME}.app"

# If this script sits next to ShopIt.app (as in the release zip), remove that copy too.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
remove_path "${SCRIPT_DIR}/${APP_NAME}.app"

# Application Support holds shop_it.sqlite and related files.
remove_path "$HOME/Library/Application Support/${BUNDLE_ID}"
# Older Flutter layouts sometimes used the product name.
remove_path "$HOME/Library/Application Support/${APP_NAME}"

# SharedPreferences / UserDefaults.
remove_path "$HOME/Library/Preferences/${BUNDLE_ID}.plist"
remove_path "$HOME/Library/Preferences/${BUNDLE_ID}.plist.lockfile"

# Caches and saved state.
remove_path "$HOME/Library/Caches/${BUNDLE_ID}"
remove_path "$HOME/Library/Caches/${APP_NAME}"
remove_path "$HOME/Library/Saved Application State/${BUNDLE_ID}.savedState"
remove_path "$HOME/Library/HTTPStorages/${BUNDLE_ID}"
remove_path "$HOME/Library/HTTPStorages/${BUNDLE_ID}.binarycookies"
remove_path "$HOME/Library/WebKit/${BUNDLE_ID}"
remove_path "$HOME/Library/Logs/${BUNDLE_ID}"
remove_path "$HOME/Library/Logs/${APP_NAME}"

# Clear any defaults domain that is still registered.
defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true

echo
echo "$APP_NAME has been uninstalled."
read -r -p "Press Return to close." _
