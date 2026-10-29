# Windows side

Windows cannot load the Linux `.ko`. The package that ships with the stick is a
separate Realtek driver (`.exe` installer → `.sys` + `.inf` + firmware), so
"unlock" here means something different: there is no source to patch, only the
registry values the driver reads at start.

## One-click driver install

`rtw89-win-driver-setup-<ver>.exe` (built by CI) is an Inno Setup installer:
run it, click through, done. It

1. installs the vendor Wi-Fi driver with `pnputil` — Realtek `5001.19.113.1`,
   taken from TP-Link's own package for this exact model,
2. backs up the current knob values, applies the relaxed ones, restarts the
   adapter,
3. schedules a logon task so a driver update does not silently undo the knobs.

Uninstalling restores the knobs and removes the task. The driver stays in the
driver store, exactly as it would after uninstalling any vendor package — use
`-RemoveDriver` if you want it gone.

x64 only (Win10 x64 / Win11). Bluetooth is **not** included: TP-Link's package
also carries a BT driver, this one ships the Wi-Fi half only.

## What the script does

`rtw89-win-knobs.ps1` finds the adapter's driver key and dumps:

- every advanced property the driver exposes, with its allowed values,
- the regulatory-ish values already in the driver key,
- the matching lines of the installed INF.

With `-Apply` it sets only keywords that actually exist (`CountryRegion`,
`RegDomain`, `TxPower`, `bDFSEnable`), then restarts the adapter. It cannot
invent a knob the driver ignores, so a wrong guess is a no-op rather than a
broken install.

```powershell
powershell -ExecutionPolicy Bypass -File .\rtw89-win-knobs.ps1          # dump
powershell -ExecutionPolicy Bypass -File .\rtw89-win-knobs.ps1 -Apply   # set
powershell -ExecutionPolicy Bypass -File .\rtw89-win-knobs.ps1 -Revert  # undo
powershell -ExecutionPolicy Bypass -File .\rtw89-win-knobs.ps1 -RemoveDriver
```

Run elevated. Paste the dump back if a value needs adjusting — the keyword
names and allowed values differ between Realtek driver generations, and the
dump is the only reliable source for them.

## What stays the same as Linux

The limits that are not in the driver are not here either: channels the chip
cannot tune, firmware radar detection, and the PA ceiling (~20 dBm conducted).
Registry values only change what the driver is willing to ask for.

## Where the driver files come from

`driver/x64/` is extracted from TP-Link's published package
(`Archer_TX10UB_Nano(US)_V1_5001.19.113.1_Win10_Win11.zip`, 2025-10-21) with
`innoextract`, unmodified. Redistribution is under TP-Link's/Realtek's driver
terms; the INF and CAT are theirs, not ours. To refresh it, download that zip,
extract `app/Driver/Win10X64/*` and drop it in `driver/x64/`.
