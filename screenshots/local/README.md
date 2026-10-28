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


---

# Simulator check of `main` at `59b9941` (28 October 2026, on a Mac)

Xcode 27.1 (27A9275), iPhone Duo simulator on iOS 27.1, iPhone 18 Pro Max simulator on iOS 27.0.
`xcodebuild … build test` on the iPhone 18 Pro Max: **TEST SUCCEEDED, 27 tests, 0 failures** (24
engine/layout tests plus the 3 `ScreenshotTests`). Everything below was played and captured on the
running game with `xcrun simctl io … screenshot`, scaled to 900 px, in `sim/`. Taps and drags went
through Device Hub, so the player mostly stands at the spawn and fires; nothing in this section
required a code change to observe, except where it says so.

| Shape                      | Points     | Mode seen | Captures |
|----------------------------|------------|-----------|----------|
| iPhone 18 Pro Max          | 440 × 956  | tall      | [menu](sim/iphone-menu.png), [levels](sim/iphone-levels.png), [level 1 at 4 s](sim/iphone-level1-1p.png), [level 1 cleared](sim/iphone-level1-results.png), [storm at 4 s](sim/iphone-storm.png) |
| Duo closed (cover)         | 466 × 678  | **tall**  | [menu](sim/duo-closed-menu.png), [levels](sim/duo-closed-levels.png), [levels, Milano](sim/duo-closed-levels-milano.png), [level 1](sim/duo-closed-level1-1.6s.png), [storm](sim/duo-closed-storm.png) |
| Duo open (inner, landscape)| 951 × 669  | wide      | [menu](sim/duo-open-menu.png), [menu, 2 players](sim/duo-open-menu-2p.png), [level 25, 1p](sim/duo-open-level25-1p.png), [level 25, 2p](sim/duo-open-level25-2p.png) |
| Duo open, upright          | 669 × 951  | upright   | [level 25, 2p](sim/duo-open-upright-level25-2p.png) |

## Check A: the closed Duo does not pick the wide arena. Refuted.

The cover screen plays the **tall 9 × 16 strip**, 242 × 430 pt on a 466 × 678 screen, with
about 100 pt of empty background either side ([level 1](sim/duo-closed-level1-1.6s.png),
[level 7](sim/duo-closed-level7-2.1s.png), [storm](sim/duo-closed-storm.png)). Item 1 above assumed
the phone-style insets from `ArenaMappingTests` (59 / 34 pt). The simulator's cover screen reports
(measured with a one-line `NSLog` in `layoutDidChange`, not committed):

```
size={466, 678} insets={top 0, left 0, bottom 34, right 84}
```

No top inset at all, and an **84 pt right inset** for the camera cut-out that runs the full height.
With those numbers `bestMode` gets:

| Shape on the cover screen   | Arena (pt)  | Unit (pt) | Area ÷ tall |
|-----------------------------|-------------|-----------|-------------|
| tall 9 × 16 (chosen)        | 242 × 430   | 26.9      | 1.00        |
| wide 16 × 12                | 366 × 274   | 22.9      | 0.97        |
| upright 12 × 16             | 322 × 430   | 26.9      | 1.33        |

The tall arena is height-limited (678 − 34 − 48 HUD − 150 controls − 16 margins = 430 pt), so the
narrow strip is not the width's fault; and once 84 pt are reserved on the right, the wide arena is
no bigger than tall, so `fillAdvantage` never fires. If the camera inset is applied to the HUD
only and the arena and control strip use the full 466 pt (the cut-out is a 40 pt circle in the
top-right corner, nowhere near either), the wide arena becomes 450 × 338 pt, unit 28.1, 1.46× tall,
and the existing 1.4 rule picks it as #8 intended. Keeping the inset and lowering `fillAdvantage`
to 1.3 would instead pick upright (322 × 430). The unit sizes say which is better for play: 28.1 pt
wide against 26.9 pt today; the iPhone 18 Pro Max plays tall at about 34 pt.

