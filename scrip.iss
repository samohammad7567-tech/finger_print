; ============================================================================
;  SecureAttend — Inno Setup installer script
;  نظام إدارة الحضور والانصراف — سكربت المُثبِّت
;
;  Use build_installer.ps1 — it builds the app, locates the Visual C++ runtime
;  folder instead of relying on the fallback path below, and works around
;  Controlled Folder Access:
;      powershell -ExecutionPolicy Bypass -File build_installer.ps1
;
;  Compiling by hand works too, but while this project lives under Desktop,
;  Defender's Controlled Folder Access blocks the icon resource update and ISCC
;  stops with "EndUpdateResource failed ... (110)". Send the output elsewhere:
;      flutter build windows --release
;      "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" /O%TEMP%\out scrip.iss
;
;  Requires Inno Setup 6.3 or later (uses ArchitecturesAllowed=x64compatible).
; ============================================================================

; ---------------------------------------------------------------------------
;  Edit these — everything else is derived.
; ---------------------------------------------------------------------------
#define MyAppName        "SecureAttend"

; TODO: replace with the real company/legal name before shipping to staff.
; This is what shows in the wizard and in Add/Remove Programs.
; NOTE: do NOT change CompanyName or ProductName in windows/runner/Runner.rc to
; match it — path_provider derives %APPDATA%\com.example\attendence from those
; two values, so editing them would orphan every existing guardsync.db.
#define MyAppPublisher   "GuardSync"

; The Flutter runner target: BINARY_NAME in windows/CMakeLists.txt.
#define MyAppExeName     "attendence.exe"
#define MyAppDirName     "SecureAttend"

; Where the app keeps its SQLite catalogue — getApplicationSupportDirectory()
; resolves to %APPDATA%\<CompanyName>\<ProductName> from the exe's version info.
#define MyAppDataDir     "com.example\attendence"
#define MyAppDbName      "guardsync.db"

; Never reuse this GUID for a different product. Keep it stable across
; versions so upgrades replace the previous install instead of stacking up.
; The doubled leading brace is Inno's escape — AppId must expand to a literal
; {GUID}, not to a constant reference.
#define MyAppId          "{{C7C1F9CE-6DDF-4A5F-9518-93E04252C0DA}"

; ---------------------------------------------------------------------------
;  Paths. ISCC is expected to run from the project root.
; ---------------------------------------------------------------------------
#define ProjectRoot  SourcePath
#define ReleaseDir   ProjectRoot + "build\windows\x64\runner\Release"

; The VC++ runtime DLLs the release binaries import are shipped app-local
; rather than through vc_redist.x64.exe, so the installer needs no admin
; rights. build_installer.ps1 overrides this with /DVCRedistDir=... after
; locating the newest toolset; the default below is the fallback.
#ifndef VCRedistDir
  #define VCRedistDir "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Redist\MSVC\14.51.36231\x64\Microsoft.VC145.CRT"
#endif

; ---------------------------------------------------------------------------
;  Fail at compile time with a useful message rather than shipping a broken
;  installer that is missing the app or the runtime.
; ---------------------------------------------------------------------------
#if !FileExists(ReleaseDir + "\" + MyAppExeName)
  #error Release build not found. Run "flutter build windows --release" first.
#endif

#if !FileExists(VCRedistDir + "\msvcp140.dll")
  #error VCRedistDir does not contain msvcp140.dll. Point it at a Microsoft.VC*.CRT\x64 folder, or run build_installer.ps1.
#endif

; ---------------------------------------------------------------------------
;  Version, read straight out of the built exe so pubspec.yaml stays the single
;  source of truth. Flutter writes "1.0.0+1" into ProductVersion; the build
;  number after the "+" is dropped for display and kept in VersionInfoVersion
;  as the fourth field ("1.0.0.1").
; ---------------------------------------------------------------------------
#define RawVersion   GetStringFileInfo(ReleaseDir + "\" + MyAppExeName, PRODUCT_VERSION)
#if Pos("+", RawVersion) > 0
  #define MyAppVersion Copy(RawVersion, 1, Pos("+", RawVersion) - 1)
#else
  #define MyAppVersion RawVersion
#endif
#define MyAppVersionFull GetVersionNumbersString(ReleaseDir + "\" + MyAppExeName)

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppCopyright=Copyright (C) 2026 {#MyAppPublisher}
VersionInfoVersion={#MyAppVersionFull}
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersionFull}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} Setup

