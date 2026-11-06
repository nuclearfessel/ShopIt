#!/usr/bin/env bash
# Installs or replaces ShopIt on a connected Android device via adb.
# Same version: override in place (adb install -r).
# When ShopIt is already installed, you choose whether to keep lists and/or settings.
set -euo pipefail

PACKAGE="com.nuclearfessel.shop_it"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KEEP_LISTS=1
KEEP_SETTINGS=1

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

ask_data_choice() {
  echo
  echo "ShopIt is already on the device. Choose what to keep:"
  echo "  1) Keep lists and settings"
  echo "  2) Keep lists, reset settings"
  echo "  3) Keep settings, clear lists"
  echo "  4) Clear lists and settings"
  echo
  while true; do
    read -r -p "Choice [1]: " reply || reply=1
    reply="${reply:-1}"
    case "$reply" in
      1) KEEP_LISTS=1; KEEP_SETTINGS=1; return ;;
      2) KEEP_LISTS=1; KEEP_SETTINGS=0; return ;;
      3) KEEP_LISTS=0; KEEP_SETTINGS=1; return ;;
      4) KEEP_LISTS=0; KEEP_SETTINGS=0; return ;;
      *) echo "Enter 1, 2, 3, or 4." ;;
    esac
  done
}

# Selective wipe needs run-as (debuggable builds). Release sideloads often cannot.
try_clear_lists() {
  adb shell "run-as $PACKAGE sh -c 'rm -f files/shop_it.sqlite files/shop_it.sqlite-wal files/shop_it.sqlite-shm'" >/dev/null 2>&1
}

try_clear_settings() {
  adb shell "run-as $PACKAGE sh -c 'rm -f shared_prefs/FlutterSharedPreferences.xml'" >/dev/null 2>&1
}

clear_all_app_data() {
  adb shell pm clear "$PACKAGE" >/dev/null 2>&1 || adb uninstall "$PACKAGE" >/dev/null 2>&1 || true
}

apply_data_choice() {
  if [[ "$KEEP_LISTS" -eq 1 && "$KEEP_SETTINGS" -eq 1 ]]; then
    echo "Keeping lists and settings."
    return 0
  fi
  if [[ "$KEEP_LISTS" -eq 0 && "$KEEP_SETTINGS" -eq 0 ]]; then
    echo "Clearing lists and settings on the device."
    clear_all_app_data
    return 0
  fi

  local ok=1
  if [[ "$KEEP_LISTS" -eq 0 ]]; then
    if try_clear_lists; then
      echo "Cleared shopping lists, pantry, history, and recipes."
    else
      ok=0
    fi
  fi
  if [[ "$KEEP_SETTINGS" -eq 0 ]]; then
    if try_clear_settings; then
      echo "Cleared settings."
    else
      ok=0
    fi
  fi
  if [[ "$ok" -eq 1 ]]; then
    return 0
  fi

  echo
  echo "This install cannot clear lists and settings separately (release builds"
  echo "block that). Choose:"
  echo "  K) Keep everything and continue"
  echo "  C) Clear lists and settings, then continue"
  while true; do
    read -r -p "Choice [K]: " reply || reply=K
    reply="${reply:-K}"
    case "$reply" in
      K|k) echo "Keeping lists and settings."; return 0 ;;
      C|c) clear_all_app_data; echo "Cleared lists and settings."; return 0 ;;
      *) echo "Enter K or C." ;;
    esac
  done
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
  fi
  ask_data_choice
  apply_data_choice
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