Also on the cover screen: the level select's `›` button sits at `size.width − insets.right − 44` =
338 pt while the city title is centred on the full width, so the two touch
([Celerina](sim/duo-closed-levels.png), [Milano](sim/duo-closed-levels-milano.png)); and two-player
mode squeezes four controls into the 382 pt that remain
([2p controls on the cover](sim/duo-closed-level25-2p-fullscreen-off.png)).

## Check B: no silent pause at the start of a level. Not reproduced.

Frames after tapping level 1 on the cover screen:
[+0.7 s](sim/duo-closed-level1-0.7s.png) timer 1s, bubble moving;
[+1.6 s](sim/duo-closed-level1-1.6s.png) timer 2s; [+2.6 s](sim/duo-closed-level1-2.6s.png) timer 3s.
The first `layoutDidChange` keeps the tall mode (see A), so `relayout` is never called and the
`foldPause` path is not reached. The same holds when the game is launched open (wide at init, wide
after insets). The pause would only appear if a first layout pass changed the mode, which with
the measured insets happens nowhere; a branch that passes `pause: false` from the pre-first-frame
path (with a unit test, 28 tests green) is prepared locally but not opened as a PR, since
nothing observable is broken.

## New: unfolding does not resize the game (fixed in #11)

With `UIRequiresFullScreen` set, opening the Duo during a level keeps the app's 466 × 678
cover-screen window and letterboxes it in the middle of the 951 × 669 inner display:
[unfolded, toast](sim/duo-unfold-open-toast.png) → [2 s later](sim/duo-unfold-open-2s-later.png).
`layoutDidChange` sees the same size with the camera inset gone, switches to the wide arena inside
that small window and shows "Unfolded — wide arena", but the inner display is mostly black bars.
The same code with the key off resizes to the full inner display:
[unfolded, toast](sim/duo-unfold-fullscreen-off-toast.png) →
[2 s later](sim/duo-unfold-fullscreen-off-2s-later.png), and folding back still works
([closed again](sim/duo-fold-closed-fullscreen-off.png)). Launching the app while already open
was always full size, which is why the menu and level captures above look right. The research
note called the key harmless; #11 turns it off and corrects the note.

Folding closed works either way: [Folded — tall arena](sim/duo-fold-closed-toast.png), bubbles at
the same relative positions. Two players appear side by side on the open device, each with their
own stick and fire, and the upright shape gives the 12 × 16 arena with both players.

## Standing still: the start hits are real, and respawns are worse

Solo on the cover screen (phone shape), nobody touching the controls:

| Level | Bubble on the player | "Knocked down" shown | Respawn |
|-------|----------------------|----------------------|---------|
| 1     | –                    | by 4.0 s (iPhone)    | hit 10× in a 74 s clear |
| 7     | [2.1 s](sim/duo-closed-level7-2.1s.png), [2.5 s](sim/duo-closed-level7-2.5s.png) | [3.0 s](sim/duo-closed-level7-3.0s.png) | [5.4 s](sim/duo-closed-level7-5.4s.png) clear |
| 16    | [2.4 s](sim/duo-closed-level16-2.4s.png) | [2.9 s](sim/duo-closed-level16-2.9s.png) | [4.3 s](sim/duo-closed-level16-4.3s.png) **under the same bubble** |
| 27    | [2.4 s](sim/duo-closed-level27-2.4s.png) | [2.9 s](sim/duo-closed-level27-2.9s.png) | [4.8 s](sim/duo-closed-level27-4.8s.png) **under a bubble** |

Item 2's prediction of a hit at exactly 2.5 s on 7, 16 and 27 holds (the label appears on the next
captured frame). What the sweep did not show: the knock-down freezes the bubbles where they are,
so on 16 and 27 the player comes back up inside the bubble that hit them and is hit again as soon
as the respawn invulnerability lapses. Storm on the iPhone also knocks a standing player down by
4 s ([storm at 4 s](sim/iphone-storm.png)). After a fold or unfold the same thing happens: the 1 s
pause plus 1.5 s of invulnerability is shorter than the time a bubble needs to come down on the
player, so [2 s after folding](sim/duo-fold-closed-2s-later.png) and
[2 s after unfolding](sim/duo-unfold-open-2s-later.png) both show "Knocked down".

