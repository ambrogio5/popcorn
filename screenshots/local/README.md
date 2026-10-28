# Review of `main` at `59b9941` (28 October 2026)

No Mac was available for this review: the session ran in a Linux container with no Xcode and no
simulator. So instead of simulator screenshots these are the frames that `ScreenshotTests` rendered
in CI run 20 on `main` (commit `59b9941`, Xcode 26.6, iPhone Air simulator, iOS 26.5, 27 tests
green), downloaded from the run's `screenshots` artifact and scaled to 900 px on the long side.
The pure-Swift engine (`Popcorn/Engine` plus `GameLayout`) was also built with a Linux Swift 6.2
toolchain and its 24 non-screenshot tests pass there; the same build was used to drive a scripted
player through every level for the numbers below.

Same caveats as `../README.md`: the test renders into a bare `UIWindow`, so safe-area insets are
zero (the HUD sits on the top edge), and nobody presses a button, so the player stands at the spawn.

| Shape              | Points     | Mode in these frames | Menu | Level select | Level 1 | Level 20 | Level 45 | Storm |
|--------------------|------------|----------------------|------|--------------|---------|----------|----------|-------|
| iPhone             | 393 × 852  | tall                 | [menu](menu-iphone.png) | [levels](levels-iphone.png) | [1p](level1-1p-iphone.png) | [1p](level20-1p-iphone.png) | [1p](level45-1p-iphone.png) | [storm](storm-iphone.png) |
| Duo closed (outer) | 466 × 678  | tall (see 1 below)   | [menu](menu-duo-closed.png) | [levels](levels-duo-closed.png) | [1p](level1-1p-duo-closed.png) | [1p](level20-1p-duo-closed.png) | [1p](level45-1p-duo-closed.png) | [storm](storm-duo-closed.png) |
| Duo open (inner)   | 951 × 669  | wide                 | [menu](menu-duo-open.png) | [levels](levels-duo-open.png) | [2p](level1-2p-duo-open.png) | [2p](level20-2p-duo-open.png) | [2p](level45-2p-duo-open.png) | [storm](storm-duo-open.png) |
| Duo open, upright  | 669 × 951  | upright              | [menu](menu-duo-open-upright.png) | [levels](levels-duo-open-upright.png) | [1p](level1-1p-duo-open-upright.png) | [1p](level20-1p-duo-open-upright.png) | [1p](level45-1p-duo-open-upright.png) | [storm](storm-duo-open-upright.png) |

Fold mid-game (level 1, two players): [closed](fold-before-closed.png) →
[just unfolded, toast showing](fold-after-open.png) → [1.5 s later](fold-after-open-resumed.png).

## What works

- Every scene renders in every shape with nothing clipped or off-screen; the arena frame, HUD and
  control strip never overlap.
- The fold series: the "Unfolded — wide arena" toast appears, the bubble and both players keep
  their relative positions, the second player's controls appear.
- Fixes from the previous review hold: Storm's two starters are in opposite lanes
  (`storm-duo-closed.png`, `storm-duo-open.png`), nobody is knocked down 2 s into level 45 any
  more, and the HUD no longer says "Frozen" after a hit.
- Level select: 2 columns tall, 4 columns wide and upright, tiles large enough to tap.

## What is wrong or questionable

1. **The closed-Duo frames do not show what the device will show.** They still have the tall 9 × 16
   strip (261 pt wide on a 466 pt screen). That is only because the test renders with zero
   safe-area insets: `GameLayout.bestMode` picks the wide arena for 466 × 678 once the real insets
   (59 / 34 pt in `ArenaMappingTests`) are subtracted, since the wide arena is then 1.96× bigger,
   over the 1.4 `fillAdvantage` threshold; with zero insets it is only 1.25× bigger and loses. So
   the cover screen should be fine on the device, but nobody has seen it yet, and the screenshot
   test cannot show it until it can inject insets. Suggested: give `BaseScene` an optional inset
   override used only by `ScreenshotTests`, and render the Duo shapes with realistic insets.
