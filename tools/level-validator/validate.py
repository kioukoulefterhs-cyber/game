#!/usr/bin/env python3
"""Independent validator for Circuit Garden level packs.

Re-implements the rules in docs/puzzle-rules.md without sharing code with the game,
and proves every level against them with its own solver (most-constrained-cell search
with edge propagation; the game uses row-major backtracking).

    python3 tools/level-validator/validate.py games/circuit-garden/puzzles/levels_v1.json

Exit code 0 when every level passes. Use --json for a machine-readable report.
"""
import argparse
import json
import sys

N, E, S, W = 1, 2, 4, 8
DIRS = (N, E, S, W)
OPP = {N: S, E: W, S: N, W: E}
DELTA = {N: (-1, 0), E: (0, 1), S: (1, 0), W: (0, -1)}
BASE = {".": 0, "#": 0, "I": N | S, "L": N | E, "T": N | E | S, "+": 15, "c": N, "S": N, "R": N}
ROTATABLE = set("ILTc")
COLORED = set("SR")
SUPPORTED_SIZES = {4, 5, 6, 7}
NODE_LIMIT = 5_000_000


def rot(mask, k):
    for _ in range(k % 4):
        mask = ((mask << 1) | (mask >> 3)) & 15
    return mask


def channel(code, d):
    if code == "+":
        return 0 if d in (N, S) else 1
    return 0


class Level:
    def __init__(self, d):
        self.d = d
        self.id = d["id"]
        self.n = d["size"]
        self.tiles = d["tiles"]
        self.colors = d["colors"]
        self.start = d["start"]
        self.solution = d["solution"]
        self.locked = set(d.get("locked", []))

    def neighbor(self, i, d):
        r, c = divmod(i, self.n)
        dr, dc = DELTA[d]
        r, c = r + dr, c + dc
        if 0 <= r < self.n and 0 <= c < self.n:
            return r * self.n + c
        return -1

    def free(self, i):
        return self.tiles[i] in ROTATABLE and i not in self.locked

    def masks_for(self, rots):
        return [rot(BASE[t], k) for t, k in zip(self.tiles, rots)]


def solved(level, masks):
    """Returns (ok, reason) for a full assignment of masks."""
    n2 = level.n * level.n
    parent = {}

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for i in range(n2):
        for d in DIRS:
            if masks[i] & d:
                parent.setdefault(i * 2 + channel(level.tiles[i], d), i * 2 + channel(level.tiles[i], d))
    for i in range(n2):
        for d in DIRS:
            if not masks[i] & d:
                continue
            j = level.neighbor(i, d)
            if j < 0 or not masks[j] & OPP[d]:
                return False, f"leak at cell {i} dir {d}"
            a = find(i * 2 + channel(level.tiles[i], d))
            b = find(j * 2 + channel(level.tiles[j], OPP[d]))
            if a != b:
                parent[a] = b
    sources = {}
    for i in range(n2):
        if level.tiles[i] == "S":
            root = find(i * 2)
            sources.setdefault(root, []).append(level.colors[i])
    for node in parent:
        root = find(node)
        if len(sources.get(root, [])) != 1:
            return False, f"network of node {node} has {len(sources.get(root, []))} sources"
    for i in range(n2):
        if level.tiles[i] == "R":
            if i * 2 not in parent:
                return False, f"receiver {i} is closed"
            if sources[find(i * 2)][0] != level.colors[i]:
                return False, f"receiver {i} gets the wrong color"
    return True, "ok"


def count_solutions(level, limit=2):
    """Most-constrained-cell search with edge propagation. Returns (count, nodes, aborted, first)."""
    n2 = level.n * level.n
    options = []
    for i in range(n2):
        if level.free(i):
            opts = sorted({rot(BASE[level.tiles[i]], k) for k in range(4)})
        else:
            opts = [rot(BASE[level.tiles[i]], level.solution[i])]
        options.append(opts)
    edge = {}  # (min cell, dir from min cell) -> bool
    assign = [None] * n2
    found = []
    stats = {"nodes": 0, "aborted": False}

    def edge_key(i, d):
        j = level.neighbor(i, d)
        return (i, d) if i < j else (j, OPP[d])

    def consistent(i, m):
        for d in DIRS:
            j = level.neighbor(i, d)
            open_ = bool(m & d)
            if j < 0:
                if open_:
                    return False
                continue
            known = edge.get(edge_key(i, d))
            if known is not None and known != open_:
                return False
        return True

    def search(remaining):
        if len(found) >= limit or stats["aborted"]:
            return
        stats["nodes"] += 1
        if stats["nodes"] > NODE_LIMIT:
            stats["aborted"] = True
            return
        if not remaining:
            masks = list(assign)
            if solved(level, masks)[0]:
                found.append(masks)
            return
        best, best_opts = None, None
        for i in remaining:
            opts = [m for m in options[i] if consistent(i, m)]
            if best_opts is None or len(opts) < len(best_opts):
                best, best_opts = i, opts
                if len(opts) <= 1:
                    break
        if not best_opts:
            return
        rest = [i for i in remaining if i != best]
        for m in best_opts:
            set_keys = []
            for d in DIRS:
                if level.neighbor(best, d) >= 0:
                    k = edge_key(best, d)
                    if k not in edge:
                        edge[k] = bool(m & d)
                        set_keys.append(k)
            assign[best] = m
            search(rest)
            assign[best] = None
            for k in set_keys:
                del edge[k]
            if len(found) >= limit or stats["aborted"]:
                return

    search(list(range(n2)))
    return len(found), stats["nodes"], stats["aborted"], (found[0] if found else None)


