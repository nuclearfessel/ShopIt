#!/usr/bin/env bash
# Installs or replaces ShopIt on a connected Android device via adb.
# Same version: override in place (adb install -r).
# Previous version: replace the installed package in place (adb install -r),
# keeping lists and settings — the same keep-data upgrade path as Windows Setup.
set -euo pipefail

PACKAGE="com.nuclearfessel.shop_it"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

pick_apk() {
  if [[ $# -ge 1 && -f "$1" ]]; then
    echo "$1"
    return
  fi
  local match
  match="$(ls -1 "$SCRIPT_DIR"/ShopIt-*.apk 2>/dev/null | sort -V | tail -n 1 || true)"
  if [[ -n "$match" ]]; then
    echo "$match"
    return
  fi
  match="$(ls -1 "$SCRIPT_DIR"/*.apk 2>/dev/null | head -n 1 || true)"
  if [[ -n "$match" ]]; then
    echo "$match"
    return
  fi
  return 1
}

require_adb() {
  if ! command -v adb >/dev/null 2>&1; then
    echo "adb was not found. Install Android platform-tools and retry."
    exit 1
  fi
  adb start-server >/dev/null
  local devices
  devices="$(adb devices | awk 'NR>1 && $2=="device" {print $1}')"
  if [[ -z "$devices" ]]; then
    echo "No Android device or emulator is connected (adb devices)."
    exit 1
  fi
}

apk_version_name() {
  local apk="$1"
  if command -v aapt >/dev/null 2>&1; then
    aapt dump badging "$apk" 2>/dev/null | sed -n "s/.*versionName='\([^']*\)'.*/\1/p" | head -n 1
    return
  fi
  if command -v aapt2 >/dev/null 2>&1; then
    aapt2 dump badging "$apk" 2>/dev/null | sed -n "s/.*versionName='\([^']*\)'.*/\1/p" | head -n 1
    return
  fi
  local base
  base="$(basename "$apk")"
  if [[ "$base" =~ ShopIt-([0-9]+(\.[0-9]+)*).apk ]]; then
    echo "${BASH_REMATCH[1]}"
    return
  fi
  echo ""
}

installed_version_name() {
  adb shell dumpsys package "$PACKAGE" 2>/dev/null \
    | tr -d '\r' \
    | sed -n 's/.*versionName=\([^ ]*\).*/\1/p' \
    | head -n 1
}

package_installed() {
  adb shell pm path "$PACKAGE" 2>/dev/null | tr -d '\r' | grep -q .
}

APK="$(pick_apk "${1:-}" || true)"
if [[ -z "${APK:-}" ]]; then
  echo "No ShopIt APK found. Pass a path or place ShopIt-*.apk next to this script."
  exit 1
fi
APK="$(cd "$(dirname "$APK")" && pwd)/$(basename "$APK")"

require_adb
NEW_VERSION="$(apk_version_name "$APK")"
[[ -n "$NEW_VERSION" ]] || NEW_VERSION="unknown"

if package_installed; then
  OLD_VERSION="$(installed_version_name)"
  [[ -n "$OLD_VERSION" ]] || OLD_VERSION="unknown"
  if [[ "$OLD_VERSION" == "$NEW_VERSION" ]]; then
    echo "ShopIt ${OLD_VERSION} is already installed. Overriding it in place."
  else
    echo "Replacing ShopIt ${OLD_VERSION} with ${NEW_VERSION}."
    echo "Your lists and settings are kept."
  fi
else
  echo "Installing ShopIt ${NEW_VERSION}."
fi

# -r replaces an existing install. -d allows installing an older build when needed.
if ! adb install -r -d "$APK"; then
  echo "In-place replace failed; removing the previous package and installing fresh."
  echo "Lists and settings on the device will be cleared."
  adb uninstall "$PACKAGE" || true
  adb install "$APK"
fi
echo "Done. Package ${PACKAGE} is ready on the device."
