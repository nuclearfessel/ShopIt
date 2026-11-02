# Installs or replaces ShopIt on a connected Android device via adb.
# Same version: override in place (adb install -r).
# Previous version: replace the installed package in place, keeping lists and
# settings — the same keep-data upgrade path as Windows Setup.
param(
  [Parameter(Mandatory = $false)]
  [string]$ApkPath
)

$ErrorActionPreference = "Stop"
$Package = "com.nuclearfessel.shop_it"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Find-ShopItApk {
  param([string]$Explicit)
  if ($Explicit) {
    if (-not (Test-Path -LiteralPath $Explicit)) {
      throw "APK not found: $Explicit"
    }
    return (Resolve-Path -LiteralPath $Explicit).Path
  }
  $named = Get-ChildItem -LiteralPath $ScriptDir -Filter "ShopIt-*.apk" -File -ErrorAction SilentlyContinue |
    Sort-Object Name |
    Select-Object -Last 1
  if ($named) { return $named.FullName }
  $any = Get-ChildItem -LiteralPath $ScriptDir -Filter "*.apk" -File -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if ($any) { return $any.FullName }
  throw "No ShopIt APK found. Pass -ApkPath or place ShopIt-*.apk next to this script."
}

function Require-Adb {
  if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    throw "adb was not found. Install Android platform-tools and retry."
  }
  & adb start-server | Out-Null
  $devices = & adb devices | Select-Object -Skip 1 | Where-Object { $_ -match "\tdevice$" }
  if (-not $devices) {
    throw "No Android device or emulator is connected (adb devices)."
  }
}

function Get-ApkVersionName {
  param([string]$Apk)
  foreach ($tool in @("aapt", "aapt2")) {
    if (Get-Command $tool -ErrorAction SilentlyContinue) {
      $line = & $tool dump badging $Apk 2>$null | Select-String -Pattern "versionName='([^']+)'" | Select-Object -First 1
      if ($line -and $line.Matches.Count -gt 0) {
        return $line.Matches[0].Groups[1].Value
      }
    }
  }
  $name = [IO.Path]::GetFileName($Apk)
  if ($name -match "^ShopIt-([0-9]+(?:\.[0-9]+)+)\.apk$") {
    return $Matches[1]
  }
  return "unknown"
}

function Test-PackageInstalled {
  $path = & adb shell pm path $Package 2>$null
  return [bool]($path -and ($path -join "").Trim())
}

function Get-InstalledVersionName {
  $dump = & adb shell dumpsys package $Package 2>$null
  foreach ($line in $dump) {
    if ($line -match "versionName=([^\s]+)") {
      return $Matches[1].Trim()
    }
  }
  return "unknown"
}

$apk = Find-ShopItApk -Explicit $ApkPath
Require-Adb
$newVersion = Get-ApkVersionName -Apk $apk

if (Test-PackageInstalled) {
  $oldVersion = Get-InstalledVersionName
  if ($oldVersion -eq $newVersion) {
    Write-Host "ShopIt $oldVersion is already installed. Overriding it in place."
  } else {
    Write-Host "Replacing ShopIt $oldVersion with $newVersion."
    Write-Host "Your lists and settings are kept."
  }
} else {
  Write-Host "Installing ShopIt $newVersion."
}

& adb install -r -d $apk
if ($LASTEXITCODE -ne 0) {
  Write-Host "In-place replace failed; removing the previous package and installing fresh."
  Write-Host "Lists and settings on the device will be cleared."
  & adb uninstall $Package 2>$null
  & adb install $apk
  if ($LASTEXITCODE -ne 0) { throw "adb install failed with exit code $LASTEXITCODE" }
}
Write-Host "Done. Package $Package is ready on the device."
