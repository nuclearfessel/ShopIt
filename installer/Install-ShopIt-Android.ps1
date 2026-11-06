# Installs or replaces ShopIt on a connected Android device via adb.
# Same version: override in place (adb install -r).
# When ShopIt is already installed, you choose whether to keep lists and/or settings.
param(
  [Parameter(Mandatory = $false)]
  [string]$ApkPath,
  [Parameter(Mandatory = $false)]
  [ValidateSet("KeepAll", "KeepLists", "KeepSettings", "ClearAll")]
  [string]$DataChoice
)

$ErrorActionPreference = "Stop"
$Package = "com.nuclearfessel.shop_it"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$KeepLists = $true
$KeepSettings = $true

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

function Set-DataChoiceFromPrompt {
  Write-Host ""
  Write-Host "ShopIt is already on the device. Choose what to keep:"
  Write-Host "  1) Keep lists and settings"
  Write-Host "  2) Keep lists, reset settings"
  Write-Host "  3) Keep settings, clear lists"
  Write-Host "  4) Clear lists and settings"
  Write-Host ""
  while ($true) {
    $reply = Read-Host "Choice [1]"
    if ([string]::IsNullOrWhiteSpace($reply)) { $reply = "1" }
    switch ($reply) {
      "1" { $script:KeepLists = $true; $script:KeepSettings = $true; return }
      "2" { $script:KeepLists = $true; $script:KeepSettings = $false; return }
      "3" { $script:KeepLists = $false; $script:KeepSettings = $true; return }
      "4" { $script:KeepLists = $false; $script:KeepSettings = $false; return }
      default { Write-Host "Enter 1, 2, 3, or 4." }
    }
  }
}

function Set-DataChoiceFromFlag {
  param([string]$Choice)
  switch ($Choice) {
    "KeepAll" { $script:KeepLists = $true; $script:KeepSettings = $true }
    "KeepLists" { $script:KeepLists = $true; $script:KeepSettings = $false }
    "KeepSettings" { $script:KeepLists = $false; $script:KeepSettings = $true }
    "ClearAll" { $script:KeepLists = $false; $script:KeepSettings = $false }
  }
}

function Clear-AllAppData {
  & adb shell pm clear $Package 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) {
    & adb uninstall $Package 2>$null | Out-Null
  }
}

function Try-ClearLists {
  & adb shell "run-as $Package sh -c 'rm -f files/shop_it.sqlite files/shop_it.sqlite-wal files/shop_it.sqlite-shm'" 2>$null | Out-Null
  return ($LASTEXITCODE -eq 0)
}

function Try-ClearSettings {
  & adb shell "run-as $Package sh -c 'rm -f shared_prefs/FlutterSharedPreferences.xml'" 2>$null | Out-Null
  return ($LASTEXITCODE -eq 0)
}

function Apply-DataChoice {
  if ($KeepLists -and $KeepSettings) {
    Write-Host "Keeping lists and settings."
    return
  }
  if (-not $KeepLists -and -not $KeepSettings) {
    Write-Host "Clearing lists and settings on the device."
    Clear-AllAppData
    return
  }

  $ok = $true
  if (-not $KeepLists) {
    if (Try-ClearLists) {
      Write-Host "Cleared shopping lists, pantry, history, and recipes."
    } else {
      $ok = $false
    }
  }
  if (-not $KeepSettings) {
    if (Try-ClearSettings) {
      Write-Host "Cleared settings."
    } else {
      $ok = $false
    }
  }
  if ($ok) { return }

  Write-Host ""
  Write-Host "This install cannot clear lists and settings separately (release builds"
  Write-Host "block that). Choose:"
  Write-Host "  K) Keep everything and continue"
  Write-Host "  C) Clear lists and settings, then continue"
  while ($true) {
    $reply = Read-Host "Choice [K]"
    if ([string]::IsNullOrWhiteSpace($reply)) { $reply = "K" }
    switch -Regex ($reply) {
      '^[Kk]$' { Write-Host "Keeping lists and settings."; return }
      '^[Cc]$' { Clear-AllAppData; Write-Host "Cleared lists and settings."; return }
      default { Write-Host "Enter K or C." }
    }
  }
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
  }
  if ($DataChoice) {
    Set-DataChoiceFromFlag -Choice $DataChoice
  } else {
    Set-DataChoiceFromPrompt
  }
  Apply-DataChoice
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
