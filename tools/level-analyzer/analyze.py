#!/usr/bin/env python3
"""Measures how hard each Circuit Garden level is to solve by reasoning, not by grid size.

A human-style deduction engine solves every level using techniques of increasing strength,
always using the weakest technique that still makes progress (the way people solve logic
puzzles). What a level needs, and how often, is its difficulty:

  T1 local fit     a tile orientation is impossible because an arm would point off the board,
                   into a neighbour that can never connect back, or away from one that must.
  T2 network rule  an orientation is impossible because placing it would, right away, join two
                   sources, give a flower the wrong colour, or close a network with no source.
  T3 what-if       assume an orientation, run T1+T2 to a standstill, and find a contradiction.
  T4 deep what-if  the same, but the contradiction only appears after a second nested guess.
  Guess            nothing above works; the engine has to branch (trial and error).

    python3 tools/level-analyzer/analyze.py games/circuit-garden/puzzles/levels_v1.json
    python3 tools/level-analyzer/analyze.py PACK --json report.json --csv report.csv

Shares only the rules module of the independent validator, not any game code.
"""
import argparse
import csv
import json
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "level-validator"))
from validate import BASE, DIRS, OPP, Level, count_solutions, min_taps, rot, channel  # noqa: E402

# Weights of the effort score: how many "simple deductions" one use of a technique is worth.
# T1 counts every tile it settles; harder techniques count every elimination they make.
# "round" is charged for every extra round of reasoning after the first, because a cell that can
# only be worked out after others were settled means holding a longer chain in your head.
WEIGHTS = {"t1": 1.0, "t2": 3.0, "t3": 8.0, "t4": 30.0, "guess": 80.0, "round": 2.0}
LABELS = ((0, "Easy"), (20, "Medium"), (45, "Hard"), (75, "Expert"))


class Contradiction(Exception):
    pass


class State:
    """Candidate masks per cell. Fixed and pinned tiles have one candidate."""

    def __init__(self, lv, cand):
        self.lv = lv
        self.cand = cand

    @classmethod
    def initial(cls, lv):
        cand = []
        for i in range(lv.n * lv.n):
            if lv.free(i):
                cand.append(sorted({rot(BASE[lv.tiles[i]], k) for k in range(4)}))
            else:
                cand.append([rot(BASE[lv.tiles[i]], lv.solution[i])])
        return cls(lv, cand)

    def copy(self):
        return State(self.lv, [list(c) for c in self.cand])

    def open_cells(self):
        return [i for i, c in enumerate(self.cand) if len(c) > 1]

    def done(self):
        return all(len(c) == 1 for c in self.cand)


def fits(lv, cand, i, m):
    for d in DIRS:
        j = lv.neighbor(i, d)
        want = bool(m & d)
        if j < 0:
            if want:
                return False
        elif not any(bool(x & OPP[d]) == want for x in cand[j]):
            return False
    return True


def propagate_t1(st):
    """Local fit to a standstill. Returns how many cells became settled."""
    lv, cand = st.lv, st.cand
    before = sum(1 for c in cand if len(c) == 1)
    queue = list(range(len(cand)))
    queued = set(queue)
    while queue:
        i = queue.pop()
        queued.discard(i)
        if len(cand[i]) == 1 and not fits(lv, cand, i, cand[i][0]):
            raise Contradiction
        keep = [m for m in cand[i] if fits(lv, cand, i, m)]
        if not keep:
            raise Contradiction
        if len(keep) != len(cand[i]):
            cand[i] = keep
            for d in DIRS:
                j = lv.neighbor(i, d)
                if j >= 0 and j not in queued:
                    queue.append(j)
                    queued.add(j)
    return sum(1 for c in cand if len(c) == 1) - before


