# Drafts for reporting to ghostty-org/ghostty

> Not yet posted. Before posting: (1) re-run on a **stable** Ghostty release and
> update the version line — current data is on a `-main-` dev build; (2) attach the
> slow-motion video. Ghostty requires reporters to be **vouched** and routes bug
> reports through Discussions → **Issue Triage**, not raw Issues.

---

## Draft 1 — Vouch Request discussion

**Category:** Vouch Request · **Title:** `Vouch request — input-latency benchmark on Intel Mac`

```markdown
Hi! I'd like to file an Issue Triage report and need to be vouched first.

Who I am: a Ghostty user on an Intel MacBook Pro. I noticed Ghostty feels laggier
than other terminals while typing, so rather than report a vague "feels slow" I
built a small deterministic harness to measure key→screen latency and compared
Ghostty against Alacritty under controlled conditions.

What I want to report: on my machine Ghostty shows a consistent ~40ms higher
per-keystroke latency than Alacritty, reproducible across runs, and not explained
by vsync, fullscreen mode, or repaint size. Full method, scripts, and result data
are here: https://github.com/komsit37/ghostty-input-latency

I'll include the harness, raw numbers, and a slow-motion video in the report.
Happy to run any additional tests you'd find useful.
```

---

## Draft 2 — Issue Triage discussion

**Category:** Issue Triage · **Title:** `Consistent ~40ms higher input latency than Alacritty on Intel Mac (built-in 60Hz display)`

```markdown
### Issue Description

On an Intel MacBook Pro, Ghostty has a consistent, steady-state key→screen
latency about **~40 ms higher than Alacritty** — present from the very first
keystroke (not a degradation-over-time issue like #11651 / #11799, and not the
external-display redraw issue in #7333 / #10013).

I measured this deterministically rather than by feel. Harness, scripts, configs,
and raw CSVs: https://github.com/komsit37/ghostty-input-latency

### How I measured

- A helper runs inside the terminal and flips the screen black↔white on each
  keystroke (a large, unambiguous render target).
- A Swift tool injects a synthetic key via `CGEventPost`, then watches the display
  via ScreenCaptureKit and times key→flip with `mach_absolute_time`, 300 trials.
- Absolute numbers include a fixed harness floor (screen-capture + one 60 Hz
  refresh ≈ 14 ms), visible as Alacritty's ~14 ms minimum. The **gap** between the
  two terminals is the signal.

### Results (300 trials, p50)

| | Ghostty | Alacritty |
|---|---|---|
| full-screen repaint | 62.5 ms | 17.9 ms |
| localized (single small block) | 58.6 ms | 18.2 ms |
| min | 40.3 ms | 13.8 ms |

Alacritty sits ~1 frame above the harness floor; Ghostty adds ~40 ms on top.

### What it is NOT (controls I ran)

- **VSync** — Ghostty `window-vsync` off vs on: 57.9 vs 62.5 ms (no meaningful change).
- **Fullscreen type** — native vs `macos-non-native-fullscreen`: no meaningful change.
- **Repaint size** — a tiny single-block update (58.6) is as slow as a full-screen
  repaint (62.5), so it's not damage-area related.

The latency appears inherent to the render/present path on this hardware,
independent of workload.

### Expected Behavior

Per-keystroke latency comparable to other GPU terminals (Alacritty here is ~1
frame above the measurement floor).

### Actual Behavior

Ghostty is a steady ~40 ms (~2–3 frames at 60 Hz) slower, every keystroke.

### Reproduction Steps

Full steps in the repo README. Summary:
1. Build the harness (`swiftc latency.swift …`).
2. `./run.sh ghostty flip.py` (fullscreen), then
   `./latency --trials 300 --display <N> --csv ghostty.csv`.
3. Repeat for Alacritty, then `./compare.py ghostty.csv alacritty.csv`.

### System Info

- **Hardware:** MacBook Pro 16" 2019 (MacBookPro16,1), Intel Core i7-9750H
- **GPU:** AMD Radeon Pro 5300M + Intel UHD 630 (both Metal 3), automatic GPU switching
- **OS:** macOS 15.7.7 (24G720)
- **Display:** built-in laptop panel, 60 Hz (1792×1120 UI scale)
- **Ghostty:** 1.3.2-main-+39b3c4771   <!-- TODO: confirm on a stable release too -->
- **Alacritty:** 0.17.0 (baseline)

### Video

<!-- TODO: drag-drop a slow-motion clip here. Side-by-side both terminals driven
by one synchronized trigger; the frame gap between the two flips is the latency
difference. -->

### Possibly related

- #11651 / #11799 — same hardware class (Intel + Metal) but *progressive*
  degradation, whereas this is a constant baseline.
```
