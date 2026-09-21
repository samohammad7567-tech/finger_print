; Inno Setup script for SecureAttend (Flutter Windows desktop build).
;
; Build the app first, then compile this script:
;   flutter build windows --release
;   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" scrip.iss
; The installer lands in build\installer\.

#define AppName        "SecureAttend"
#define AppVersion     "1.0.0"
#define AppPublisher   "SecureAttend"
#define AppExeName     "attendence.exe"
#define SourceDir      "build\windows\x64\runner\Release"
; Stable GUID - never change it, or upgrades install side by side instead of
; replacing the previous version.
#define AppId          "{{8F3C1B6A-2D47-4E5B-9A10-6C7E4F2D91B3}"

[Setup]
AppId={#AppId}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
UninstallDisplayName={#AppName}
UninstallDisplayIcon={app}\{#AppExeName}
OutputDir=build\installer
OutputBaseFilename={#AppName}-Setup-{#AppVersion}
SetupIconFile=windows\runner\resources\app_icon.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; The Flutter Windows bundle is x64 only.
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Writing into Program Files needs elevation.
PrivilegesRequired=admin
DisableProgramGroupPage=yes
; Offer to close a running copy instead of failing on locked files.
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
; Arabic is not part of a stock Inno Setup 6 install - included only when the
; unofficial translation has been dropped into the compiler's Languages folder.
#if FileExists(AddBackslash(CompilerPath) + "Languages\Arabic.isl")
Name: "arabic"; MessagesFile: "compiler:Languages\Arabic.isl"
#endif

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; The whole Flutter release bundle: exe, flutter_windows.dll, plugin DLLs
; (sqlite3.dll among them) and the data\ folder with assets and ICU data.
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Optional: drop vc_redist.x64.exe into redist\ and it ships with the installer.
#if FileExists("redist\vc_redist.x64.exe")
Source: "redist\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall
#endif

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
#if FileExists("redist\vc_redist.x64.exe")
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing Visual C++ runtime..."; Check: VCRedistMissing
#endif
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Anything the app writes next to itself; the database and preferences live
; under the user's AppData and are deliberately left in place.
Type: filesandordirs; Name: "{app}\logs"

[Code]
// The Flutter runner links against the MSVC runtime, which is present on most
// Windows 10/11 machines but not guaranteed on a fresh image.
function VCRedistMissing: Boolean;
var
  Installed: Cardinal;
begin
  Result := True;
  if RegQueryDWordValue(HKLM, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Installed', Installed) then
    Result := Installed = 0;
end;
