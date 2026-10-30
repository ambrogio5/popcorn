# Popcorn

A Pang-style bubble shooter for iPhone, built for the foldable iPhone Duo and regular iPhones.
Shoot harpoons up, split bubbles until they pop, climb ladders, don't get touched. Everything is
open from the start: 64 levels across 8 cities, an endless Storm mode, two-player co-op. No ads,
no coins, no timers, nothing to buy.

Swift + SpriteKit, no dependencies.

## Build and run

Requirements: Xcode 16 or newer, iOS 18 or newer on the device or simulator.

1. Open `Popcorn.xcodeproj`.
2. Pick a simulator (or your phone; set your team under *Signing & Capabilities* the first time).
3. Run (⌘R). Tests: ⌘U.

From the command line:

```sh
xcodebuild -scheme Popcorn -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme Popcorn -destination 'platform=iOS Simulator,name=iPhone 17' test
```

If the project file does not open on your Xcode version, regenerate it from the spec:

```sh
brew install xcodegen
xcodegen generate
```

The project uses Xcode's synchronized folders, so adding a file to `Popcorn/` is enough; there is
no file list to maintain.

## How the fold is handled

The game never asks the device whether it is folded. It reads the view's size and derives a
`LayoutMode` from the aspect ratio and the size in points (`Popcorn/Engine/Arena.swift`):

| Screen                                   | Window (points) | Aspect (w/h) | Mode   | Arena         |
|------------------------------------------|-----------------|--------------|--------|---------------|
| Regular iPhone (portrait)                | 393 × 852 etc.  | ≈ 0.46       | `tall` | 9 × 16 units  |
| Duo closed, outer display                | 466 × 678       | ≈ 0.69       | `tall` | 9 × 16 units  |
| Duo open, inner display (landscape)      | 951 × 669       | ≈ 1.42       | `wide` | 16 × 12 units |
| Duo open, turned upright; iPad portrait  | 669 × 951       | ≈ 0.70       | `upright` | 12 × 16 units |
| iPad landscape, any landscape screen     | —               | > 0.95       | `wide` | 16 × 12 units |

Point sizes are those reported by the iPhone Duo simulator in Xcode 27.1 (see `docs/RESEARCH.md`).
The outer and inner displays have almost the same aspect ratio, so the rule for the big portrait
shapes is "squarer than 0.6 *and* at least 600 points across" rather than aspect alone. The two constants at the top of
`LayoutMode` are the only thing to tune if Apple changes the numbers.

Levels are authored in normalised 0…1 coordinates and mapped into whichever arena is active, so
every level works in both shapes. When the size changes mid-game (`GameScene.layoutDidChange`),
`GameModel.relayout(to:)` moves every bubble, player and pickup to the same normalised position in
the new arena, drops in-flight harpoons, and pauses the simulation for a second with a toast so
nobody gets hit during the transition.

If Apple publishes a fold-state API, it belongs in `LayoutMode.forSize` as a hint; nothing else
needs to know.

### Testing the Duo layout without a Duo

- **Best:** Xcode 27.1 ships an iPhone Duo simulator (needs the iOS 27.1 runtime, a separate
  ~8 GB download). Device Hub has pose buttons — Closed, Book, Open, Rotate — so you can fold and
  unfold the running game. First boot is slow.
- **Tall mode without it:** any iPhone simulator.
- **Wide mode without it:** an iPad simulator approximates the open Duo. Rotate it to see the wide
  arena in both orientations.
- **Live fold without it:** run on an iPad simulator and use Split View / Stage Manager to resize
  the window (a half-width iPad window is tall, full width is wide). You should
  see the "Unfolded — wide arena" toast, bubbles keep their relative positions, and the second
  player's controls appear or disappear.
- **Keyboard in the simulator:** arrows + space for player 1, WASD + F for player 2 (⌘K shows the
  software keyboard if hardware keyboard input is off).

## Controls

- Bottom-left: a floating stick (drag left/right to run, up/down for ladders).
- Bottom-right: fire. Tapping anywhere on the arena also fires.
- Two players: the strip splits into two mirrored sets, player 1 left, player 2 right.
- Game controllers: first controller is player 1, second is player 2. A / right trigger fires.

## Playtest checklist

- [ ] Clear level 1 solo on an iPhone simulator.
- [ ] Clear level 1 in two-player on an iPad simulator (Menu → Players: 2).
- [ ] Trigger each bubble type: armored (city 3+), triple (city 4+), flipped (city 5+),
      lightning (city 6+), golden (any city from Milano on).