2. **Standing still at the spawn gets you hit the instant invulnerability ends.** With the engine's
   current numbers (2.0 s bubble grace, 2.5 s player invulnerability) a player who does nothing is
   hit at exactly 2.5 s in 22 of the 384 level/shape/player-count combinations, because a bubble is
   already sitting on the spawn box when the shield drops. Solo on a phone that is levels 7 (Ice
   Rink), 16 (Derby) and 27 (Papyrus); level 1 follows at 3.6 s. Overall a standing player is hit
   within 8 s in 299 of 384 combinations, 52 of the 64 solo phone levels, 25 of those before 3 s.
   `Tools/spawn_sweep.py` had drifted from the engine (it still used 1.5 s / 1.0 s and did not
   scale horizontal speed for wider arenas); this branch brings it back in step, and its output now
   matches a sweep run through the real engine case for case (299 rows, same times to 0.1 s).
3. **A chase-and-shoot bot clears only 37 of 64 levels solo on the phone shape** (36 of them under
   par; it never climbs ladders, so bubbles trapped above platforms defeat it). That is expected for
   a dumb bot, but it also gets hit in the first 5 s on 38 levels despite dodging, which points the
   same way as item 2. Level 1 takes the bot 7.0 s with one hit (par 50 s).
4. **Decorative menu bubbles still read through the button labels** (`menu-duo-closed.png`, the
   small bubble on "Players: 1"; `menu-duo-open.png`, under "Players: 1"). They are behind the
   buttons now, but the secondary buttons are translucent, so the bubble shows through the text.
5. **Level select on the upright shape floats low** (`levels-duo-open-upright.png`): the 4 × 2 grid
   is centred in the space under the title, leaving an empty band of about 180 pt. Still open from
   the previous review.
6. **Storm's two starters still cross in the middle a second in** (`storm-duo-open-upright.png`,
   `storm-iphone.png`): they spawn apart but with random directions, so half the time they head
   straight at each other and overlap near the centre at 1–2 s.
7. **One-player controls on the wide shape sit far from the edges** (`storm-duo-open.png`): the stick
   and fire hints are drawn at 25 % and 75 % of the width, 238 pt in from each edge of the open Duo.
   The touch zones are the whole left and right halves and the stick floats to the touch, so it
   plays fine, but the hints suggest a reach that is not needed.
8. **A level started on the closed Duo probably begins with a silent 1 s freeze.** `GameScene.init`
   builds the model with zero insets (tall), then the first `layoutDidChange` sees the real insets,
   switches to wide and calls `GameModel.relayout`, which sets the 1 s fold pause even though this
   is not a fold. Not visible in these frames (zero insets); needs a device or the override from
   item 1 to confirm.

## Engine numbers (phone shape, 9 × 16 units)

| Bubble | Radius | Wall to wall | Bounce apex | Bounce period |
|--------|--------|--------------|-------------|---------------|
| large  | 1.40   | 2.2 s        | 82 % of height | 2.6 s     |
| medium | 0.95   | 2.1 s        | 64 %        | 2.3 s         |
| small  | 0.60   | 2.0 s        | 46 %        | 2.0 s         |
| tiny   | 0.35   | 1.7 s        | 30 %        | 1.6 s         |

Harpoon floor to ceiling 0.73 s (rapid 0.46 s); player wall to wall 1.35 s; half-height ladder
climb 2.0 s. With the width scaling from #8 a large bubble crosses the wide arena in 2.65 s and the
upright one in 2.46 s, so the three shapes feel the same. These all look sane for Pang; nothing in
the numbers suggests the speeds themselves need touching, only the starts (item 2).

## Suggested tweaks

1. **Safe starts.** Make `Tools/generate_levels.py` reject any level where a standing player is hit
   within 4 s in any shape (reuse `spawn_sweep.first_hit`), regenerate, and mirror the rule in
   `LevelValidator` so `LevelLoaderTests` guards it. Alternatively, or as well, let a bubble's
   `spawnGrace` not expire while it overlaps a player who has not moved yet, up to 4 s.
2. **Screenshots with insets.** `ScreenshotTests` renders each Duo shape with the expected insets
   so the cover screen's wide arena is actually pictured.
3. **Storm starters move apart:** left lane `dir = -1`, right lane `dir = +1` in `GameModel.init`.
4. **Menu buttons:** raise `Palette.secondaryButton` alpha to about 0.85, or draw the menu bubbles
   at 0.4 alpha when they pass under the button column.
5. **Upright level select:** anchor the grid 40 pt under the city title instead of centring it.
6. **Wide one-player hints:** place the stick base 110 pt from the left edge and the fire button
   110 pt from the right edge of the strip (the two-player layout already does this).
7. **No pause on the first layout:** give `GameModel.relayout(to:)` a `pause: Bool` parameter and
   pass `false` from `GameScene.layoutDidChange` when `model.elapsed == 0`.
