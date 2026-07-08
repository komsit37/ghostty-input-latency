#!/usr/bin/env python3
"""Full-screen flip latency target. Each trigger flips the whole screen
black<->white using the terminal's erase-to-background -- a large, high-contrast
signal that's easy to detect (harness) or spot on camera (filming).

Two trigger sources:
  (default)      keystrokes typed into this terminal (raw mode, no echo)
  --fifo PATH    trigger bytes read from a named pipe, so an external driver can
                 pulse several terminals in sync (see sync_drive.py). Lets you
                 film two terminals side by side and read the lag as the gap
                 between their flips.

A counter at top-left confirms triggers are arriving. Ctrl-C to quit."""
import sys, os, tty, termios

BLACK = "\x1b[48;2;0;0;0m"
WHITE = "\x1b[48;2;255;255;255m"
CLEAR = "\x1b[2J"
HOME  = "\x1b[H"

def status(n, state):
    fg = "\x1b[38;2;0;0;0m" if state else "\x1b[38;2;255;255;255m"
    return HOME + fg + f" flip test | triggers: {n} | Ctrl-C to quit " + "\x1b[39m"

def render(n, state):
    sys.stdout.write((WHITE if state else BLACK) + CLEAR + status(n, state))
    sys.stdout.flush()

def loop(next_trigger):
    """next_trigger() returns a byte-ish on each trigger, or '' / None to stop."""
    state, n = 0, 0
    sys.stdout.write(BLACK + CLEAR + status(n, state))
    sys.stdout.flush()
    while True:
        c = next_trigger()
        if c in ("", b"", None) or c in ("\x03", b"\x03"):
            break
        state ^= 1
        n += 1
        render(n, state)

def main():
    fifo = None
    if "--fifo" in sys.argv:
        fifo = sys.argv[sys.argv.index("--fifo") + 1]

    if fifo:
        if not os.path.exists(fifo):   # create the pipe if it doesn't exist yet
            os.mkfifo(fifo)
        # draw initial frame BEFORE opening the pipe (open blocks until a writer)
        sys.stdout.write(BLACK + CLEAR + status(0, 0)); sys.stdout.flush()
        with open(fifo, "rb", buffering=0) as f:
            loop(lambda: f.read(1))
        sys.stdout.write("\x1b[0m" + CLEAR + HOME); sys.stdout.flush()
    else:
        fd = sys.stdin.fileno()
        old = termios.tcgetattr(fd)
        tty.setraw(fd)
        try:
            loop(lambda: sys.stdin.read(1))
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old)
            sys.stdout.write("\x1b[0m" + CLEAR + HOME); sys.stdout.flush()

if __name__ == "__main__":
    main()
