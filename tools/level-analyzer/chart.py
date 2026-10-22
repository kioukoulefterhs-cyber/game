#!/usr/bin/env python3
"""Draws the level-by-level effort chart (SVG, no dependencies) from analyze.py --json reports.

    python3 tools/level-analyzer/chart.py after.json [before.json] -o docs/difficulty/effort.svg
"""
import argparse
import json

W, H, L, R, T, B = 900, 430, 56, 20, 40, 74
SERIES = [("#eb6834", "Launch pack (rebuilt)"), ("#2a78d6", "First pack (2026-10-21)")]
INK, MUTED, GRID, SURFACE = "#1f1f1e", "#6b6a63", "#e4e3dd", "#ffffff"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("reports", nargs="+")
    ap.add_argument("-o", "--out", required=True)
    args = ap.parse_args()
    runs = [json.load(open(p, encoding="utf-8"))["levels"] for p in args.reports]
    top = max(110, max(r["effort"] for run in runs for r in run))
    x = lambda i: L + (W - L - R) * (i - 1) / 99
    y = lambda e: H - B - (H - T - B) * e / top
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" font-family="system-ui, sans-serif" font-size="12">',
           f'<rect width="{W}" height="{H}" fill="{SURFACE}"/>',
           f'<text x="{L}" y="22" font-size="15" font-weight="600" fill="{INK}">Reasoning effort per level (higher = harder)</text>']
    for e in range(0, int(top) + 1, 20):
        out.append(f'<line x1="{L}" x2="{W - R}" y1="{y(e):.1f}" y2="{y(e):.1f}" stroke="{GRID}"/>')
        out.append(f'<text x="{L - 8}" y="{y(e) + 4:.1f}" text-anchor="end" fill="{MUTED}">{e}</text>')
    run0 = runs[0]
    prev, row = None, 0
    for r in run0:
        if r["band"] != prev:
            xi = x(r["index"])
            out.append(f'<line x1="{xi:.1f}" x2="{xi:.1f}" y1="{T}" y2="{H - B}" stroke="{GRID}" stroke-dasharray="3 3"/>')
            out.append(f'<text x="{xi + 4:.1f}" y="{H - B + 30 + 13 * row}" fill="{MUTED}">{r["band"]} {r["size"]}x{r["size"]}</text>')
            prev, row = r["band"], 1 - row
    for i in (1, 20, 40, 60, 80, 100):
        out.append(f'<text x="{x(i):.1f}" y="{H - B + 15}" text-anchor="middle" fill="{MUTED}">{i}</text>')
    for k, run in reversed(list(enumerate(runs))):
        color, _ = SERIES[k]
        pts = " ".join(f"{x(r['index']):.1f},{y(r['effort']):.1f}" for r in run)
        out.append(f'<polyline points="{pts}" fill="none" stroke="{color}" stroke-width="2" stroke-linejoin="round"/>')
    lx = W - R - 380
    for k in range(len(runs)):
        color, name = SERIES[k]
        out.append(f'<rect x="{lx + k * 200}" y="12" width="14" height="4" rx="2" fill="{color}"/>')
        out.append(f'<text x="{lx + k * 200 + 20}" y="18" fill="{INK}">{name}</text>')
    out.append(f'<text x="{W / 2}" y="{H - 8}" text-anchor="middle" fill="{MUTED}">Level</text>')
    out.append("</svg>")
    with open(args.out, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")


if __name__ == "__main__":
    main()
