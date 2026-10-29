# rtw89-custom — out-of-tree driver for the RTL8851BU USB adapter

Built for the stick on this machine (`3625:010b`, TP-Link Archer TX10UB Nano),
from the upstream `rtw89` tree at tag `v7.0-rc1`, as four loadable modules.

This was **built, not run**. Nothing was loaded, replaced or unloaded.

## What "full features" means here

The driver has no vendor lock-outs to remove — it is mainline GPL code. What this
build changes relative to the distro module is that every *optional* code path is
compiled in instead of depending on the distro's config:

| Feature | How it is enabled | Notes |
|---|---|---|
| Monitor RX + radiotap (HT/VHT/HE/EHT) | default | `WANT_MONITOR_VIF`, `RTW89_RADIOTAP_ROOM` |
| Frame injection (monitor TX) | default | `IEEE80211_TX_CTL_INJECTED` path in `core.c` |
| AP / AP-VLAN / P2P-GO / P2P-client | default | see `iw phy phy0 info` |
| debugfs (`read_reg`, `write_reg`, `send_h2c`, `fw_crash`, `diag_*`) | `-DCONFIG_RTW89_DEBUGFS` | `/sys/kernel/debug/rtw89/` |
| dynamic debug messages | `-DCONFIG_RTW89_DEBUGMSG` | `rtw89_debug=0x...` module param |
| WoW / suspend-resume | `wow.o` | kernel has `CONFIG_PM=y` |
| 8851B + 8851BU only | `Kbuild` | other chips trimmed from the build |
| regulatory unlock + TX power boost | `unlock_regd`, `txpwr_boost` params | opt-in, see below |

## Regulatory unlock (opt-in, off by default)

Two module parameters. Both are read during setup, so they are load-time only
(`0444`); changing them needs a reload.

| param | effect |
|---|---|
| `unlock_regd=1` | applies a custom `"99"` world domain before registration: clears `RADAR`, `NO_IR`, `INDOOR_ONLY`, `NO_HT40`, `NO_80MHZ`, `NO_160MHZ`, `NO_320MHZ` and the 6 GHz client flags on every channel the chip registered, and forces the FCC TX power rule set. `REGULATORY_STRICT_REG` + no reg notifier, so neither `iw reg set` nor a country IE can tighten it again. |
| `txpwr_boost=<dB>` | added to every TX power limit at the single choke point (`rtw89_phy_read_txpwr_limit` and its RU twin), clamped to the 6-bit MAC field. With `unlock_regd` set, SAR and 6 GHz TPE clamping are skipped as well. |

What is still **not** unlocked, on purpose:

- channels the chip itself cannot tune stay `DISABLED` — the domain only clears
  restriction flags, it cannot invent channels;
- firmware radar detection still runs. Clearing `RADAR` removes the CAC wait, so
  an AP starts on a DFS channel immediately and may be interrupted by a radar
  event instead of being kept off the channel;
- the 30 dBm in the rules is a cfg80211 ceiling. The 8851BU PA does roughly
  20 dBm conducted, so a large `txpwr_boost` mostly buys distortion, not range.

Legality is now yours: with `unlock_regd=1` you may transmit outside your
country's allocation.

## Build

```sh
make            # -> src/*.ko
make clean
```

## Provenance

| | |
|---|---|
| source | `torvalds/linux` tag `v7.0-rc1`, `drivers/net/wireless/realtek/rtw89` |
| target kernel | `7.0.0-38-generic` (`/lib/modules/$(uname -r)/build`) |
| compiler | gcc 15.2.0 (kernel was built with the same version, pahole differs) |
| `vermagic` | `7.0.0-38-generic SMP preempt mod_unload modversions` |
| signing | unsigned; Secure Boot is disabled on this machine |
| modules | `rtw89_core`, `rtw89_usb`, `rtw89_8851b`, `rtw89_8851bu` |

Module names are identical to the in-tree ones, so the in-tree modules must be
unloaded before these can be inserted.

## Loading (documented, not executed)

```sh
sudo modprobe -r rtw89_8851bu rtw89_8851b rtw89_usb rtw89_core
sudo insmod src/rtw89_core.ko unlock_regd=1 txpwr_boost=3   # drop the params to stay legal
sudo insmod src/rtw89_usb.ko
sudo insmod src/rtw89_8851b.ko
sudo insmod src/rtw89_8851bu.ko
dmesg | tail -30
```

Unload in reverse order. `modprobe -r` after that points at the in-tree copies
again, which is the normal way back.

## Verifying it is the custom build

```sh
modinfo src/rtw89_core.ko | grep -E 'srcversion|vermagic'
cat /sys/module/rtw89_core/srcversion        # must match
```

Then the two things this tree was built for:

```sh
sudo ./../wmon.sh start          # monitor mode (../wmon.sh)
sudo ./../inject_test.py         # injection: expects a probe response
```

## Status

Compiled clean (only the harmless "compiler/pahole differs from the kernel
build" notes). Not runtime-tested: not loaded, no hardware validation.
