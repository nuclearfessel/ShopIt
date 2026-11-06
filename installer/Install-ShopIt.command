#!/bin/bash
# Installs or replaces ShopIt.app on this Mac.
# Same version: overwrite in place. Previous version: remove the old app, then install.
# When ShopIt is already present, you choose whether to keep lists and/or settings.
set -euo pipefail

APP_NAME="ShopIt"
BUNDLE_ID="com.nuclearfessel.shopit"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="${SCRIPT_DIR}/${APP_NAME}.app"
DEST="/Applications/${APP_NAME}.app"
SUPPORT_DIR="$HOME/Library/Application Support/${BUNDLE_ID}"
SUPPORT_DIR_ALT="$HOME/Library/Application Support/${APP_NAME}"
PREFS_PLIST="$HOME/Library/Preferences/${BUNDLE_ID}.plist"

KEEP_LISTS=1
KEEP_SETTINGS=1

if [[ ! -d "$SRC" ]]; then
  echo "${APP_NAME}.app was not found next to this installer."
  echo "Keep Install-ShopIt.command beside ${APP_NAME}.app from the release zip."
  read -r -p "Press Return to close." _
  exit 1
fi

read_version() {
  local app="$1"
  /usr/bin/defaults read "${app}/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo ""
}

quit_shopit() {
  if pgrep -xq "$APP_NAME" >/dev/null 2>&1; then
    osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
    sleep 1
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  fi
}

clear_lists() {
  rm -f "$SUPPORT_DIR"/shop_it.sqlite "$SUPPORT_DIR"/shop_it.sqlite-wal "$SUPPORT_DIR"/shop_it.sqlite-shm
  rm -f "$SUPPORT_DIR_ALT"/shop_it.sqlite "$SUPPORT_DIR_ALT"/shop_it.sqlite-wal "$SUPPORT_DIR_ALT"/shop_it.sqlite-shm
  echo "Cleared shopping lists, pantry, history, and recipes."
}

clear_settings() {
  rm -f "$PREFS_PLIST" "$PREFS_PLIST.lockfile"
  defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
  echo "Cleared settings."
}

ask_data_choice() {
  echo
  echo "ShopIt is already on this Mac. Choose what to keep:"
  echo "  1) Keep lists and settings"
  echo "  2) Keep lists, reset settings"
  echo "  3) Keep settings, clear lists"
  echo "  4) Clear lists and settings"
  echo
  while true; do
    read -r -p "Choice [1]: " reply
    reply="${reply:-1}"
    case "$reply" in
      1)
        KEEP_LISTS=1
        KEEP_SETTINGS=1
        return
        ;;
      2)
        KEEP_LISTS=1
        KEEP_SETTINGS=0
        return
        ;;
      3)
        KEEP_LISTS=0
        KEEP_SETTINGS=1
        return
        ;;
      4)
        KEEP_LISTS=0
        KEEP_SETTINGS=0
        return
        ;;
      *)
        echo "Enter 1, 2, 3, or 4."
        ;;
    esac
  done
}

apply_data_choice() {
  if [[ "$KEEP_LISTS" -eq 0 ]]; then
    clear_lists
  fi
  if [[ "$KEEP_SETTINGS" -eq 0 ]]; then
    clear_settings
  fi
  if [[ "$KEEP_LISTS" -eq 1 && "$KEEP_SETTINGS" -eq 1 ]]; then
    echo "Keeping lists and settings."
  fi
}

NEW_VERSION="$(read_version "$SRC")"
[[ -n "$NEW_VERSION" ]] || NEW_VERSION="unknown"

quit_shopit

if [[ -d "$DEST" ]]; then
  OLD_VERSION="$(read_version "$DEST")"
  [[ -n "$OLD_VERSION" ]] || OLD_VERSION="unknown"
  if [[ "$OLD_VERSION" == "$NEW_VERSION" ]]; then
    echo "ShopIt ${OLD_VERSION} is already in Applications. Overriding it."
  else
    echo "Replacing ShopIt ${OLD_VERSION} with ${NEW_VERSION}."
  fi
  ask_data_choice
  apply_data_choice
  rm -rf "$DEST"
else
  echo "Installing ShopIt ${NEW_VERSION} to Applications."
fi

mkdir -p "/Applications"
cp -R "$SRC" "$DEST"
echo
echo "ShopIt ${NEW_VERSION} is installed at ${DEST}."
echo "Bundle id ${BUNDLE_ID} is unchanged, so kept data stays available."
read -r -p "Press Return to close." _
