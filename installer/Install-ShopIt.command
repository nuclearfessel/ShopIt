#!/bin/bash
# Installs or replaces ShopIt.app on this Mac.
# Same version: overwrite in place. Previous version: remove the old app, then install.
# Lists and settings in Application Support are kept either way.
set -euo pipefail

APP_NAME="ShopIt"
BUNDLE_ID="com.nuclearfessel.shopit"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="${SCRIPT_DIR}/${APP_NAME}.app"
DEST="/Applications/${APP_NAME}.app"

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
    echo "Your lists and settings are kept."
  fi
  rm -rf "$DEST"
else
  echo "Installing ShopIt ${NEW_VERSION} to Applications."
fi

mkdir -p "/Applications"
cp -R "$SRC" "$DEST"
echo
echo "ShopIt ${NEW_VERSION} is installed at ${DEST}."
echo "Bundle id ${BUNDLE_ID} is unchanged, so prior data stays available."
read -r -p "Press Return to close." _
