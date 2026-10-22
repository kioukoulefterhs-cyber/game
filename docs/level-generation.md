# Level generation and validation

## Pipeline (`CGGenerator`, `games/circuit-garden/scripts/puzzle/generator.gd`)

1. **Seeded RNG.** `RandomNumberGenerator` (PCG32) seeded with the level seed. The global RNG
   and `Array.shuffle()` are never used, so a seed reproduces the same level everywhere.
2. **Blocked cells** are placed at random while the open cells stay connected.
3. **Cross cells** are interior cells whose four neighbours are open.
4. **Sources** (one per color) are placed away from crosses and from each other.
5. **Carve a solved board.** Randomized Kruskal over (cell, channel) nodes builds a spanning
   forest with one tree per source. Constraints: a source has degree 1, a normal cell has at
   most degree 3 (a tee), cross channels always pass straight through, and two trees that
   both hold a source are never merged. A carve where any node is left without a source
   is rejected and the next attempt draws from the same RNG stream.
6. **Tiles from degrees.** Degree 1 becomes a receiver (share set by `receiver_ratio`, at least
   one per color) or a cap, degree 2 a straight or elbow, degree 3 a tee.
7. **Scramble** every rotatable tile to a random rotation.
8. **Uniqueness.** `CGSolver` searches all rotations (row-major backtracking with
   neighbour-consistency pruning). While it finds two solutions, the generator pins a tile
   where they differ to its intended rotation. In practice the rules (no leaks, exactly one
   source per network) are strong enough that almost no launch level needs a pin (one does).
9. **Rejection rules** (the attempt is discarded):
   * start already solved, or `min_moves < max(3, free_tiles * min_scramble)`;
   * share of tiles fixed by local constraints alone `>= max_forced_ratio` (too trivial);
   * solver node limit reached (uniqueness unproven).

## Acceptance criterion (what "valid level" means)

A level ships only if **both** independent solvers prove it has **exactly one solution** under
mask equivalence (docs/puzzle-rules.md), the stored solution is that solution, the start is not
solved, `min_moves` and `par` recompute exactly, and each color has one source and at least one
receiver. We do not claim more than this: uniqueness is proven per level by exhaustive search,
not guaranteed by construction.

## Difficulty

Measured, not guessed: `tools/level-analyzer/analyze.py` solves each level with a human-style
logic engine and scores its reasoning effort (method and results in `docs/difficulty/README.md`).
The generator's own `difficulty.score` is only a rough heuristic kept for reference.

Each shipped level stores in `difficulty`: `band`, `params` (exact generator settings, so the level
reproduces from its seed), `effort`, `label` (Easy/Medium/Hard/Expert), `hardest` technique needed,
`depth` (rounds of deduction) and `kept_from_v1`.

## Campaign

`games/circuit-garden/puzzles/curriculum.json` (version 2) defines seven bands, each with a count,
an effort range and one or more generator variants. `tools/level-generator/build_campaign.py`:

1. dumps candidates for every variant with Godot (`tools/dump_candidates.gd`, seeds from
   `seed_base + variant * 1000000`);
2. adds the band's levels from the first pack (`tools/level-generator/archive/`) when `keep_v1` is set;
3. measures every candidate and picks levels at evenly spaced effort targets, never below the
   previous level's effort, preferring first-pack levels when they are within 1 effort point;
4. re-validates every pick with the independent validator and writes `levels_v1.json`.

```
tools/level-generator/generate.sh            # Linux/macOS (about 2 minutes on 4 cores)
.\tools\level-generator\generate.ps1 -Godot <path to Godot console exe>   # Windows
```

The result is deterministic for the same curriculum, archive and engine version.

## Independent validator

`tools/level-validator/validate.py` re-implements the rules in Python with a different search
(most-constrained cell first, edge-state propagation). It checks schema, solution, uniqueness,
triviality, `min_moves`/`par`, colors, duplicate ids and puzzles, and campaign size order.
Its own tests (`python3 -m unittest tools/level-validator/test_validate.py`) include a
brute-force cross-check on every level with 8 or fewer free tiles.
