; ShopIt Windows installer. The release workflow passes /DAppVersion=0.0.1.
#ifndef AppVersion
  #define AppVersion "0.0.1"
#endif
; Stable product id so Setup can find prior installs across versions.
; Inno requires "{{" in the script to embed a single "{" in AppId.
#define MyAppId "{8F3A1C2E-6B47-4D91-9E5A-2C7B0D4F6A18}"
#define UninstallRegKey "Software\Microsoft\Windows\CurrentVersion\Uninstall\" + MyAppId + "_is1"

[Setup]
AppId={{8F3A1C2E-6B47-4D91-9E5A-2C7B0D4F6A18}
AppName=ShopIt
AppVersion={#AppVersion}
AppPublisher=ShopIt
DefaultDirName={autopf}\Shop-it
DefaultGroupName=ShopIt
DisableProgramGroupPage=yes
DisableDirPage=auto
DirExistsWarning=no
UsePreviousAppDir=yes
UsePreviousGroup=yes
OutputDir=..\build\installer
OutputBaseFilename=ShopIt-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
WizardStyle=modern
CloseApplications=force
SetupMutex=ShopItSetupMutex
UninstallDisplayIcon={app}\shop_it.exe
UninstallDisplayName=ShopIt

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\ShopIt"; Filename: "{app}\shop_it.exe"
Name: "{group}\Uninstall ShopIt"; Filename: "{uninstallexe}"
Name: "{autodesktop}\ShopIt"; Filename: "{app}\shop_it.exe"

[Run]
Filename: "{app}\shop_it.exe"; Description: "Launch ShopIt"; Flags: nowait postinstall skipifsilent

; Only the program folder is always removed on uninstall. AppData is wiped from
; [Code] unless Setup is replacing a previous version (/KEEP_DATA).
[UninstallDelete]
Type: filesandordirs; Name: "{app}"

[Code]
var
  DataPage: TInputOptionWizardPage;
  UpgradeExisting: Boolean;
  KeepLists: Boolean;
  KeepSettings: Boolean;

function CmdLineHasFlag(const Flag: String): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to ParamCount do
    if CompareText(ParamStr(I), Flag) = 0 then
    begin
      Result := True;
      Exit;
    end;
end;

function KeepUserData(): Boolean;
begin
  { Upgrade path: previous-version uninstall must not wipe lists/settings. }
  Result := CmdLineHasFlag('/KEEP_DATA');
end;

function QueryUninstallValue(const ValueName: String; var Value: String): Boolean;
begin
  Result := RegQueryStringValue(HKLM, '{#UninstallRegKey}', ValueName, Value);
  if not Result then
    Result := RegQueryStringValue(HKCU, '{#UninstallRegKey}', ValueName, Value);
end;

function GetInstalledVersion(var InstalledVersion: String): Boolean;
begin
  { Prefer DisplayVersion only — DisplayName is the product label, not a version. }
  Result := QueryUninstallValue('DisplayVersion', InstalledVersion) and (InstalledVersion <> '');
end;

function IsShopItInstalled(): Boolean;
var
  Unused: String;
begin
  Result := QueryUninstallValue('UninstallString', Unused);
end;

function GetUninstallString(): String;
begin
  if not QueryUninstallValue('UninstallString', Result) then
    Result := '';
end;

function UninstallPreviousVersion(): Boolean;
var
  UninstallString: String;
  ResultCode: Integer;
begin
  Result := True;
  UninstallString := RemoveQuotes(GetUninstallString());
  if UninstallString = '' then
    Exit;

  { Remove the prior Program Files install; keep AppData via /KEEP_DATA. }
  if not Exec(
    UninstallString,
    '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /KEEP_DATA',
    '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    Result := False;
    Exit;
  end;
  Result := ResultCode = 0;
end;

procedure DeleteIfExists(const Path: String);
begin
  if FileExists(Path) then
    DeleteFile(Path);
end;

procedure ClearShopItLists();
var
  Root: String;
begin
  Root := ExpandConstant('{userappdata}\com.nuclearfessel\ShopIt\');
  DeleteIfExists(Root + 'shop_it.sqlite');
  DeleteIfExists(Root + 'shop_it.sqlite-wal');
  DeleteIfExists(Root + 'shop_it.sqlite-shm');
  Root := ExpandConstant('{userappdata}\com.nuclearfessel\shop_it\');
  DeleteIfExists(Root + 'shop_it.sqlite');
  DeleteIfExists(Root + 'shop_it.sqlite-wal');
  DeleteIfExists(Root + 'shop_it.sqlite-shm');
  Root := ExpandConstant('{localappdata}\com.nuclearfessel\ShopIt\');
  DeleteIfExists(Root + 'shop_it.sqlite');
  DeleteIfExists(Root + 'shop_it.sqlite-wal');
  DeleteIfExists(Root + 'shop_it.sqlite-shm');
  Root := ExpandConstant('{localappdata}\com.nuclearfessel\shop_it\');
  DeleteIfExists(Root + 'shop_it.sqlite');
  DeleteIfExists(Root + 'shop_it.sqlite-wal');
  DeleteIfExists(Root + 'shop_it.sqlite-shm');
end;

procedure ClearShopItSettings();
begin
  DeleteIfExists(ExpandConstant('{userappdata}\com.nuclearfessel\ShopIt\shared_preferences.json'));
  DeleteIfExists(ExpandConstant('{userappdata}\com.nuclearfessel\shop_it\shared_preferences.json'));
  DeleteIfExists(ExpandConstant('{localappdata}\com.nuclearfessel\ShopIt\shared_preferences.json'));
  DeleteIfExists(ExpandConstant('{localappdata}\com.nuclearfessel\shop_it\shared_preferences.json'));
end;

procedure ApplyDataRetentionChoice();
begin
  if not KeepLists then
    ClearShopItLists();
  if not KeepSettings then
    ClearShopItSettings();
end;

procedure ReadDataChoiceFromPage();
begin
  if Assigned(DataPage) then
  begin
    KeepLists := DataPage.Values[0];
    KeepSettings := DataPage.Values[1];
  end;
end;

procedure ResolveSilentDataFlags();
begin
  KeepLists := True;
  KeepSettings := True;
  if CmdLineHasFlag('/CLEAR_DATA') then
  begin
    KeepLists := False;
    KeepSettings := False;
  end;
  if CmdLineHasFlag('/CLEAR_LISTS') then
    KeepLists := False;
  if CmdLineHasFlag('/CLEAR_SETTINGS') then
    KeepSettings := False;
end;

function InitializeSetup(): Boolean;
var
  InstalledVersion: String;
begin
  Result := True;
  UpgradeExisting := False;
  KeepLists := True;
  KeepSettings := True;
  InstalledVersion := '';
  if not IsShopItInstalled() then
    Exit;

  UpgradeExisting := True;
  ResolveSilentDataFlags();

  if GetInstalledVersion(InstalledVersion) and
     (CompareText(InstalledVersion, '{#AppVersion}') = 0) then
  begin
    Log('ShopIt ' + InstalledVersion + ' is already installed; overriding in place.');
    Exit;
  end;

  if InstalledVersion = '' then
    InstalledVersion := 'a previous version';
  Log('Replacing ShopIt ' + InstalledVersion + ' with {#AppVersion}.');
end;

procedure InitializeWizard();
begin
  DataPage := CreateInputOptionPage(
    wpSelectDir,
    'Lists and settings',
    'Choose what to keep from the ShopIt already on this computer',
    'Unchecked items are removed before the new version is installed.',
    False, False);
  DataPage.Add('Keep shopping lists, pantry, history, and recipes');
  DataPage.Add('Keep settings (theme, sync code, tax, and sharing)');
  DataPage.Values[0] := True;
  DataPage.Values[1] := True;
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := False;
  if (DataPage <> nil) and (PageID = DataPage.ID) then
    Result := (not UpgradeExisting) or WizardSilent;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  InstalledVersion: String;
  SameVersion: Boolean;
begin
  Result := '';
  NeedsRestart := False;
  if not UpgradeExisting then
    Exit;

  if not WizardSilent then
    ReadDataChoiceFromPage()
  else
    ResolveSilentDataFlags();

  SameVersion := GetInstalledVersion(InstalledVersion) and
    (CompareText(InstalledVersion, '{#AppVersion}') = 0);

  if not SameVersion then
  begin
    if not UninstallPreviousVersion() then
    begin
      Result :=
        'Could not remove the installed ShopIt before upgrading. Close ShopIt and try again.';
      Exit;
    end;
  end;

  ApplyDataRetentionChoice();
end;

procedure AllowShopItOnPrivateNetworks();
var
  ResultCode: Integer;
  App: String;
begin
  App := ExpandConstant('{app}\shop_it.exe');
  Exec(
    ExpandConstant('{sys}\netsh.exe'),
    'advfirewall firewall delete rule name="ShopIt"',
    '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Exec(
    ExpandConstant('{sys}\netsh.exe'),
    'advfirewall firewall add rule name="ShopIt" dir=in action=allow program="' + App + '" enable=yes profile=private',
    '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
    AllowShopItOnPrivateNetworks();
end;

procedure RemoveShopItData();
begin
  DelTree(ExpandConstant('{userappdata}\com.nuclearfessel\ShopIt'), True, True, True);
  DelTree(ExpandConstant('{userappdata}\com.nuclearfessel\shop_it'), True, True, True);
  DelTree(ExpandConstant('{userappdata}\com.nuclearfessel'), True, True, True);
  DelTree(ExpandConstant('{localappdata}\com.nuclearfessel\ShopIt'), True, True, True);
  DelTree(ExpandConstant('{localappdata}\com.nuclearfessel\shop_it'), True, True, True);
  DelTree(ExpandConstant('{localappdata}\com.nuclearfessel'), True, True, True);
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  ResultCode: Integer;
begin
  if CurUninstallStep = usUninstall then
  begin
    Exec(
      ExpandConstant('{sys}\netsh.exe'),
      'advfirewall firewall delete rule name="ShopIt"',
      '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    if not KeepUserData() then
      RemoveShopItData();
  end;
end;

function InitializeUninstall(): Boolean;
begin
  Result := True;
  if KeepUserData() or UninstallSilent then
    Exit;
  Result := MsgBox(
    'Uninstall ShopIt and remove its lists, settings, and data folders from this computer?',
    mbConfirmation, MB_YESNO) = IDYES;
end;