- [ ] Pick up each power-up: double shot, sticky line, rapid fire, shield, freeze.
- [ ] Get hit: the room freezes briefly, you respawn, the level keeps its state.
- [ ] Resize mid-game and watch the arena reshape.
- [ ] Confirm there is no purchase, ad, timer or energy anywhere. (There isn't.)

## Game Center (optional)

`Popcorn/App/GameCenter.swift` submits the Storm score and the total star count to two
leaderboards and reports a few achievements. It is entirely optional: when the player is not
signed in to Game Center, has declined the sign-in, or the capability is missing, every call is a
no-op and the game behaves exactly as before. The menu's *Leaderboards* button only appears once
the player is signed in.

To switch it on for your own build:

1. In Xcode, select the Popcorn target → *Signing & Capabilities* → **+ Capability** → *Game
   Center*. (This adds the entitlement; it is deliberately not checked in.)
2. In App Store Connect, under the app's *Game Center* section, create these IDs exactly:

   | Kind        | ID                        | Meaning                                       |
   |-------------|---------------------------|-----------------------------------------------|
   | Leaderboard | `storm.best`              | Best Storm score                              |
   | Leaderboard | `levels.totalstars`       | Total stars across all 64 levels (max 192)    |
   | Achievement | `city.<index>.threestars` | All 8 levels of city `<index>` (0…7) at 3 stars |
   | Achievement | `storm.1000`              | Storm score of 1,000 (reported as progress)   |
   | Achievement | `storm.10000`             | Storm score of 10,000 (reported as progress)  |

The IDs live in `GameCenter.Leaderboard` and `GameCenter.Achievement`; change them there if you
prefer other names in App Store Connect. Test with a sandbox Game Center account on a device or
simulator (*Settings → Game Center*).

## Localization

English is the development language; Italian, German and French ship alongside it. Every
user-facing string goes through `String(localized: "…")` with the English text as the key, and
the translations live in one String Catalog, `Popcorn/Localizable.xcstrings`. Level and city
names in `Content/*.json` are proper nouns and stay as they are, as does the title "POPCORN".

To add a language:

1. Open `Popcorn/Localizable.xcstrings` in Xcode.
2. Press **+** at the bottom of the editor and pick the language.
3. Fill in the new column. Keys with `%lld` (a number) or `%@` (already formatted text) must keep
   those placeholders in the same order.

To add a string: write `String(localized: "New text")` in Swift and build once; Xcode adds the
key to the catalog (`SWIFT_EMIT_LOC_STRINGS` is on) and marks it as needing translation. Test a
language from the scheme's *Options → App Language*, or by changing the simulator's language.

## Project layout

```
Popcorn/
  App/          AppDelegate, SceneDelegate, GameViewController (SKView host, orientation rules)
  Engine/       Pure Swift simulation: Arena, Level + validator, GameModel, LevelLoader, Progress
  Layout/       GameLayout — screen points for the arena, HUD and controls
  Scenes/       Menu, level select, game scene, HUD
  Rendering/    Palette and TextureFactory (art from Assets.xcassets, Core Graphics placeholders otherwise)
  Input/        Touch controls, game controller + keyboard
  Audio/        SoundBank, Haptics, generated .wav placeholders
  Content/      levels.json (64 levels), cities.json
PopcornTests/   Arena mapping, bubble splitting, level validation
Tools/          Python generators for levels, sounds and the icon
```

## Content pipeline

```sh
python3 Tools/generate_levels.py   # rewrites Content/levels.json + cities.json, validates them
python3 Tools/generate_audio.py    # rewrites the placeholder sounds
python3 Tools/make_icon.py         # rewrites the placeholder app icon (needs Pillow)
```

`generate_levels.py` mirrors `LevelValidator` in Swift; `LevelLoaderTests` checks the shipped
JSON against the Swift rules, so the two cannot drift silently.

## Design notes

- Bubbles bounce to a fixed apex per size, as in Pang; smaller bubbles are faster.
- Getting hit never resets the level. The bubbles freeze for a moment, you come back, the
  checkpoint is wherever you were. Deaths only cost a star.
- Stars: one for finishing, one for no hits, one for beating par.
- Combos: pops within 1.5 s chain up to ×8 and the pop sound rises through a scale.
- Lightning bubbles hit everything within 3.5 units; flipped bubbles fall upward and their
  children stay flipped; golden bubbles always drop a power-up; plain pops drop one 6% of the time.
