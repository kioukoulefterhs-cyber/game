#!/usr/bin/env python3
"""Builds the Circuit Garden campaign pack with a measured difficulty curve.

1. Godot dumps generator candidates for every band variant (tools/dump_candidates.gd).
2. tools/level-analyzer scores each candidate's reasoning effort.
3. For each band, levels are picked so effort climbs evenly across the band's range and never
   drops below the previous level (v1 levels are preferred when they fit).
4. Every picked level is re-proven by the independent validator.

    python3 tools/level-generator/build_campaign.py --godot godot

The v1 levels come from archive/levels_v1_2026-10-21.json (the first launch pack) and keep the
generator params they were made with (archive/curriculum_v1.json), so each still reproduces
from its seed.

Deterministic for the same curriculum, engine version and previous pack.
"""
import argparse
import concurrent.futures as cf
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
GAME = os.path.join(ROOT, "games", "circuit-garden")
sys.path.insert(0, os.path.join(ROOT, "tools", "level-analyzer"))
sys.path.insert(0, os.path.join(ROOT, "tools", "level-validator"))
from analyze import analyze_level, label_for  # noqa: E402
from validate import validate_level  # noqa: E402

ARCHIVE = os.path.join(ROOT, "tools", "level-generator", "archive")
CHUNK = 500
PREFER_V1 = 1.0  # effort points a v1 level may be off target and still win


def dump(godot, params, first, count, tmp):
    pf = os.path.join(tmp, f"p{first}.json")
    out = os.path.join(tmp, f"c{first}.json")
    with open(pf, "w", encoding="utf-8") as f:
        json.dump(params, f)
    subprocess.run([godot, "--headless", "--path", GAME, "-s", "res://tools/dump_candidates.gd", "--",
                    pf, str(first), str(count), out], check=True, capture_output=True)
    with open(out, encoding="utf-8") as f:
        return json.load(f)["levels"]


def candidates(godot, band, per_variant, tmp, jobs):
    tasks = []
    for v, params in enumerate(band["variants"]):
        base = band["seed_base"] + v * 1_000_000
        for first in range(base, base + per_variant, CHUNK):
            tasks.append((v, params, first, min(CHUNK, base + per_variant - first)))
    out = []
    with cf.ThreadPoolExecutor(jobs) as ex:
        futures = [ex.submit(dump, godot, p, first, n, tmp) for v, p, first, n in tasks]
        for (v, params, first, n), fut in zip(tasks, futures):
            for d in fut.result():
                d["difficulty"]["params"] = params
                out.append(d)
    return out


def pick(pool, count, lo, hi, floor):
    """Evenly spaced effort targets; each pick at least as hard as the previous one."""
    chosen, used = [], set()
    for k in range(count):
        target = lo + (hi - lo) * k / max(1, count - 1)
        best, best_cost = None, None
        for idx, (d, r) in enumerate(pool):
            if idx in used or r["effort"] < floor:
                continue
            cost = abs(r["effort"] - target) - (PREFER_V1 if d.get("_v1") else 0.0)
            key = (cost, r["effort"], d["seed"])
            if best_cost is None or key < best_cost:
                best, best_cost = idx, key
        if best is None:
            raise SystemExit(f"no candidate left for target {target:.1f} (floor {floor})")
        used.add(best)
        chosen.append(pool[best])
        floor = pool[best][1]["effort"]
    return chosen, floor


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    ap.add_argument("--curriculum", default=os.path.join(GAME, "puzzles", "curriculum.json"))
    ap.add_argument("--old", default=os.path.join(ARCHIVE, "levels_v1_2026-10-21.json"),
                    help="previous pack whose levels are preferred when they fit (band names must match)")
    ap.add_argument("--old-curriculum", default=os.path.join(ARCHIVE, "curriculum_v1.json"))
    ap.add_argument("--out", default=os.path.join(GAME, "puzzles", "levels_v1.json"))
    ap.add_argument("--jobs", type=int, default=os.cpu_count() or 2)
    args = ap.parse_args()
    with open(args.curriculum, encoding="utf-8") as f:
        cur = json.load(f)
    old = {}
    with open(args.old_curriculum, encoding="utf-8") as f:
        old_params = {b["name"]: b["params"] for b in json.load(f)["bands"]}
    with open(args.old, encoding="utf-8") as f:
        for d in json.load(f)["levels"]:
            d["difficulty"]["params"] = old_params[d["difficulty"]["band"]]
            old.setdefault(d["difficulty"]["band"], []).append(d)
    levels, seen, floor = [], set(), 0.0
    with tempfile.TemporaryDirectory() as tmp:
        for band in cur["bands"]:
            per = band.get("candidates_per_variant", cur["candidates_per_variant"])
            raw = candidates(args.godot, band, per, tmp, args.jobs)
            if band.get("keep_v1"):
                for d in old.get(band["name"], []):
                    d = json.loads(json.dumps(d))
                    d["_v1"] = True
                    raw.insert(0, d)
            pool = []
            for d in raw:
                key = (d["tiles"], tuple(d["colors"]))
                if key in seen:
                    continue
                seen.add(key)
                pool.append((d, analyze_level(d)))
            lo, hi = band["effort"]
            chosen, floor = pick(pool, band["count"], lo, hi, floor)
            kept = sum(1 for d, _ in chosen if d.get("_v1"))
            print(f"{band['name']:<10} {band['count']:2d} levels from {len(pool):5d} candidates, "
                  f"effort {chosen[0][1]['effort']:.0f}-{chosen[-1][1]['effort']:.0f}, kept {kept} v1 levels")
            for d, r in chosen:
                d = dict(d)
                was = d.pop("_v1", False)
                d["id"] = "cg-%03d" % (len(levels) + 1)
                diff = dict(d["difficulty"])
                diff.update({"band": band["name"], "effort": r["effort"], "label": label_for(r["effort"]),
                             "hardest": r["hardest"], "depth": r["depth"], "kept_from_v1": was})
                d["difficulty"] = diff
                errs, _ = validate_level(d)
                if errs:
                    raise SystemExit(f"{d['id']} failed validation: {errs}")
                levels.append(d)
    pack = {"format": "circuit-garden-pack", "version": 1, "generator": "forest-v1",
            "curriculum_version": cur["version"], "levels": levels}
    with open(args.out, "w", encoding="utf-8") as f:
        f.write(json.dumps(pack, indent="\t") + "\n")
    print(f"wrote {len(levels)} levels to {args.out}")


if __name__ == "__main__":
    main()
