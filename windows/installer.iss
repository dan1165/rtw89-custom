; Inno Setup script for the Windows driver installer.
; Built in CI with: iscc /DMyVersion=<ver> installer.iss
;
; Ships the vendor Wi-Fi driver (Realtek 5001.19.113.1, from TP-Link's package
; for this exact model) plus the knob script. The driver is installed with
; pnputil, the knobs are applied afterwards.

#ifndef MyVersion
#define MyVersion "0.0.0"
#endif

[Setup]
AppId={{9F1C2B44-6E8A-4C31-9A57-2D3F1B0C7E55}
AppName=rtw89 unlock driver (Archer TX10UB Nano)
AppVersion={#MyVersion}
AppPublisher=dan1165
AppPublisherURL=https://github.com/dan1165/rtw89-custom
DefaultDirName={autopf}\rtw89-win-knobs
DisableProgramGroupPage=yes
PrivilegesRequired=admin
OutputDir=..\dist
OutputBaseFilename=rtw89-win-driver-setup-{#MyVersion}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
UninstallDisplayName=rtw89 unlock driver
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Files]
Source: "driver\x64\*"; DestDir: "{app}\driver\x64"; Flags: ignoreversion
Source: "rtw89-win-knobs.ps1"; DestDir: "{app}"; Flags: ignoreversion

[Run]
Filename: "{sys}\pnputil.exe"; \
  Parameters: "/add-driver ""{app}\driver\x64\netrtwlanu6.inf"" /install"; \
  Flags: runhidden waituntilterminated; \
  StatusMsg: "Installing the Wi-Fi driver..."
Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\rtw89-win-knobs.ps1"" -Apply -Quiet"; \
  Flags: runhidden waituntilterminated; \
  StatusMsg: "Applying driver knobs..."

[UninstallRun]
; knobs first: they live in the driver key. The driver itself stays in the
; driver store, same as any vendor package.
Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\rtw89-win-knobs.ps1"" -Revert -Quiet"; \
  Flags: runhidden waituntilterminated; \
  RunOnceId: "revert"

[Messages]
FinishedLabel=Done. The Wi-Fi driver is installed and the adapter was restarted with the relaxed settings.%n%nIf the stick is not plugged in yet, the knobs are applied automatically at next logon.
