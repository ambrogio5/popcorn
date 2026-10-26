# Screenshots

Rendered by `PopcornTests/ScreenshotTests` in CI (run 13 on `main`, commit `7073898`, Xcode 26.6,
iPhone Air simulator, iOS 26.5). Each PNG is a frame of a scene presented at the given point
size, scaled down to 900 px on the long side for the repository. The full-resolution originals
(3x) are in the `screenshots` artifact of that CI run.

Two things to keep in mind when reading them:

- The test renders into a bare `UIWindow`, so the safe-area insets are zero. The HUD sits on the
  very top edge in every picture; on a real phone it moves below the status bar / Dynamic Island.
- Nothing presses a button, so the player stands still at the spawn point.

| Shape              | Points     | Mode      | Menu | Level select | Level 1 | Level 20 | Level 45 | Storm |
|--------------------|------------|-----------|------|--------------|---------|----------|----------|-------|
| iPhone             | 393 × 852  | tall      | [menu](menu-iphone.png) | [levels](levels-iphone.png) | [1p](level1-1p-iphone.png) | [1p](level20-1p-iphone.png) | [1p](level45-1p-iphone.png) | [storm](storm-iphone.png) |
| Duo closed (outer) | 466 × 678  | tall      | [menu](menu-duo-closed.png) | [levels](levels-duo-closed.png) | [1p](level1-1p-duo-closed.png) | [1p](level20-1p-duo-closed.png) | [1p](level45-1p-duo-closed.png) | [storm](storm-duo-closed.png) |
| Duo open (inner)   | 951 × 669  | wide      | [menu](menu-duo-open.png) | [levels](levels-duo-open.png) | [2p](level1-2p-duo-open.png) | [2p](level20-2p-duo-open.png) | [2p](level45-2p-duo-open.png) | [storm](storm-duo-open.png) |
| Duo open, upright  | 669 × 951  | upright   | [menu](menu-duo-open-upright.png) | [levels](levels-duo-open-upright.png) | [1p](level1-1p-duo-open-upright.png) | [1p](level20-1p-duo-open-upright.png) | [1p](level45-1p-duo-open-upright.png) | [storm](storm-duo-open-upright.png) |

Fold mid-game (level 1, two players): [closed](fold-before-closed.png) →
[just unfolded, toast showing](fold-after-open.png) → [1.5 s later](fold-after-open-resumed.png).

## What the pictures show

Works:

- Every scene renders in every shape; nothing is clipped or off-screen.
- Unfolding mid-level shows the "Unfolded — wide arena" toast and keeps every bubble and player at
  the same relative position (compare the fold series).
- Two-player layout on the open Duo: mirrored stick + fire per player, P1 left, P2 right.
- Level select switches from 2 columns (tall) to 4 columns (wide, upright).

Wrong or questionable:

1. **Closed Duo wastes most of its width** (`level1-1p-duo-closed.png`, `storm-duo-closed.png`).
   The 9 × 16 arena is bounded by the short screen, so it is 261 pt wide on a 466 pt display, and
   only 209 pt once the real safe-area insets are subtracted. See the PR description for numbers.
2. **Level 45 knocks a standing player down 2 s in** (`level45-1p-iphone.png`,
   `level45-1p-duo-closed.png`): no player sprite, "Frozen 2s" in the HUD, pink freeze tint. The
   player was hit just after the 1.5 s starting invulnerability ended. `Tools/spawn_sweep.py`
   shows this is common, including levels 3, 5 and 7 in the first city.
3. **Menu bubbles drawn over button text** (`menu-duo-closed.png`, the small bubble on
   "Players: 1"). The decorative bubbles shared a zPosition with the buttons and the view ignores
   sibling order, so the draw order was arbitrary. Fixed in this branch.
4. **Storm can start with its two bubbles overlapping** (`storm-iphone.png`); both spawn at a
   random x near the ceiling with nothing keeping them apart.
5. **Level select on the upright shape floats low** (`levels-duo-open-upright.png`): a 4 × 2 grid
   centred in the space under the title leaves a big empty band above it.
6. **"Frozen Ns" is shown both for the freeze power-up and for the knock-down pause**
   (`level45-1p-iphone.png`), so a knocked-down player reads as having picked something up.
