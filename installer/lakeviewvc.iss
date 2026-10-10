; ---------------------------------------------------------------------------
; Inno Setup script for LakeviewVC.
;
; Build with:  ISCC.exe /DAppVersion=0.2.0 lakeviewvc.iss
; Expects the compiled exe at ..\dist\LakeviewVC.exe.
;
; Per-machine install. Ships the compiled exe (UI is embedded as resources),
; the icon, the WebView2 loader and the OCR engine + dictionaries. OCR models
; download at runtime into %APPDATA%.
; ---------------------------------------------------------------------------

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

#define AppName "LakeviewVC"
#define AppPublisher "Arjun Patel"
#define AppExeName "LakeviewVC.exe"
#define SourceRoot ".."

[Setup]
AppId={{8F3B2E1C-6A4D-4E7B-9C2F-1D5A7E3B9F10}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\icon.ico
UninstallDisplayName={#AppName}
OutputDir=Output
OutputBaseFilename=LakeviewVC-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
WizardSmallImageFile=wizard-small.png
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
SetupIconFile={#SourceRoot}\icon.ico

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Application (UI is embedded in the exe as resources)
Source: "{#SourceRoot}\dist\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceRoot}\icon.ico"; DestDir: "{app}"; Flags: ignoreversion

; WebView2 loader (fallback; the exe embeds its own copy)
Source: "{#SourceRoot}\vendor\webview\64bit\WebView2Loader.dll"; DestDir: "{app}"; Flags: ignoreversion

; OCR engine + dictionaries
Source: "{#SourceRoot}\engines\RapidOCR-json\RapidOCR-json.exe"; DestDir: "{app}\engines\RapidOCR-json"; Flags: ignoreversion
Source: "{#SourceRoot}\engines\RapidOCR-json\LICENSE"; DestDir: "{app}\engines\RapidOCR-json"; Flags: ignoreversion
Source: "{#SourceRoot}\engines\RapidOCR-json\dicts\*"; DestDir: "{app}\engines\RapidOCR-json\dicts"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
