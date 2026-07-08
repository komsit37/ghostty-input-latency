#!/usr/bin/env python3
"""Pulse two (or more) flip.py --fifo instances in sync, so terminals flip at the
same instant. Film them side by side: the gap between their flips is the latency
difference.

Usage:
  1. mkfifo /tmp/s1 /tmp/s2            (this script makes them if missing)
  2. in terminal A:  ./flip.py --fifo /tmp/s1
     in terminal B:  ./flip.py --fifo /tmp/s2
  3. ./sync_drive.py /tmp/s1 /tmp/s2   [--interval 1.5] [--pulses 20]

Each pulse writes one byte to every pipe back-to-back (microseconds apart, i.e.
effectively simultaneous vs the tens-of-ms we're measuring)."""
import sys, os, time

def main():
    args = sys.argv[1:]
    interval = 1.5
    pulses = 20
    paths = []
    i = 0
    while i < len(args):
        a = args[i]
        # accept both "--flag value" and "--flag=value"
        if "=" in a and a.startswith("--"):
            key, val = a.split("=", 1)
        elif a.startswith("--"):
            key, val = a, (args[i+1] if i+1 < len(args) else "")
            i += 1
        else:
            paths.append(a); i += 1; continue
        if key == "--interval": interval = float(val)
        elif key == "--pulses": pulses = int(val)
        else: print(f"unknown option: {key}"); sys.exit(1)
        i += 1
    if len(paths) < 2:
        print("usage: sync_drive.py FIFO1 FIFO2 [...] [--interval S] [--pulses N]")
        sys.exit(1)

    for p in paths:
        if not os.path.exists(p):
            os.mkfifo(p)
    print(f"opening {len(paths)} pipes (start the flip.py readers now if you haven't)...")
    # opening for write blocks until each pipe has a reader -> natural rendezvous
    fds = [os.open(p, os.O_WRONLY) for p in paths]
    print(f"connected. pulsing every {interval}s, {pulses} times. Ctrl-C to stop.\n")
    try:
        for k in range(1, pulses + 1):
            for fd in fds:              # back-to-back writes = effectively simultaneous
                os.write(fd, b" ")
            print(f"  pulse {k}")
            time.sleep(interval)
    except KeyboardInterrupt:
        pass
    finally:
        for fd in fds:
            os.close(fd)

if __name__ == "__main__":
    main()
