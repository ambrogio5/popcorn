# Research notes: building a Pang-style game for iPhone Duo

Gathered 26 October 2026, three days after the iPhone Duo went on sale. Apple's own pages were the
primary source where they could be read; measurements and API names from third parties are marked
as such.

## 1. What Apple has published for the Duo

- [Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)
  (technology overview), a companion *Designing for iPhone Duo* guide, and two Tech Talks:
  [Prepare your app for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111461/) and
  [Design for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111466/). Apple
  announced the resources on 9 September 2026 ([9to5Mac](https://9to5mac.com/2026/09/09/apple-launches-iphone-duo-developer-resources-ahead-of-october-release/)).
- Tooling: **Xcode 27.1** (release build 27A9275, 15 October) carries the iPhone Duo simulator and
  the iOS 27.1 SDK. The simulator runtime is a separate download. Device Hub exposes the poses
  (Closed, Book, Open, Rotate Right); `simctl` has no pose command
  ([Blake Crosley, simulator notes](https://blakecrosley.com/blog/xcode-27-1-beta-iphone-duo-simulator)).
- Release: 23 October 2026 ([Wikipedia](https://en.wikipedia.org/wiki/IPhone_Duo)).

### Screen sizes (community-measured from the simulator profile, not published by Apple)

| Display | Pixels (panel) | Points @3x in the simulator | Aspect |
|---|---|---|---|
| Outer, 5.4" | 1398 × 2034 | 466 × 678 | 1.45 |
| Inner, 7.6" | 1878 × 2670 (spec) / 2007 × 2853 (simulator, App Store screenshots) | 951 × 669 (landscape-native) | 1.42 ≈ √2 |

Sources: [Crosley, "The 1.42 problem"](https://blakecrosley.com/blog/iphone-duo-for-developers),
[FoldHunt](https://foldhunt.com/guides/iphone-duo-screen-sizes/),
[getchonky](https://getchonky.app/blog/iphone-duo-screen-sizes/),
[Dobra issue #204](https://github.com/jacksonmafra-umain/Dobra/issues/204). Test against the
simulator figures; the inner panel appears to render at 669 × 951 pt and downscale slightly.

The inner display's √2 aspect means folding it yields two panels of the same shape — great for
two-pane layouts and two-player games, poor for 16:9 video.

### Guidance that applies directly to Popcorn

| Apple says | Popcorn today |
|---|---|
| Use size classes, not interface orientation; the inner display does not honour supported orientations. | We derive `LayoutMode` from the window size, which amounts to the same thing. `supportedInterfaceOrientations` is only a hint for the outer display. |
| Never read `UIScreen.main`; it reports the outer display even when you are on the inner one. Use the window scene's screen. | `GameViewController` reads `view.window?.screen`. ✔ |
| `UIRequiresFullScreen` no longer opts an app out of resizing; scenes are resized in discrete steps when the device opens or closes. | We handle every size change in `GameScene.layoutDidChange`. The key is still set (harmless). |
| Safe-area insets are asymmetric (Dynamic Island on one side); don't assume leading == trailing. | `GameLayout` uses all four insets separately. ✔ |
| Games: change the aspect ratio rather than letterbox; if you must pad, fill the padding with art; fill the screen in every pose. | The arena reshapes (9×16 ↔ 16×12) and the sky background always fills the screen. ✔ |
| Reserved regions (fold, cameras) come back empty for the first several layout passes; query repeatedly. | Not used yet — see follow-ups. |

### New iOS 27.1 APIs (reported by third parties; verify in the SDK before use)

From [ecorpit's SDK write-up](https://ecorpit.com/iphone-duo-sdk-new-apis-xcode-27-1-developer-guide-2026/)
and Crosley's posts:

- `UIView.reservedRegions(kind:options:)` / `GeometryProxy.reservedRegions(...)`: the fold
  (`.division`) and the cameras (occlusions) as regions to keep content out of; each has `isActive`.
- `UIArrangementViewController` / SwiftUI `ArrangementView`: two panes split or overlaid around the fold.
- `UIHingeInteraction` / `UIHinge` / SwiftUI `onHingeChange`: hinge **angle** (radians) and
  **status** (`closed`, `partiallyOpen`, `fullyOpen`). Apple's advice: drive effects with it, not layout.
- No dedicated "pose" API; pose is covered by size classes + hinge status.

## 2. Framework choice: SpriteKit in 2026

- Not deprecated. An Apple DTS engineer checked the iOS 26 SDK headers: no framework-level
  deprecation marker, only a few ancient APIs ([forums](https://developer.apple.com/forums/thread/826562)).
- But: no major update in years, no named successor (SceneKit was deprecated at WWDC 2025 in favour of
  RealityKit, which has no 2D equivalent to SpriteKit's shape nodes and z-ordering), and a
  frame-rate regression has come and gone across iOS 26.x point releases
  ([forums](https://developer.apple.com/forums/thread/816719)).
- Alternatives: Godot (MIT, strong 2D, Apple has been contributing) and Unity (mature mobile pipeline,
  2D simulated inside 3D, licensing trust damaged in 2023) — see
  [Cubix](https://cubix.co/blog/best-2d-game-engines-complete-comparison-guide/),
  [OceanView](https://oceanviewgames.co.uk/blog/posts/unity-vs-godot-vs-unreal-for-indie-developers).
- **Decision for Popcorn:** stay on SpriteKit — it is the lightest path to a native, fold-aware
  iPhone game with no toolchain — but keep the simulation in `Popcorn/Engine` free of SpriteKit
  (already the case) so the renderer can be swapped if Apple ever retires it.

## 3. The genre

- Pang / Buster Bros (Mitchell, 1989) descends from *Cannon Ball* (MSX, 1983). Core loop: shoot a
  line upward, bubbles split in two down to a size that pops; bubbles bounce under gravity with a
  fixed apex per size ([Wikipedia](https://en.wikipedia.org/wiki/Buster_Bros.),
  [StrategyWiki on Super Pang](https://strategywiki.org/wiki/Super_Pang)).
- Modern clones (e.g. *Bubble Hunter*) lean on physics engines and add RPG progression; most are
  freemium. Popcorn's angle is the opposite: a complete, paid-nothing game whose only unlock is skill.
- No published technical breakdown of the original's bounce physics exists; our model (constant
  horizontal speed, fixed apex height per size, perfectly elastic walls) matches the observable behaviour.

## 4. Fold-native games so far

- *Twofold* (tabletop games — Liar's Dice, Broadside) uses the half-folded "Book" pose as a privacy
  screen between two players ([Axios](https://axios.com/2026/10/05/apple-iphone-duo-foldable-walkman-app)).
- A Bitrig hackathon on 26 September produced 73 Duo-specific projects, including a Nintendo
  DS-style dual-screen emulator shell ([DevClass](https://devclass.com/devops/2026/09/16/apple-iphone-duo-makes-developers-think-in-folds/5296425)).
- Pattern: the fold is used either as a *divider* (two players, two panes) or as an *input*
  (hinge angle drives something). Popcorn uses the first; the second is an opportunity.

## 5. Shipping

- Since 28 April 2026 App Store uploads must be built with the iOS 26 SDK or later
  ([Apple](https://developer.apple.com/app-store/submitting)). Use Xcode 27.1 so the Duo simulator
  is available anyway.
- Apple Developer Program: US$99/year. TestFlight for beta distribution.
- Games with Game Center features get better placement in Apple's Games app.
- The EU (and Switzerland's revised FADP) require a privacy policy even for an app that collects nothing;
  a one-paragraph "no data leaves the device" statement is enough.

## 6. Prioritised follow-ups for Popcorn

1. **Compile on a Mac with Xcode 27.1** and fix whatever the UIKit/SpriteKit half needs — the engine
   is verified, the rendering half has only been reviewed by eye.
2. **Reserved regions**: once `reservedRegions` is confirmed in the SDK, keep the HUD and pause
   button out of the camera occlusion and, in two-player mode, snap the arena's centre line to the
   fold division so the fold *is* the midfield line. Query it on every layout pass (it is empty at first).
3. **Book pose**: when `UIHinge.status == .partiallyOpen`, offer a "tabletop" variant — the lower
   half becomes a shared control deck, the upper half the arena — à la Twofold. Pure addition, no
   change to the model.
4. **Game Center**: leaderboards for Storm and per-level best times; achievements for 3-star cities.
   Improves Games-app placement and costs little.
5. **Renderer hedge**: keep `Engine/` SpriteKit-free (it is); if SpriteKit regresses further, a
   Metal or Godot front end can reuse it unchanged.
6. **Real art and audio**: the Core Graphics placeholders and synthesised blips are stand-ins; the
   call sites (`TextureFactory`, `SoundBank`) are the only places to touch.
