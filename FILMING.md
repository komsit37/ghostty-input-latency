# Filming the input lag (ground-truth, high-speed camera)

A screen recording can't show input lag (no visible reference for the keypress).
Film in slow motion instead. Two methods below — the **side-by-side** one is
easier and needs no keyboard in shot.

---

## Method 1 (recommended): side-by-side, synchronized trigger

Drive both terminals from one trigger so they flip at the same instant. Film them
next to each other; the **gap between their two flips is the latency difference**.

You can't send one real keystroke to two apps (macOS delivers it only to the
focused window), so we feed both a shared trigger pipe. Note: this exercises the
terminals' **output->render** path, bypassing keyboard-input handling — but that's
where ghostty's ~40 ms lives, so the gap still shows.

Setup:
1. Put a ghostty and an alacritty window **side by side**, same size, same display
   (windowed, not fullscreen, so both fit in one camera frame). Use the matched
   configs: `--config-file` as in run.sh.
2. In ghostty:    `./flip.py --fifo /tmp/s1`
   In alacritty:  `./flip.py --fifo /tmp/s2`   (each shows a solid black screen)
3. `./sync_drive.py /tmp/s1 /tmp/s2 --interval 1.5 --pulses 20`

Film both windows in **slo-mo 240 fps** (each frame = 4.17 ms). On each pulse both
screens flip; scrub frame-by-frame and count frames between alacritty's flip and
ghostty's flip. `frames x 4.17 ms` = the gap. Average over several pulses.

Expectation: ghostty lags alacritty by ~8–10 frames (~35–45 ms).

---

## Method 2: single terminal, film the keyboard too

Gives the *absolute* end-to-end latency of one terminal (includes key travel + USB).
Count frames from finger-contact to the screen changing.

## Setup
- Target: run `./run.sh <term> flip.py` **fullscreen on the built-in display**
  (display 1 here). The whole screen flashes black↔white per keystroke — easy to
  spot the exact frame it changes.
- Camera: a second phone in **slo-mo 240 fps** (iPhone: Camera ▸ Slo-mo). Each
  frame = 1000/240 ≈ **4.17 ms**.
- Frame the shot so you see **both the pressed key and the laptop screen** at once.
  A MacBook is ideal — built-in keyboard sits right under the built-in display.
- Lock the phone on something steady, same distance/angle for both terminals.
- Pick one key (e.g. **space**) and press it **deliberately, once every ~1–2 s**,
  ~10 times. Press crisply so the contact frame is clear.

## Measure
Scrub the slo-mo frame by frame:
1. Frame A = key bottoms out (finger/keycap fully down).
2. Frame B = screen flips.
3. Latency = (B − A) × 4.17 ms.
Do this for ~5 presses per terminal and average (drop the odd outlier).

Quick math: `python3 -c "print(f'{(B-A)*1000/240:.1f} ms')"` (fill in A, B).

## Fair A/B
- Same display, same fixed refresh (120 Hz), same fullscreen, same phone position.
- Film ghostty, then `Cmd-Q` and film alacritty identically.
- Expectation from the harness: alacritty a couple frames (~1–2), ghostty ~10
  frames (~40 ms) more. If the camera shows a similar gap, it's fully confirmed
  in the real world — independent of the software harness.

## Note
The camera's absolute number is the *true* end-to-end latency (includes keyboard
travel + USB + render + panel). The harness measured only the render portion and
added its own ~14 ms floor, so camera absolutes will differ from harness absolutes
— but the **ghostty − alacritty gap** should agree.
