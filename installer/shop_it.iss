; Shop-it Windows installer. The release workflow passes /DAppVersion=0.0.1.
#ifndef AppVersion
#define AppVersion "0.0.1"
#endif

[Setup]
AppId={{8F3A1C2E-6B47-4D91-9E5A-2C7B0D4F6A18}
AppName=Shop-it
AppVersion={#AppVersion}
AppPublisher=Shop-it
DefaultDirName={autopf}\Shop-it
DefaultGroupName=Shop-it
DisableProgramGroupPage=yes
OutputDir=..\build\installer
OutputBaseFilename=Shop-it-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
WizardStyle=modern
UninstallDisplayIcon={app}\shop_it.exe

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Shop-it"; Filename: "{app}\shop_it.exe"
Name: "{autodesktop}\Shop-it"; Filename: "{app}\shop_it.exe"

[Run]
Filename: "{app}\shop_it.exe"; Description: "Launch Shop-it"; Flags: nowait postinstall skipifsilent