def min_taps(level):
    total = 0
    sol = level.masks_for(level.solution)
    for i in range(level.n * level.n):
        if not level.free(i):
            continue
        base = BASE[level.tiles[i]]
        k = next(k for k in range(4) if rot(base, level.start[i] + k) == sol[i])
        total += k
    return total


def validate_level(d):
    errors = []
    try:
        lv = Level(d)
    except (KeyError, TypeError) as exc:
        return [f"missing field {exc}"], {}
    n2 = lv.n * lv.n
    if d.get("format") != "circuit-garden-level" or d.get("version") != 1:
        errors.append("wrong format/version")
    if lv.n not in SUPPORTED_SIZES:
        errors.append(f"unsupported size {lv.n}")
    for name in ("tiles", "colors", "start", "solution"):
        if len(d[name]) != n2:
            errors.append(f"{name} has {len(d[name])} entries, expected {n2}")
    if errors:
        return errors, {}
    for i, t in enumerate(lv.tiles):
        if t not in BASE:
            errors.append(f"cell {i}: unknown tile {t!r}")
        elif (t in COLORED) != (lv.colors[i] >= 0):
            errors.append(f"cell {i}: tile {t!r} color {lv.colors[i]}")
        if not 0 <= lv.start[i] <= 3 or not 0 <= lv.solution[i] <= 3:
            errors.append(f"cell {i}: rotation out of range")
        if t not in ROTATABLE and lv.start[i] != lv.solution[i]:
            errors.append(f"cell {i}: fixed tile starts off its solution")
    for i in lv.locked:
        if lv.tiles[i] not in ROTATABLE:
            errors.append(f"cell {i}: locked but not rotatable")
    if errors:
        return errors, {}
    ok, why = solved(lv, lv.masks_for(lv.solution))
    if not ok:
        errors.append(f"stored solution does not solve: {why}")
    start_rots = [lv.solution[i] if i in lv.locked else lv.start[i] for i in range(n2)]
    if solved(lv, lv.masks_for(start_rots))[0]:
        errors.append("start position is already solved (trivial)")
    count, nodes, aborted, first = count_solutions(lv, 2)
    if aborted:
        errors.append("solver hit its node limit; uniqueness unproven")
    elif count != 1:
        errors.append(f"expected exactly 1 solution, found {count}")
    elif first != lv.masks_for(lv.solution):
        errors.append("the unique solution differs from the stored solution")
    taps = min_taps(lv)
    if taps != d.get("min_moves"):
        errors.append(f"min_moves {d.get('min_moves')} but recomputed {taps}")
    if d.get("par") != taps + lv.n:
        errors.append(f"par {d.get('par')} but expected {taps + lv.n}")
    free = sum(1 for i in range(n2) if lv.free(i))
    if taps < 3:
        errors.append(f"only {taps} taps needed (trivial)")
    colors = sorted({c for c in lv.colors if c >= 0})
    for c in colors:
        if sum(1 for i in range(n2) if lv.tiles[i] == "S" and lv.colors[i] == c) != 1:
            errors.append(f"color {c} does not have exactly one source")
        if not any(lv.tiles[i] == "R" and lv.colors[i] == c for i in range(n2)):
            errors.append(f"color {c} has no receiver")
    return errors, {"solutions": count, "nodes": nodes, "free": free, "min_moves": taps}


def validate_pack(pack, expected_count=None):
    report = {"levels": [], "pack_errors": []}
    if pack.get("format") != "circuit-garden-pack" or pack.get("version") != 1:
        report["pack_errors"].append("wrong pack format/version")
    levels = pack.get("levels", [])
    if expected_count is not None and len(levels) != expected_count:
        report["pack_errors"].append(f"expected {expected_count} levels, found {len(levels)}")
    ids, puzzles = set(), set()
    prev_size = 0
    for d in levels:
        errs, info = validate_level(d)
        if d.get("id") in ids:
            errs.append("duplicate id")
        ids.add(d.get("id"))
        key = (d.get("tiles"), tuple(d.get("colors", [])))
        if key in puzzles:
            errs.append("duplicate puzzle")
        puzzles.add(key)
        if d.get("size", 0) < prev_size:
            errs.append("board size decreases along the campaign")
        prev_size = max(prev_size, d.get("size", 0))
        report["levels"].append({"id": d.get("id"), "ok": not errs, "errors": errs, **info})
    sizes = {d.get("size") for d in levels}
    if levels and not SUPPORTED_SIZES <= sizes:
        report["pack_errors"].append(f"campaign covers sizes {sorted(sizes)}, expected 4-7")
    report["passed"] = sum(1 for lv in report["levels"] if lv["ok"])
    report["failed"] = len(report["levels"]) - report["passed"]
    report["ok"] = report["failed"] == 0 and not report["pack_errors"]
    return report


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("pack")
    ap.add_argument("--expect", type=int, default=None, help="required number of levels")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()
    with open(args.pack, encoding="utf-8") as f:
        pack = json.load(f)
    report = validate_pack(pack, args.expect)
    if args.json:
        print(json.dumps(report, indent=2))
    else:
        for lv in report["levels"]:
            if lv["ok"]:
                print(f"ok    {lv['id']}  free={lv['free']:2d} min_moves={lv['min_moves']:2d} nodes={lv['nodes']}")
            else:
                print(f"FAIL  {lv['id']}  " + "; ".join(lv["errors"]))
        for e in report["pack_errors"]:
            print("PACK  " + e)
        print(f"\n{report['passed']}/{len(report['levels'])} levels valid" + ("" if report["ok"] else "  (FAILED)"))
    sys.exit(0 if report["ok"] else 1)


if __name__ == "__main__":
    main()