; Per-user install: no UAC prompt, no admin account needed on staff machines.
; The catalogue already lives per-user under %APPDATA%, so a machine-wide
; install would buy nothing. {autopf} resolves to %LOCALAPPDATA%\Programs here.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=
DefaultDirName={autopf}\{#MyAppDirName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
AllowNoIcons=yes

; Flutter Windows desktop targets 64-bit Windows 10 1809 and later.
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763

UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName} {#MyAppVersion}
SetupIconFile={#ProjectRoot}windows\runner\resources\app_icon.ico

OutputDir={#ProjectRoot}build\installer
OutputBaseFilename={#MyAppDirName}-{#MyAppVersion}-Setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ShowLanguageDialog=auto

; Uses the Restart Manager to offer closing a running copy during an upgrade,
; instead of failing on a locked attendence.exe.
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "ar"; MessagesFile: "compiler:Languages\Arabic.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
ar.AutoStartTask=تشغيل {#MyAppName} تلقائيًا عند بدء تشغيل Windows
ar.AutoStartGroup=خيارات التشغيل:
ar.RemoveDataPrompt=هل تريد حذف قاعدة بيانات الحضور أيضًا؟%n%n%1%n%nاختر «لا» للاحتفاظ بسجلات الحضور والموظفين لإعادة التثبيت لاحقًا.
ar.NewerVersionInstalled=يوجد إصدار أحدث من {#MyAppName} مُثبَّت بالفعل على هذا الجهاز. أزِل الإصدار الحالي أولًا قبل تثبيت هذا الإصدار.
en.AutoStartTask=Start {#MyAppName} automatically when Windows starts
en.AutoStartGroup=Startup options:
en.RemoveDataPrompt=Delete the attendance database as well?%n%n%1%n%nChoose No to keep the attendance and employee records for a later reinstall.
en.NewerVersionInstalled=A newer version of {#MyAppName} is already installed on this computer. Uninstall it first before installing this version.

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
; The device cubit arms the terminal's auto-sync timer at launch, so a machine
; that is meant to keep pulling punches wants the app running after a reboot.
Name: "autostart"; Description: "{cm:AutoStartTask}"; GroupDescription: "{cm:AutoStartGroup}"; Flags: unchecked

[Files]
; --- Application ---------------------------------------------------------
Source: "{#ReleaseDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
; flutter_windows.dll, file_selector_windows_plugin.dll and the sqlite3.dll
; that sqflite_common_ffi opens the catalogue through.
Source: "{#ReleaseDir}\*.dll";           DestDir: "{app}"; Flags: ignoreversion
; app.so (the AOT snapshot), icudtl.dat and flutter_assets — including the
; ar/en translation JSON the UI reads every string from.
Source: "{#ReleaseDir}\data\*";          DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

; --- Visual C++ runtime, deployed app-local ------------------------------
; attendence.exe and file_selector_windows_plugin.dll import msvcp140.dll,
; vcruntime140.dll and vcruntime140_1.dll directly; their api-ms-win-crt
; imports resolve against the UCRT that ships with Windows 10, so no
; vc_redist.x64.exe run is needed. The msvcp140_* satellites are what
; msvcp140.dll itself may forward to, hence skipifsourcedoesntexist.
Source: "{#VCRedistDir}\msvcp140.dll";               DestDir: "{app}"; Flags: ignoreversion
Source: "{#VCRedistDir}\msvcp140_1.dll";             DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#VCRedistDir}\msvcp140_2.dll";             DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#VCRedistDir}\msvcp140_atomic_wait.dll";   DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#VCRedistDir}\msvcp140_codecvt_ids.dll";   DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#VCRedistDir}\vcruntime140.dll";           DestDir: "{app}"; Flags: ignoreversion
Source: "{#VCRedistDir}\vcruntime140_1.dll";         DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}";       Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Comment: "{#MyAppName} {#MyAppVersion}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Comment: "{#MyAppName} {#MyAppVersion}"; Tasks: desktopicon

[Registry]
; Opt-in autostart. Per-user, so it needs no admin rights, and the value goes
; away with the app rather than pointing at a deleted exe after an uninstall.
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "{#MyAppDirName}"; ValueData: """{app}\{#MyAppExeName}"""; Flags: uninsdeletevalue; Tasks: autostart
; Clears a stale autostart value when the task is left unchecked on an upgrade.
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: none; ValueName: "{#MyAppDirName}"; Flags: deletevalue; Tasks: not autostart

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Removes the program folder only. The SQLite catalogue under
; %APPDATA%\com.example\attendence is left in place unless the person
; uninstalling explicitly asks for it — see CurUninstallStepChanged.
Type: filesandordirs; Name: "{app}"

[Code]
{ MB_DEFBUTTON2 — keeping data is the safe answer, so No is the default button. }
const
  MsgBoxDefaultSecondButton = $100;

{ Blocks installing an older build over a newer one. Downgrading would leave a
  guardsync.db already migrated to a higher schema version in front of code
  that only knows the older one, and AppDatabase has no downgrade path. }
function InitializeSetup(): Boolean;
var
  Installed: string;
  InstalledVer, ThisVer: Int64;
begin
  Result := True;
  if RegQueryStringValue(HKCU,
        'Software\Microsoft\Windows\CurrentVersion\Uninstall\{#MyAppId}_is1',
        'DisplayVersion', Installed) then
  begin
    if StrToVersion(Installed, InstalledVer) and
       StrToVersion('{#MyAppVersion}', ThisVer) and
       (ComparePackedVersion(InstalledVer, ThisVer) > 0) then
    begin
      MsgBox(CustomMessage('NewerVersionInstalled'), mbError, MB_OK);
      Result := False;
    end;
  end;
end;

{ Offers to take the catalogue with it, defaulting to keeping it: on a staff
  machine with no server, that file is the only copy of the attendance and
  employee records. }
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  DataDir: string;
begin
  if CurUninstallStep <> usPostUninstall then
    Exit;

  DataDir := ExpandConstant('{userappdata}\{#MyAppDataDir}');
  if not FileExists(DataDir + '\{#MyAppDbName}') then
    Exit;

  if MsgBox(FmtMessage(CustomMessage('RemoveDataPrompt'), [DataDir]),
            mbConfirmation, MB_YESNO or MsgBoxDefaultSecondButton) = IDYES then
    DelTree(DataDir, True, True, True);
end;
