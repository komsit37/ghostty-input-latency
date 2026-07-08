# Terminal input-latency test: Ghostty vs Alacritty

## Summary

On an **Intel MacBook Pro 16" (2019), macOS 15.7.7**, measuring **key event → screen
update** latency, **Ghostty is ~40 ms slower than Alacritty** (p50 **~59 ms** vs
**~18 ms**). The gap is large, reproducible across runs, and matches subjective
perception that Ghostty feels laggy on this machine.

The gap is **not** explained by:
- **VSync** — Ghostty vsync off vs on: ~58 vs ~62 ms (no meaningful change).
- **Fullscreen type** — native vs non-native fullscreen: no meaningful change.
- **Repaint size** — a tiny single-block update is as slow (~59 ms) as a
  full-screen repaint (~62 ms), so it's not about damage area.

So the latency appears inherent to Ghostty's frame scheduling / present path on
this hardware, independent of workload.

> Method note: absolute numbers include a fixed harness floor (screen-capture +
> one display refresh ≈ 14 ms at 60 Hz), visible as Alacritty's ~14 ms minimum.
> Alacritty adds ~nothing above that floor; Ghostty adds ~40 ms. The **gap** is
> the signal, not the absolutes.

## Environment

| | |
|---|---|
| Machine | MacBook Pro 16" 2019 (MacBookPro16,1), Intel Core i7-9750H |
| GPU | AMD Radeon Pro 5300M / Intel UHD 630 (both Metal 3) |
| OS | macOS 15.7.7 (24G720) |
| Test display | **built-in laptop panel, 60 Hz** (1792×1120 UI scale) |
| Ghostty | 1.3.2-main-+39b3c4771 |
| Alacritty | 0.17.0 |

Both terminals used matched configs (`ghostty.conf`, `alacritty.toml`): Menlo 14,
zero padding, fullscreen on the built-in display.

## Results (300 trials each)

| ms | Ghostty full-screen | Ghostty localized | Alacritty full-screen | Alacritty localized |
|---|---|---|---|---|
| min | 40.3 | 41.5 | 13.8 | 14.6 |
| **p50** | **62.5** | **58.6** | **17.9** | **18.2** |
| p90 | 64.3 | 61.1 | 19.6 | 20.4 |
| p99 | 69.7 | 65.5 | 22.9 | 22.1 |
| stdev | 5.4 | 5.1 | 2.5 | 2.6 |

Control run — Ghostty vsync off + non-native fullscreen: p50 **57.9** (vs 62.5).

## How it works

- `flip.py` runs inside the terminal under test. On each keystroke it flips the
  whole screen black↔white (full-screen target); `block.py` toggles only a small
  block (localized target). No text echo — the flip is the signal.
- `latency` (Swift, ScreenCaptureKit) injects a synthetic key with `CGEventPost`,
  then watches the captured display for the flip and times key→flip with
  `mach_absolute_time`. It reports the distribution.
- `compare.py` prints a side-by-side p50/p90/p99 table from the CSVs.

## Reproduce

Prereqs: macOS, Xcode command-line tools (`swiftc`), Ghostty + Alacritty in
`/Applications`.

```sh
# build
swiftc latency.swift -o latency \
  -framework ScreenCaptureKit -framework CoreMedia \
  -framework CoreVideo -framework CoreGraphics -framework Foundation

# one-time: grant the terminal you run ./latency FROM both
#   Accessibility  +  Screen Recording   (System Settings ▸ Privacy & Security)

# measure ghostty (full-screen target)
./run.sh ghostty flip.py            # opens fullscreen on the test display
./latency --trials 300 --display <N> --csv ghostty.csv   # click the flip window during the 5s countdown

# measure alacritty
./run.sh alacritty flip.py
./latency --trials 300 --display <N> --csv alacritty.csv

# compare
./compare.py ghostty.csv alacritty.csv
```

Find the right `--display N` with `./latency --watch --display N` (type in the
flip window; you should see "change detected"). Swap `flip.py`→`block.py` for the
localized-update test.

## Filming it (optional, ground truth)

A screen recording can't show input lag. To see it directly, film in slow motion
— see `FILMING.md`. The side-by-side method drives both terminals from one
synchronized trigger (`sync_drive.py` + `flip.py --fifo`) so you can film them
next to each other and read the lag as the frame gap between their two flips.

## Limitations

- Measures the render/present path (key event → framebuffer), not USB/keyboard
  hardware. Absolute values carry the ~14 ms harness floor; treat as relative.
- Frame-arrival timing, so resolution ≈ one display frame (16.7 ms at 60 Hz).
- Single machine (Intel Mac). Results may differ on Apple Silicon.
