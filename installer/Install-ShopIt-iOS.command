#!/bin/bash
# Installs or replaces ShopIt on a connected iPhone/iPad.
# Same version: override in place. Previous version: replace the installed
# bundle in place, keeping lists and settings when the device accepts an update.
#
# Expects a signed ShopIt.ipa (or .app) next to this script, or a path argument.
# Requires Xcode's devicectl, ideviceinstaller, or ios-deploy, plus a paired device.
set -euo pipefail

APP_NAME="ShopIt"
BUNDLE_ID="com.nuclearfessel.shopit"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

pick_payload() {
  if [[ $# -ge 1 && -e "$1" ]]; then
    echo "$1"
    return
  fi
  local match
  match="$(ls -1 "$SCRIPT_DIR"/ShopIt-*.ipa 2>/dev/null | sort -V | tail -n 1 || true)"
  [[ -n "$match" ]] && { echo "$match"; return; }
  match="$(ls -1 "$SCRIPT_DIR"/*.ipa 2>/dev/null | head -n 1 || true)"
  [[ -n "$match" ]] && { echo "$match"; return; }
  if [[ -d "$SCRIPT_DIR/${APP_NAME}.app" ]]; then
    echo "$SCRIPT_DIR/${APP_NAME}.app"
    return
  fi
  return 1
}

payload_version() {
  local payload="$1"
  if [[ -d "$payload" && -f "$payload/Info.plist" ]]; then
    /usr/bin/defaults read "${payload}/Info" CFBundleShortVersionString 2>/dev/null || echo ""
    return
  fi
  if [[ -f "$payload" && "$payload" == *.ipa ]]; then
    local tmp
    tmp="$(mktemp -d)"
    unzip -qq -o "$payload" -d "$tmp" "Payload/*.app/Info.plist" 2>/dev/null || true
    local plist
    plist="$(find "$tmp/Payload" -name Info.plist 2>/dev/null | head -n 1 || true)"
    if [[ -n "$plist" ]]; then
      /usr/bin/defaults read "${plist%.plist}" CFBundleShortVersionString 2>/dev/null || \
        /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist" 2>/dev/null || echo ""
      rm -rf "$tmp"
      return
    fi
    rm -rf "$tmp"
  fi
  local base
  base="$(basename "$payload")"
  if [[ "$base" =~ ShopIt-([0-9]+(\.[0-9]+)*).ipa ]]; then
    echo "${BASH_REMATCH[1]}"
    return
  fi
  echo ""
}

first_device_udid() {
  if command -v xcrun >/dev/null 2>&1; then
    xcrun xctrace list devices 2>/dev/null \
      | sed -n 's/.*(\([0-9A-Fa-f-]\{25,\}\)).*/\1/p' \
      | head -n 1 || true
  fi
}

installed_version_idevice() {
  if ! command -v ideviceinstaller >/dev/null 2>&1; then
    echo ""
    return
  fi
  ideviceinstaller -l 2>/dev/null \
    | tr -d '\r' \
    | awk -F',' -v id="$BUNDLE_ID" '
        index($0, id) {
          for (i = 1; i <= NF; i++) {
            if ($i ~ /^[0-9]+(\.[0-9]+)+$/) { print $i; exit }
          }
        }'
}

app_installed_idevice() {
  command -v ideviceinstaller >/dev/null 2>&1 || return 1
  ideviceinstaller -l 2>/dev/null | tr -d '\r' | grep -F "$BUNDLE_ID" >/dev/null
}

install_with_devicectl() {
  local payload="$1"
  local udid
  udid="$(first_device_udid)"
  if [[ -z "$udid" ]]; then
    return 1
  fi
  xcrun devicectl device install app --device "$udid" "$payload"
}

install_with_ideviceinstaller() {
  local payload="$1"
  ideviceinstaller -i "$payload"
}

install_with_ios_deploy() {
  local payload="$1"
  if [[ -d "$payload" ]]; then
    ios-deploy --bundle "$payload"
  else
    return 1
  fi
}

PAYLOAD="$(pick_payload "${1:-}" || true)"
if [[ -z "${PAYLOAD:-}" ]]; then
  echo "No signed ShopIt.ipa (or ShopIt.app) found."
  echo "Pass a path, or place the signed package next to this script."
  echo "iOS requires a development or distribution-signed build to install on a device."
  read -r -p "Press Return to close." _
  exit 1
fi
if [[ -f "$PAYLOAD" ]]; then
  PAYLOAD="$(cd "$(dirname "$PAYLOAD")" && pwd)/$(basename "$PAYLOAD")"
elif [[ -d "$PAYLOAD" ]]; then
  PAYLOAD="$(cd "$PAYLOAD" && pwd)"
fi

NEW_VERSION="$(payload_version "$PAYLOAD")"
[[ -n "$NEW_VERSION" ]] || NEW_VERSION="unknown"

HAS_INSTALLER=0
if command -v xcrun >/dev/null 2>&1 && xcrun --find devicectl >/dev/null 2>&1; then
  HAS_INSTALLER=1
fi
if command -v ideviceinstaller >/dev/null 2>&1; then
  HAS_INSTALLER=1
fi
if command -v ios-deploy >/dev/null 2>&1; then
  HAS_INSTALLER=1
fi
if [[ "$HAS_INSTALLER" -eq 0 ]]; then
  echo "No iOS install tool found. Install Xcode (devicectl), libimobiledevice"
  echo "(ideviceinstaller), or ios-deploy, pair a device, and retry."
  read -r -p "Press Return to close." _
  exit 1
fi

if app_installed_idevice; then
  OLD_VERSION="$(installed_version_idevice)"
  [[ -n "$OLD_VERSION" ]] || OLD_VERSION="unknown"
  if [[ "$OLD_VERSION" == "$NEW_VERSION" ]]; then
    echo "ShopIt ${OLD_VERSION} is already installed. Overriding it in place."
  else
    echo "Replacing ShopIt ${OLD_VERSION} with ${NEW_VERSION}."
    echo "Your lists and settings are kept when the device accepts an in-place update."
  fi
else
  echo "Installing ShopIt ${NEW_VERSION}."
fi

if command -v xcrun >/dev/null 2>&1 && xcrun --find devicectl >/dev/null 2>&1; then
  if install_with_devicectl "$PAYLOAD"; then
    echo "Done. ${BUNDLE_ID} is installed via devicectl."
    read -r -p "Press Return to close." _
    exit 0
  fi
fi

if command -v ideviceinstaller >/dev/null 2>&1; then
  if install_with_ideviceinstaller "$PAYLOAD"; then
    echo "Done. ${BUNDLE_ID} is installed via ideviceinstaller."
    read -r -p "Press Return to close." _
    exit 0
  fi
fi

if command -v ios-deploy >/dev/null 2>&1; then
  if install_with_ios_deploy "$PAYLOAD"; then
    echo "Done. ${BUNDLE_ID} is installed via ios-deploy."
    read -r -p "Press Return to close." _
    exit 0
  fi
fi

echo "Install failed. Confirm the IPA/APP is signed for this device and try again."
read -r -p "Press Return to close." _
exit 1
