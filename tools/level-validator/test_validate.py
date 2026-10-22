#!/usr/bin/env python3
"""Tests for the independent validator. Run: python3 -m unittest tools/level-validator/test_validate.py"""
import copy
import itertools
import json
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import validate as v  # noqa: E402

PACK = os.path.join(HERE, "..", "..", "games", "circuit-garden", "puzzles", "levels_v1.json")


class ValidatorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with open(PACK, encoding="utf-8") as f:
            cls.pack = json.load(f)

    def test_shipped_pack_is_valid(self):
        report = v.validate_pack(self.pack, expected_count=100)
        self.assertTrue(report["ok"], [lv for lv in report["levels"] if not lv["ok"]][:3])

    def test_solver_agrees_with_brute_force(self):
        checked = 0
        for d in self.pack["levels"]:
            lv = v.Level(d)
            free = [i for i in range(lv.n * lv.n) if lv.free(i)]
            if len(free) > 8:
                continue
            solutions = set()
            for combo in itertools.product(range(4), repeat=len(free)):
                rots = list(lv.solution)
                for i, k in zip(free, combo):
                    rots[i] = k
                masks = lv.masks_for(rots)
                if v.solved(lv, masks)[0]:
                    solutions.add(tuple(masks))
            count, _, aborted, _ = v.count_solutions(lv, limit=100)
            self.assertFalse(aborted)
            self.assertEqual(count, len(solutions), d["id"])
            checked += 1
        self.assertGreater(checked, 0, "no small levels to brute force")

    def _level(self, idx=20):
        return copy.deepcopy(self.pack["levels"][idx])

    def test_detects_wrong_solution(self):
        d = self._level()
        free = next(i for i, t in enumerate(d["tiles"]) if t in "LTc" and i not in d["locked"])
        d["solution"][free] = (d["solution"][free] + 1) % 4
        errors, _ = v.validate_level(d)
        self.assertTrue(any("solution" in e for e in errors), errors)

    def test_detects_trivial_start(self):
        d = self._level()
        d["start"] = list(d["solution"])
        errors, _ = v.validate_level(d)
        self.assertTrue(any("trivial" in e for e in errors), errors)

    def test_detects_wrong_min_moves(self):
        d = self._level()
        d["min_moves"] += 1
        errors, _ = v.validate_level(d)
        self.assertTrue(any("min_moves" in e for e in errors), errors)

    def test_detects_missing_receiver_color(self):
        d = self._level()
        i = d["tiles"].index("R")
        d["colors"][i] = (d["colors"][i] + 1) % 6
        errors, _ = v.validate_level(d)
        self.assertTrue(errors)

    def test_detects_duplicates_in_pack(self):
        pack = copy.deepcopy(self.pack)
        pack["levels"].append(copy.deepcopy(pack["levels"][-1]))
        report = v.validate_pack(pack)
        self.assertFalse(report["ok"])
        self.assertTrue(any("duplicate" in e for e in report["levels"][-1]["errors"]))

    def test_detects_disconnected_network(self):
        # A 4x4 with a powered pair and a separate unpowered elbow loop.
        d = {
            "format": "circuit-garden-level", "version": 1, "id": "x", "size": 4,
            "tiles": "SR##" "LL##" "LL##" "####",
            "colors": [0, 0] + [-1] * 14,
            "start": [1, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            "solution": [1, 3, 0, 0, 1, 2, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0],
            "locked": [], "min_moves": 0, "par": 4,
        }
        errors, _ = v.validate_level(d)
        self.assertTrue(any("sources" in e for e in errors), errors)


if __name__ == "__main__":
    unittest.main()