Level 1 was cleared on the iPhone by standing at the spawn and tapping the arena: 74.4 s against
a 50 s par, one star, 10 knock-downs, score 6,550. Harpoon speed, bounce heights and the
bubble sizes all felt right in the captures; the start and the respawns are what need work.

## Earlier items, confirmed or not

- Item 4, bubbles through the translucent buttons: confirmed on both
  ([iPhone menu](sim/iphone-menu.png), [cover menu](sim/duo-closed-menu.png)).
- Item 7, one-player hints at 25 % / 75 % on the wide shape: confirmed
  ([level 25, 1p](sim/duo-open-level25-1p.png)).
- Item 6, Storm starters crossing: not measured; the standing-player hit at 4 s is the visible
  effect.
- Item 5, upright level select floating low: not captured this time.
- Item 1 and item 8: see A and B above; both rested on insets the device does not report.

## Recommended tweaks, in order

1. **Merge #11** (`UIRequiresFullScreen` off) so the Duo actually resizes when opened.
2. **Cover-screen layout.** In `GameLayout.compute`, apply `insets.left/right` to `hudRect` only
   and let the arena and `controlsRect` span the full width: with the measured insets the cover
   then plays wide at 450 × 338 pt (unit 28.1) instead of the 242 × 430 strip (unit 26.9). Add
   `UIEdgeInsets(top: 0, left: 0, bottom: 34, right: 84)` to `ArenaMappingTests` and
   `ScreenshotTests` as the Duo-closed case; the 59 / 34 case is a phone, not the cover screen.
   Alternative that keeps a portrait feel: `fillAdvantage` 1.4 → 1.3 and the cover plays upright,
   322 × 430 pt. Done on branch `claude/cover-screen-layout`:
   [level 25, two players, cover screen](sim/duo-closed-level25-2p-cover-layout.png) now plays wide. The level-select title should be centred on the inset area (x = 191 on the cover)
   or the `›` moved to `size.width − 44`.
3. **Safe starts and respawns.** `startInvulnerability` 2.5 → 4.0 s and `startGrace` 2.0 → 3.0 s;
   on respawn, keep the player invulnerable while any bubble overlaps the spawn box (cap 4 s),
   or move the frozen bubbles one radius away from the spawn before the player comes back. After
   `relayout`, raise the invulnerability floor from 1.5 to 2.5 s. Then the level-generator rule
   from item 2 above.
4. **Two players on the cover screen.** 382 pt is too little for four controls; either make the
   stick zones 120 pt and the fire zones 71 pt (fire also works anywhere on the arena), or show
   "Open the phone for two players" and keep one-player controls until the device is open.
5. Items 4 (button alpha 0.85) and 7 (hints 110 pt from the edges) as written above.
6. Screenshot tests with real insets, now with the measured values rather than guessed ones.

## Simulator notes

- Xcode 27.1 has no Simulator.app; the device windows live in Device Hub (`Xcode.app/Contents/
  Applications/DeviceHub.app`), with Closed / Partially Open / Open and Rotate buttons for the Duo.
  A booted device that is not shown in a Device Hub window renders a few frames and then blocks
  waiting for screen surfaces, so `simctl io screenshot` repeats the same frame and taps never
  complete; open the device in Device Hub first.
- The Duo's cover screen is `--display=1` (1398 × 2034 px), the inner display `--display=3`
  (2007 × 2853 px, landscape framebuffer when open). After a cold boot the inner display stayed
  black in the Open pose until the device was rebooted once with Device Hub already set to Open.
- Three booted simulators on a 16 GB Mac swap the machine into the ground (load average above
  500, every `simctl` call timing out); one at a time is fine.
