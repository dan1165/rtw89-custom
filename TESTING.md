# Test log

Hardware run on the machine this repo was built for. Everything below was
observed, not assumed; the two driver bugs found are listed at the end.

## Environment

| | |
|---|---|
| kernel | `7.0.0-38-generic` |
| adapter | `3625:010b` RTL8851BU (TP-Link Archer TX10UB Nano) |
| AP | `d4:01:68:24:dd:10`, ch36 / 80 MHz, `PSK SAE`, MFP-capable (0x0080) |
| modules | built from this tree, unsigned, Secure Boot off |

## Build and load

```
vermagic  7.0.0-38-generic SMP preempt mod_unload modversions   (matches)
load      insmod core → usb → 8851b → 8851bu, probe succeeds
```

## Regulatory unlock

```
radar-flagged channels   12 → 0
5260 / 5500 MHz          23 dBm → 30 dBm
txpower                  20 dBm → 30 dBm
```

## Monitor RX

```
2348 frames in 6 s on ch36, radiotap with TSFT / rate / channel / antenna
third-party RTS, CTS, BA and ACK from b8:88:80:0b:c3:a2 visible
```

## Injection

```
5 probe requests  → 1 probe response from d4:01:68:24:dd:10
repeat runs       → 1, 2, 0 responses (probe responses are best effort)
```

Requires **dedicated monitor mode**. With an associated station the monitor vif
has no channel, `iw dev mon0 set channel` returns `-EBUSY`, and mac80211 drops
every injected frame before the driver (`tx_packets` stays 0).

## Deauth

```
300 deauth frames to the phone, 877 frames from it captured
auth/assoc frames after: 0
```

The phone does **not** disconnect. The AP advertises `PSK SAE` and
MFP-capable, so the client runs PMF and ignores unprotected deauth — and the AP
ignores it too (no deauth is echoed back). Plain deauth only works against
non-PMF clients; protected deauth needs the PTK/IGTK, which the driver does not
expose to userspace.

## Bugs found and fixed

1. `regd`: `wiphy_apply_custom_regulatory()` sets `REGULATORY_CUSTOM_REG`
   itself, and that flag is mutually exclusive with `WIPHY_SELF_MANAGED` in
   `wiphy_register` → `-EINVAL`, probe failed. Switched to
   `regulatory_set_wiphy_regd()`.
2. `core`: `rtw89_core_tx_update_injection()` read
   `rtwvif_link->chanctx_idx`, which is out of range for a monitor vif, so
   `rtw89_chan_get()` read past `hal->chanctx[]` and picked the wrong band —
   a CCK rate on 5 GHz that nothing decodes. Clamped to `RTW89_CHANCTX_0`.
3. `Makefile`: `make load` used `modprobe -r` (which takes mac80211/cfg80211
   with it) followed by `insmod` (which does not resolve dependencies) → the
   reload died on unknown symbols. Dependencies are modprobed first now.

## Not tested

- 6.12 and 6.17: compile-only, no hardware.
- 6.5–6.11: unsupported.
- The Windows installer: never executed, no Windows machine.
- Protected deauth / PMF.
