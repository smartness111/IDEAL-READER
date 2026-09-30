; Inno Setup script for Ideal Reader.
; Turns the folder produced by "flutter build windows" into a single
; double-click installer: IdealReaderSetup.exe
;
; One-time free setup: download and install Inno Setup from
; https://jrsoftware.org/isdl.php (the plain "innosetup-x.x.x.exe", not
; the "-unicode" one; it already supports Unicode). Then open this file
; in "Inno Setup Compiler" and press Compile (Ctrl+F9).
;
; This assumes the normal project layout: this file lives in
; ideal_reader\installer\ideal_reader.iss, and the Flutter build output is
; at ideal_reader\build\windows\x64\runner\Release\ (adjust SourceDir below
; if you placed things differently).

#define MyAppName "Ideal Reader"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Ideal Path Impactful Development Initiative (IPIDI)"
#define MyAppExeName "ideal_reader.exe"
#define SourceDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{8F1B1E9E-6B0B-4B7B-9B7D-5B9A9A9F2E10}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; Installs for the current user by default, so it does NOT need an
; administrator prompt on most PCs. Change to "admin" if you'd rather
; install once for every user of a shared PC.
PrivilegesRequired=lowest
OutputDir=Output
OutputBaseFilename=IdealReaderSetup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
; Uses the app's own icon (the one Flutter generated) for the installer.
; This file's path is fixed by the standard Flutter project layout; if
; Inno Setup can't find it, delete this line and the one below it that
; matches — the installer still works fine with Inno Setup's default icon.
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Files]
; Copies everything Flutter produced (the .exe, its .dll files, and the
; data folder with the app's Dart code and assets) into the install folder.
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName} now"; Flags: nowait postinstall skipifsilent
