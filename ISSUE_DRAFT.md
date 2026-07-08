# Drafts for reporting to ghostty-org/ghostty

> Not yet posted. Before posting: (1) re-run on a **stable** Ghostty release and
> update the version line — current data is on a `-main-` dev build; (2) attach the
> slow-motion video. Ghostty requires reporters to be **vouched** and routes bug
> reports through Discussions → **Issue Triage**, not raw Issues.

---

## Draft 1 — Vouch Request discussion

**Category:** Vouch Request

> ⚠️ **WRITE THIS YOURSELF, IN YOUR OWN VOICE.** Ghostty's CONTRIBUTING rule #3
> explicitly says "don't have an AI write this." The whole point of the vouch
> system is to filter out AI-generated content — pasting AI prose here defeats it
> and risks denouncement. So this is a **checklist of points to cover**, not text
> to copy. Keep it concise and follow their template.

Points to cover in your own words:
- Who you are and that you actually use Ghostty daily.
- What you want to report: Ghostty feels laggier than other terminals when typing,
  so you measured it instead of guessing.
- That you built a small harness to compare key→screen latency vs Alacritty and
  found a consistent gap, with controls.
- Link to your repo for the method/data: https://github.com/komsit37/ghostty-input-latency
- That you'll include a slow-mo video and are happy to run more tests.

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