def network_violation(lv, cand):
    """True if the settled tiles already break a network rule (see docstring, T2)."""
    n2 = lv.n * lv.n
    parent = {}

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    settled = [c[0] if len(c) == 1 else None for c in cand]
    for i in range(n2):
        if settled[i] is None:
            continue
        for d in DIRS:
            if settled[i] & d:
                k = i * 2 + channel(lv.tiles[i], d)
                parent.setdefault(k, k)
    open_end = set()
    for i in range(n2):
        m = settled[i]
        if m is None:
            continue
        for d in DIRS:
            if not m & d:
                continue
            j = lv.neighbor(i, d)
            a = find(i * 2 + channel(lv.tiles[i], d))
            if j < 0:
                return True
            if settled[j] is None:
                open_end.add(a)
                continue
            if not settled[j] & OPP[d]:
                return True
            b = find(j * 2 + channel(lv.tiles[j], OPP[d]))
            if a != b:
                parent[a] = b
    groups = {}
    for k in parent:
        g = groups.setdefault(find(k), {"src": [], "rcv": [], "open": False})
    for k in list(open_end):
        groups[find(k)]["open"] = True
    for i in range(n2):
        if settled[i] is None or lv.tiles[i] not in "SR":
            continue
        g = groups[find(i * 2)]
        (g["src"] if lv.tiles[i] == "S" else g["rcv"]).append(lv.colors[i])
    for g in groups.values():
        if len(g["src"]) > 1:
            return True
        if g["src"] and any(c != g["src"][0] for c in g["rcv"]):
            return True
        if not g["open"] and not g["src"]:
            return True
    return False


def t1_wave(st):
    """One synchronous round of local fit: every cell judged against the board as it was at
    the start of the round. Returns cells settled this round (raises on contradiction)."""
    lv, snap = st.lv, [list(c) for c in st.cand]
    settled = 0
    for i in range(len(snap)):
        keep = [m for m in snap[i] if fits(lv, snap, i, m)]
        if not keep:
            raise Contradiction
        if len(keep) == 1 and len(snap[i]) > 1:
            settled += 1
        st.cand[i] = keep
    return settled, st.cand != snap


def settle(st):
    """T1 + network check to a standstill; raises Contradiction when the state is impossible."""
    propagate_t1(st)
    if network_violation(st.lv, st.cand):
        raise Contradiction


def try_t2(st):
    """Eliminate orientations that break a network rule immediately. Returns eliminations."""
    lv, cand = st.lv, st.cand
    removed = 0
    for i in st.open_cells():
        keep = []
        for m in cand[i]:
            trial = list(cand)
            trial[i] = [m]
            if network_violation(lv, trial):
                removed += 1
            else:
                keep.append(m)
        cand[i] = keep
    return removed


def probe(st, i, m, depth):
    """True if assuming cell i = m leads to a contradiction within `depth` nested guesses."""
    t = st.copy()
    t.cand[i] = [m]
    try:
        settle(t)
        while True:
            if try_t2(t) == 0:
                break
            settle(t)
    except Contradiction:
        return True
    if depth <= 1 or t.done():
        return False
    for j in t.open_cells():
        if all(probe(t, j, x, depth - 1) for x in t.cand[j]):
            return True
    return False


def try_probe(st, depth):
    removed = 0
    for i in st.open_cells():
        keep = [m for m in st.cand[i] if not probe(st, i, m, depth)]
        if not keep:
            raise Contradiction
        removed += len(st.cand[i]) - len(keep)
        st.cand[i] = keep
        if removed:
            return removed  # cheapest-first: go back to simple logic after each find
    return removed


