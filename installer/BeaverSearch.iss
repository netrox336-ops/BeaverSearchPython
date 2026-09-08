#define MyAppName "BeaverSearch"
#define MyAppVersion "0.1.0"
#define MyAppPublisher "BeaverSearch"
#define MyAppExeName "BeaverSearch.exe"

[Setup]
AppId={{7B7C7C46-2DF1-4F2B-8D7A-BE7A4C8A1201}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\BeaverSearch
DefaultGroupName=BeaverSearch
DisableProgramGroupPage=yes
OutputDir=dist\installer
OutputBaseFilename=BeaverSearch-Setup-{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}
PrivilegesRequired=admin

[Files]
Source: "..\dist\BeaverSearch\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\BeaverSearch"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\BeaverSearch"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Создать ярлык на рабочем столе"; GroupDescription: "Дополнительно:"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Запустить BeaverSearch"; Flags: nowait postinstall skipifsilent
