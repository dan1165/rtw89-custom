# Windows side

Windows cannot load the Linux `.ko`. The package that ships with the stick is a
separate Realtek driver (`.exe` installer → `.sys` + `.inf` + firmware), so
"unlock" here means something different: there is no source to patch, only the
registry values the driver reads at start.

## One-click

`rtw89-win-knobs-setup-<ver>.exe` (built by CI) is an Inno Setup installer: run
it, click through, done. It backs up the current values, applies the relaxed
ones, restarts the adapter, and schedules a logon task so a driver update does
not silently undo it. Uninstalling restores the backup and removes the task.

It is **not** a driver installer. Realtek's package still has to be installed
first — this only changes what that driver is willing to ask for. If the stick
is not plugged in, the installer says so and leaves the logon task to do the
work later.

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
