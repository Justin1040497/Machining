#define AppName "FrameLean"
#ifndef AppVersion
#define AppVersion "0.0.0"
#endif
#ifndef SourceDir
#define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
#define OutputDir "..\..\build\windows\x64\installer"
#endif

[Setup]
AppId={{7E8C56BB-B9B6-4D87-A4BE-97E6F60B113A}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=FrameLean
DefaultDirName={localappdata}\Programs\FrameLean
DisableDirPage=no
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
UninstallDisplayName=FrameLean
OutputDir={#OutputDir}
OutputBaseFilename=FrameLean-v{#AppVersion}-windows-x64-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
CloseApplicationsFilter=FrameLean.exe

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\FrameLean"; Filename: "{app}\FrameLean.exe"; WorkingDir: "{app}"

[Registry]
Root: HKA; Subkey: "Software\FrameLean\FrameLean"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\FrameLean\FrameLean"; ValueType: string; ValueName: "Version"; ValueData: "{#AppVersion}"; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\FrameLean"; Flags: uninsdeletekeyifempty

[Run]
Filename: "{app}\FrameLean.exe"; Description: "启动 FrameLean"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\tools\FrameLean-Clean-Uninstall.ps1"" -RemoveUserData -RemoveRegistry -RemoveTemp -Force"; Flags: runhidden waituntilterminated; RunOnceId: "FrameLeanCleanUninstall"