def solve_logically(lv):
    st = State.initial(lv)
    uses = {"t1": 0, "t2": 0, "t3": 0, "t4": 0, "guess": 0}
    steps = {"t1": 0, "t2": 0, "t3": 0, "t4": 0, "guess": 0}
    trace = []  # technique used at each round, the "solution path"
    hardest = "t1"
    order = ["t1", "t2", "t3", "t4", "guess"]
    waves = []  # cells settled by each round of local fit: the chain of reasoning
    while True:
        while True:
            gained, changed = t1_wave(st)
            if not changed:
                break
            uses["t1"] += gained
            steps["t1"] += 1
            waves.append(gained)
            trace.append("t1")
        if st.done():
            break
        n = try_t2(st)
        if n:
            uses["t2"] += n
            steps["t2"] += 1
            trace.append("t2")
            hardest = max(hardest, "t2", key=order.index)
            continue
        n = try_probe(st, 1)
        if n:
            uses["t3"] += n
            steps["t3"] += 1
            trace.append("t3")
            hardest = max(hardest, "t3", key=order.index)
            continue
        n = try_probe(st, 2)
        if n:
            uses["t4"] += n
            steps["t4"] += 1
            trace.append("t4")
            hardest = max(hardest, "t4", key=order.index)
            continue
        # Stuck: settle the most constrained cell to its solution, as a lucky guess would.
        i = min(st.open_cells(), key=lambda c: len(st.cand[c]))
        target = rot(BASE[lv.tiles[i]], lv.solution[i])
        uses["guess"] += len(st.cand[i]) - 1
        steps["guess"] += 1
        trace.append("guess")
        hardest = "guess"
        st.cand[i] = [target]
    sol = lv.masks_for(lv.solution)
    if [c[0] for c in st.cand] != sol:
        raise RuntimeError(f"{lv.id}: logic engine reached a different solution")
    return uses, steps, trace, hardest, waves


def analyze_level(d):
    lv = Level(d)
    n2 = lv.n * lv.n
    free = [i for i in range(n2) if lv.free(i)]
    pinned = sum(1 for i in lv.locked)
    bits = sum(math.log2(len({rot(BASE[lv.tiles[i]], k) for k in range(4)})) for i in free)
    uses, steps, trace, hardest, waves = solve_logically(lv)
    count, nodes, aborted, _ = count_solutions(lv, 2)
    # Rounds of deduction in a row: how long the chain of reasoning is (the "solution depth").
    depth = len(trace)
    effort = sum(WEIGHTS[k] * v for k, v in uses.items()) + WEIGHTS["round"] * max(0, depth - 1)
    entry = round(waves[0] / max(1, len(free)), 2) if waves else 0.0
    colors = len({c for c in lv.colors if c >= 0})
    return {
        "id": lv.id, "band": d.get("difficulty", {}).get("band", ""), "size": lv.n,
        "rotatable": sum(1 for i in range(n2) if lv.tiles[i] in "ILTc"),
        "free": len(free), "pinned": pinned, "colors": colors,
        "bridges": lv.tiles.count("+"), "receivers": lv.tiles.count("R"),
        "min_moves": min_taps(lv), "par": d.get("par"),
        "search_bits": round(bits, 1), "solver_nodes": nodes, "unique": count == 1 and not aborted,
        "t1_cells": uses["t1"], "t2_elims": uses["t2"], "t3_elims": uses["t3"],
        "t4_elims": uses["t4"], "guesses": steps["guess"],
        "depth": depth, "entry_share": entry, "hardest": hardest, "effort": round(effort, 1),
    }


def label_for(effort):
    name = LABELS[0][1]
    for threshold, label in LABELS:
        if effort >= threshold:
            name = label
    return name


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("pack")
    ap.add_argument("--json")
    ap.add_argument("--csv")
    args = ap.parse_args()
    with open(args.pack, encoding="utf-8") as f:
        pack = json.load(f)
    rows = []
    for k, d in enumerate(pack["levels"]):
        r = analyze_level(d)
        r["index"] = k + 1
        r["label"] = label_for(r["effort"])
        rows.append(r)
        print(f"{r['index']:3d} {r['id']} {r['band']:<10} {r['size']}x{r['size']} free={r['free']:2d} pin={r['pinned']:2d} "
              f"moves={r['min_moves']:2d} bits={r['search_bits']:5.1f} nodes={r['solver_nodes']:6d} "
              f"T1={r['t1_cells']:2d} T2={r['t2_elims']:2d} T3={r['t3_elims']:2d} T4={r['t4_elims']:2d} G={r['guesses']} "
              f"depth={r['depth']:2d} entry={r['entry_share']:.2f} hardest={r['hardest']:<5} effort={r['effort']:6.1f} {r['label']}")
    if args.json:
        with open(args.json, "w", encoding="utf-8") as f:
            json.dump({"weights": WEIGHTS, "labels": LABELS, "levels": rows}, f, indent=1)
    if args.csv:
        with open(args.csv, "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
            w.writeheader()
            w.writerows(rows)


if __name__ == "__main__":
    main()
