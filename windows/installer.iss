; Inno Setup script for the Windows knob installer.
; Built in CI with: iscc /DMyVersion=<ver> installer.iss

#define MyVersion "0.0.0"

[Setup]
AppId={{9F1C2B44-6E8A-4C31-9A57-2D3F1B0C7E55}
AppName=rtw89 unlock knobs
AppVersion={#MyVersion}
AppPublisher=dan1165
AppPublisherURL=https://github.com/dan1165/rtw89-custom
DefaultDirName={autopf}\rtw89-win-knobs
DisableProgramGroupPage=yes
PrivilegesRequired=admin
OutputDir=..\dist
OutputBaseFilename=rtw89-win-knobs-setup-{#MyVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayName=rtw89 unlock knobs

[Files]
Source: "rtw89-win-knobs.ps1"; DestDir: "{app}"; Flags: ignoreversion

[Run]
Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\rtw89-win-knobs.ps1"" -Apply -Quiet"; \
  Flags: runhidden waituntilterminated; \
  StatusMsg: "Applying driver knobs..."

[UninstallRun]
Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\rtw89-win-knobs.ps1"" -Revert -Quiet"; \
  Flags: runhidden waituntilterminated; \
  RunOnceId: "revert"

[Messages]
FinishedLabel=Done. The adapter was restarted with the relaxed settings.%n%nIf the stick was not plugged in yet, it is applied automatically at next logon.
