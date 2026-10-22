# Level JSON format (version 1)

A pack file: `{"format": "circuit-garden-pack", "version": 1, "generator": "forest-v1", "levels": [...]}`.

Each level:

| Field | Type | Meaning |
|-------|------|---------|
| `format`, `version` | `"circuit-garden-level"`, `1` | Schema id. Readers reject other versions. |
| `id` | string | Stable id, e.g. `cg-001`. Save data keys progress by id. |
| `size` | int | Board side, 4 to 7. |
| `seed` | int | Generator seed (reproduces the level with the same params). |
| `tiles` | string, `size*size` chars, row-major | `.` empty, `#` blocked, `I` straight, `L` elbow, `T` tee, `+` cross, `c` cap, `S` source, `R` receiver. |
| `colors` | int[] | Color index for `S`/`R`, `-1` elsewhere. |
| `start` | int[] | Scrambled rotation (0-3 clockwise quarter turns from the base mask). |
| `solution` | int[] | Rotation of the unique solution. |
| `locked` | int[] | Cells pinned to their solution rotation. |
| `min_moves`, `par` | int | Exact fewest taps; `par = min_moves + size`. |
| `difficulty` | object | Heuristic metrics (score, free_tiles, locks, forced_tiles, search_nodes, colors, crosses, band). |

Base masks (bits N=1, E=2, S=4, W=8): straight N+S, elbow N+E, tee N+E+S, cross all,
cap/source/receiver N. Changing the format means bumping `version` and keeping a reader for
the old one, because saved progress refers to level ids.
