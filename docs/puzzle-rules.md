# Circuit Garden: formal puzzle rules

These rules are the single source of truth. `games/circuit-garden/scripts/puzzle/board.gd`
(game) and `tools/level-validator/validate.py` (independent validator) both implement them.

## Board

* A board is an `N x N` grid, `N` in {4, 5, 6, 7}.
* Each cell holds exactly one tile. Directions are N, E, S, W with bit values
  N=1, E=2, S=4, W=8. A tile's *mask* is the set of directions it is open toward.

## Tiles

| Tile      | Base mask      | Rotatable | Channels                         |
|-----------|----------------|-----------|----------------------------------|
| empty     | none           | no        | none                             |
| blocked   | none           | no        | none (a rock; nothing connects)  |
| straight  | N+S            | yes       | one: {all openings}              |
| elbow     | N+E            | yes       | one                              |
| tee       | N+E+S          | yes       | one                              |
| cross     | N+E+S+W        | no (symmetric) | **two independent**: {N,S} and {E,W} |
| cap       | N              | yes       | one (a dead-end bud)             |
| source    | one direction  | no        | one, carries the source's color  |
| receiver  | one direction  | no        | one, demands one color           |

* A tap rotates a rotatable tile 90 degrees clockwise. There is no counter-clockwise tap;
  three taps equal one counter-clockwise turn.
* A *locked* tile is a rotatable tile shown with a pin. It cannot be rotated. Locks come
  from the level file (to guarantee uniqueness) or from a used hint.

## Connections

* Two orthogonally adjacent cells are **linked** across their shared edge when both are
  open toward that edge.
* An opening that is not linked (it faces the border, an empty or blocked cell, or a
  neighbour that is closed on that side) is a **leak**.
* A *node* is a (cell, channel) pair. Links join nodes; a connected set of nodes is a
  **network**.
* Energy never turns inside a cross: its N-S and E-W channels belong to different
  networks unless they are joined somewhere else on the board.

## Energy and colors

* Each source has a color. A network's *colors* are the colors of the sources in it.
* A network with exactly one source is **powered** in that color. Energy animates through
  every node of a powered network.
* A network with sources of two or more colors (or two sources) is **shorted**. It is
  drawn with sparks and is never part of a solution.
* A receiver is **satisfied** when its network is powered in the receiver's own color.

## Win condition

The board is solved when all of the following hold:

1. There are no leaks.
2. Every network contains exactly one source.
3. Every receiver is satisfied.

Rule 2 means every tile must be part of a powered circuit: no floating loops or unused
pieces. Color is always shown with a matching shape (circle, square, triangle, diamond,
hexagon, star) so the rules never depend on color vision.

## Solution equivalence and uniqueness

Two boards are the same solution when every cell has the same *mask* (so a straight
rotated 180 degrees equals the original). A level is **accepted** only when an exhaustive
solver proves exactly one solution under this equivalence, given its locked tiles.
The generator adds locks until this holds; both the in-game solver and the independent
Python validator must agree. See `docs/level-generation.md`.

## Moves, par and stars

* Each tap is one move. Undo removes the last tap and its move. Restart returns to the
  original scramble with zero moves.
* `min_moves` is the sum, over rotatable unlocked tiles, of the fewest clockwise taps
  that bring the tile to its solution mask. This is an exact lower bound.
* `par = min_moves + N`.
* Stars: 3 when `moves <= par` and no hints were used; otherwise 2 when
  `moves <= 2 * par` and at most one hint was used; otherwise 1.
