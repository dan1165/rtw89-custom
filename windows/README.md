# Windows side

Windows cannot load the Linux `.ko`. The package that ships with the stick is a
separate Realtek driver (`.exe` installer → `.sys` + `.inf` + firmware), so
"unlock" here means something different: there is no source to patch, only the
registry values the driver reads at start.

## What this script does

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
```

Run elevated. Paste the dump back if a value needs adjusting — the keyword
names and allowed values differ between Realtek driver generations, and the
dump is the only reliable source for them.

## What stays the same as Linux

The limits that are not in the driver are not here either: channels the chip
cannot tune, firmware radar detection, and the PA ceiling (~20 dBm conducted).
Registry values only change what the driver is willing to ask for.

## Patching the installer instead

Registry edits are per-machine and lost on driver reinstall. The durable version
is to patch the INF inside the `.exe` (add a permissive `[Registry]`/`AddReg`
block, repack) so a fresh install comes up unlocked. That needs the installer
file itself; drop it in `~/Downloads` and it can be extracted and patched.
