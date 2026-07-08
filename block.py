#!/usr/bin/env python3
"""Localized-update latency target (contrast with flip.py's full-screen clear).
On each keystroke it toggles only a small block near the top-left between black
and white -- a SMALL damage region, like typing a glyph, not a whole-screen
repaint. If a terminal is still slow here, its latency isn't repaint-size
specific. There is no text echo. Ctrl-C to quit."""
import sys, tty, termios

ROWS, COLS = 10, 20            # block size in cells (localized)
BG   = "\x1b[48;2;30;30;30m"   # neutral surround, drawn once
WHITE = "\x1b[48;2;255;255;255m"
BLACK = "\x1b[48;2;0;0;0m"

def block(state):
    color = WHITE if state else BLACK
    return "".join(f"\x1b[{r};1H{color}" + " " * COLS for r in range(1, ROWS + 1)) + "\x1b[0m"

def status(n):
    return f"\x1b[{ROWS+2};1H\x1b[38;2;200;200;200m block test | keys: {n} | Ctrl-C to quit \x1b[0m"

def main():
    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    tty.setraw(fd)
    state = 0
    n = 0
    try:
        sys.stdout.write(BG + "\x1b[2J" + block(state) + status(n))  # full clear ONCE
        sys.stdout.flush()
        while True:
            c = sys.stdin.read(1)
            if c == "" or c == "\x03":
                break
            state ^= 1
            n += 1
            sys.stdout.write(block(state) + status(n))  # only the block + counter redraw
            sys.stdout.flush()
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)
        sys.stdout.write("\x1b[0m\x1b[2J\x1b[H")
        sys.stdout.flush()

if __name__ == "__main__":
    main()
