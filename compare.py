#!/usr/bin/env python3
"""Side-by-side latency comparison from the harness CSVs.
Usage: ./compare.py ghostty.csv alacritty.csv [more.csv ...]"""
import sys, statistics as st

def load(path):
    with open(path) as f:
        rows = [float(x) for x in f.read().split("\n")[1:] if x.strip()]
    return sorted(rows)

def pct(s, p):
    if not s: return float("nan")
    return s[min(len(s)-1, round((p/100)*(len(s)-1)))]

def main(paths):
    data = {p: load(p) for p in paths}
    cols = list(data)
    w = max(12, max(len(c) for c in cols) + 2)
    def row(label, fn):
        print(f"{label:<8}" + "".join(f"{fn(data[c]):>{w}.2f}" for c in cols))
    print(f"{'':<8}" + "".join(f"{c:>{w}}" for c in cols))
    print("-" * (8 + w*len(cols)))
    row("n",    lambda s: len(s))
    row("min",  lambda s: s[0] if s else float('nan'))
    row("p50",  lambda s: pct(s,50))
    row("p90",  lambda s: pct(s,90))
    row("p99",  lambda s: pct(s,99))
    row("max",  lambda s: s[-1] if s else float('nan'))
    row("mean", lambda s: st.mean(s) if s else float('nan'))
    row("stdev",lambda s: st.pstdev(s) if len(s)>1 else float('nan'))
    if len(cols) == 2:
        a, b = data[cols[0]], data[cols[1]]
        d = pct(a,50) - pct(b,50)
        print(f"\np50 delta: {cols[0]} - {cols[1]} = {d:+.2f} ms "
              f"({'faster' if d<0 else 'slower'} {cols[0]})")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__); sys.exit(1)
    main(sys.argv[1:])
