; Shop-it Windows installer. The release workflow passes /DAppVersion=0.0.1.
#ifndef AppVersion
  #define AppVersion "0.0.1"
#endif

[Setup]
AppId={{8F3A1C2E-6B47-4D91-9E5A-2C7B0D4F6A18}
AppName=ShopIt
AppVersion={#AppVersion}
AppPublisher=ShopIt
DefaultDirName={autopf}\Shop-it
DefaultGroupName=ShopIt
DisableProgramGroupPage=yes
OutputDir=..\build\installer
OutputBaseFilename=ShopIt-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
WizardStyle=modern
CloseApplications=force
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

; Flutter stores the database and SharedPreferences under AppData.
; CompanyName and ProductName come from windows/runner/Runner.rc.
; {app} is C:\Program Files\Shop-it — remove leftovers so the folder goes away.
[UninstallDelete]
Type: filesandordirs; Name: "{app}"
Type: filesandordirs; Name: "{userappdata}\com.nuclearfessel\ShopIt"
Type: filesandordirs; Name: "{userappdata}\com.nuclearfessel\shop_it"
Type: dirifempty; Name: "{userappdata}\com.nuclearfessel"
Type: filesandordirs; Name: "{localappdata}\com.nuclearfessel\ShopIt"
Type: filesandordirs; Name: "{localappdata}\com.nuclearfessel\shop_it"
Type: dirifempty; Name: "{localappdata}\com.nuclearfessel"

[Code]
function InitializeUninstall(): Boolean;
begin
  Result := True;
  if not UninstallSilent then
  begin
    Result := MsgBox(
      'Uninstall ShopIt and remove its lists, settings, and data folders from this computer?',
      mbConfirmation, MB_YESNO) = IDYES;
  end;
end;
