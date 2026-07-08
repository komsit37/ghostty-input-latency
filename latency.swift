// Deterministic-ish keyboard->screen latency harness for terminal emulators.
//
// Posts a synthetic key event, then watches a small screen region (captured via
// ScreenCaptureKit) for the luminance flip produced by flip.py running inside
// the target terminal. Times key->flip over N trials and reports the spread.
//
// Requires, granted to whatever terminal you RUN this binary from
// (System Settings > Privacy & Security):
//   - Accessibility    (to post the key event)
//   - Screen Recording (to capture the region)
//
// Build:  swiftc latency.swift -o latency \
//           -framework ScreenCaptureKit -framework CoreMedia \
//           -framework CoreVideo -framework CoreGraphics -framework Foundation
// Usage:  ./latency [--trials N] [--region PX] [--settle MS] [--timeout MS] [--csv path]

import Foundation
import CoreGraphics
import CoreMedia
import CoreVideo
import ScreenCaptureKit

// ---- args ----
var trials = 300
var regionSize = 200.0
var settleMs = 150.0
var timeoutMs = 1000.0
var keycode: CGKeyCode = 0x31 // space
var csvPath: String? = nil
var displayIndex = -1   // -1 = auto (main display)
var watch = false       // just print live luminance, no key posting
var verbose = false

var it = CommandLine.arguments.dropFirst().makeIterator()
while let a = it.next() {
    switch a {
    case "--trials":  if let v = it.next() { trials = Int(v) ?? trials }
    case "--region":  if let v = it.next() { regionSize = Double(v) ?? regionSize }
    case "--settle":  if let v = it.next() { settleMs = Double(v) ?? settleMs }
    case "--timeout": if let v = it.next() { timeoutMs = Double(v) ?? timeoutMs }
    case "--csv":     csvPath = it.next()
    case "--display": if let v = it.next() { displayIndex = Int(v) ?? -1 }
    case "--watch":   watch = true
    case "--verbose", "-v": verbose = true
    default: FileHandle.standardError.write("unknown arg: \(a)\n".data(using: .utf8)!)
    }
}

// ---- timing ----
var tb = mach_timebase_info_data_t()
mach_timebase_info(&tb)
@inline(__always) func nowNs() -> Double {
    Double(mach_absolute_time()) * Double(tb.numer) / Double(tb.denom)
}

// ---- key injection ----
let src = CGEventSource(stateID: .hidSystemState)
func postKey() {
    CGEvent(keyboardEventSource: src, virtualKey: keycode, keyDown: true)?.post(tap: .cghidEventTap)
    CGEvent(keyboardEventSource: src, virtualKey: keycode, keyDown: false)?.post(tap: .cghidEventTap)
}

// ---- capture (ScreenCaptureKit) ----
// Latest per-cell luminance grid (whole display, downscaled) + arrival timestamp.
// We keep the whole grid, not a single average, so we can detect a LOCALIZED
// change (single glyph / small block) anywhere on screen without hand-aligning
// a capture region -- the detector looks at the max per-cell delta.
final class Cap: NSObject, SCStreamOutput {
    private let lock = NSLock()
    private var _grid: [Double] = []
    private var _stamp = 0.0
    var latest: (grid: [Double], stamp: Double) {
        lock.lock(); defer { lock.unlock() }; return (_grid, _stamp)
    }
    func stream(_ stream: SCStream, didOutputSampleBuffer sb: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, let pb = CMSampleBufferGetImageBuffer(sb) else { return }
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pb) else { return }
        let w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb)
        let bpr = CVPixelBufferGetBytesPerRow(pb)
        let p = base.assumingMemoryBound(to: UInt8.self)
        var grid = [Double](repeating: 0, count: w*h)   // per-cell luminance (BGRA)
        for y in 0..<h { for x in 0..<w {
            let o = y*bpr + x*4
            grid[y*w+x] = 0.2126*Double(p[o+2]) + 0.7152*Double(p[o+1]) + 0.0722*Double(p[o])
        } }
        let t = nowNs()
        lock.lock(); _grid = grid; _stamp = t; lock.unlock()
    }
}

// max per-cell absolute difference between two equal-length grids
@inline(__always) func maxDelta(_ a: [Double], _ b: [Double]) -> Double {
    guard a.count == b.count, !a.isEmpty else { return 0 }
    var m = 0.0
    for i in 0..<a.count { let d = abs(a[i]-b[i]); if d > m { m = d } }
    return m
}

let cap = Cap()
let sema = DispatchSemaphore(value: 0)
var stream: SCStream?
var setupError: String?

SCShareableContent.getWithCompletionHandler { content, err in
    defer { sema.signal() }
    if let err = err { setupError = "getShareableContent: \(err.localizedDescription)"; return }
    let displays = content?.displays ?? []
    guard !displays.isEmpty else { setupError = "no display"; return }
    // list displays so a multi-monitor setup can pick the right one
    print("displays:")
    for (i, d) in displays.enumerated() {
        let main = d.displayID == CGMainDisplayID() ? " (main)" : ""
        print("  [\(i)] \(d.width)x\(d.height)\(main)")
    }
    let display: SCDisplay
    if displayIndex >= 0 && displayIndex < displays.count {
        display = displays[displayIndex]
    } else {
        display = displays.first { $0.displayID == CGMainDisplayID() } ?? displays[0]
    }
    print("capturing display \(display.width)x\(display.height); center region \(Int(regionSize))px\n")
    let filter = SCContentFilter(display: display, excludingWindows: [])
    let cfg = SCStreamConfiguration()
    // capture the whole display, downscaled to a grid fine enough that a small
    // localized block still occupies several cells (for max-delta detection)
    cfg.width = 96
    cfg.height = 54
    cfg.minimumFrameInterval = CMTime(value: 1, timescale: 240)
    cfg.pixelFormat = kCVPixelFormatType_32BGRA
    cfg.queueDepth = 6
    cfg.showsCursor = false
    let s = SCStream(filter: filter, configuration: cfg, delegate: nil)
    do {
        try s.addStreamOutput(cap, type: .screen, sampleHandlerQueue: DispatchQueue(label: "cap"))
        stream = s
    } catch { setupError = "addStreamOutput: \(error.localizedDescription)" }
}
sema.wait()

if let e = setupError {
    FileHandle.standardError.write("""
    ERROR: \(e)
    Grant Screen Recording to this terminal in System Settings > Privacy & Security,
    then fully quit and reopen the terminal.\n
    """.data(using: .utf8)!)
    exit(1)
}

let startSema = DispatchSemaphore(value: 0)
stream?.startCapture { err in
    if let err = err { setupError = "startCapture: \(err.localizedDescription)" }
    startSema.signal()
}
startSema.wait()
if let e = setupError {
    FileHandle.standardError.write("ERROR: \(e)\n".data(using: .utf8)!)
    exit(1)
}

// let the stream warm up and deliver a first frame
usleep(500_000)
if cap.latest.stamp == 0 {
    FileHandle.standardError.write("ERROR: no frames delivered; is Screen Recording permission granted?\n".data(using: .utf8)!)
    exit(1)
}

// ---- watch mode: print when the screen changes so you can validate capture ----
if watch {
    print("WATCH: focus the test terminal and type — you should see a change detected on each key.")
    print("If nothing prints, the target isn't on the captured display. Ctrl-C to stop.\n")
    var prev = cap.latest.grid
    while true {
        let cur = cap.latest.grid
        let d = maxDelta(cur, prev)
        if d > 20 { print(String(format: "  change detected: max cell delta %.0f", d)) }
        prev = cur
        usleep(60_000)
    }
}

// ---- run ----
print("Focus the TEST terminal (running flip.py). \(trials) trials, region \(Int(regionSize))px @ screen center.")
for i in stride(from: 5, through: 1, by: -1) { print("  starting in \(i)..."); usleep(1_000_000) }

var samples: [Double] = []
var misses = 0
let threshold = 40.0

for i in 0..<trials {
    let base = cap.latest.grid
    let t0 = nowNs()
    postKey()
    var hit: Double? = nil
    while nowNs() - t0 < timeoutMs * 1e6 {
        let cur = cap.latest
        if cur.stamp > t0 && maxDelta(cur.grid, base) > threshold { hit = cur.stamp; break }
        usleep(200)
    }
    if let t1 = hit {
        let ms = (t1 - t0) / 1e6
        samples.append(ms)
        if verbose { print(String(format: "  trial %d: ms=%.2f", i, ms)) }
    } else {
        misses += 1
        if verbose { print(String(format: "  trial %d: MISS", i)) }
    }
    usleep(UInt32(settleMs * 1000))
}

stream?.stopCapture { _ in }

// ---- stats ----
func pct(_ s: [Double], _ p: Double) -> Double {
    if s.isEmpty { return .nan }
    let idx = min(s.count - 1, max(0, Int(((p/100.0) * Double(s.count - 1)).rounded())))
    return s[idx]
}
let sorted = samples.sorted()
let mean = samples.isEmpty ? Double.nan : samples.reduce(0,+)/Double(samples.count)
print(String(format: """

  samples: %d   misses: %d
  min   : %6.2f ms
  p50   : %6.2f ms
  p90   : %6.2f ms
  p99   : %6.2f ms
  max   : %6.2f ms
  mean  : %6.2f ms
""", samples.count, misses,
   sorted.first ?? .nan, pct(sorted,50), pct(sorted,90), pct(sorted,99),
   sorted.last ?? .nan, mean))

if let path = csvPath {
    let csv = "ms\n" + samples.map { String(format: "%.3f", $0) }.joined(separator: "\n") + "\n"
    try? csv.write(toFile: path, atomically: true, encoding: .utf8)
    print("  wrote \(samples.count) samples -> \(path)")
}
