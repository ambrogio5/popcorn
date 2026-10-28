# Art brief for Popcorn

Everything on screen today is a Core Graphics placeholder drawn at launch
(`Popcorn/Rendering/TextureFactory.swift`). This brief lists what real art has to replace, in what
sizes, and gives a ready-to-paste prompt for an image model. Section 1 is the inventory, section 2
the style directions, section 3 the prompt.

## 1. Asset inventory

Sizes are the largest the game ever draws (a large bubble on an iPad in portrait is about 160 pt
across, which is 480 px at 3x). Deliver square transparent PNGs at the sizes below; the game
scales down, never up.

### Bubbles, 12 designs, 512 × 512 px each

One design per colour; the game shows each at four sizes (large, medium, small, tiny), so every
design must stay readable at 40 px.

| File | Meaning | Today's colour | Mark |
|---|---|---|---|
| `bubble-plain-large` | ordinary, large | purple `#B084F5` | none |
| `bubble-plain-medium` | ordinary, medium | blue `#5AA9FF` | none |
| `bubble-plain-small` | ordinary, small | green `#5BE38A` | none |
| `bubble-plain-tiny` | ordinary, tiny | yellow `#FFD84D` | none |
| `bubble-flipped-large` … `-tiny` | falls upward, bounces on the ceiling | each size colour, darker | up arrow |
| `bubble-armored` | needs two hits | grey `#9AA3AD` | rivet band |
| `bubble-lightning` | hitting it zaps neighbours | cyan `#5CE6FF` | lightning bolt |
| `bubble-triple` | splits into three | pink `#FF6FD8` | three dots |
| `bubble-golden` | always drops a power-up | gold `#FFC53D` | star |

Rule to keep: size is told by hue, kind by the mark. Four clearly different hues for the sizes, and
the four special kinds must not reuse them.

### Players, 2 characters, 256 px tall (about 165 px wide), bottom-centre anchored

`player-1` teal `#3DD6D0`, `player-2` coral `#FF7A7A`. Facing right; the game mirrors for left.
One standing frame is the minimum. Nice to have, same canvas: `-walk-a`, `-walk-b`, `-climb`,
`-hit`, `-cheer`.

### Power-ups, 5 pickups, 192 × 192 px

`pickup-double` (two harpoons), `pickup-sticky` (line sticks to the ceiling), `pickup-rapid`
(hold to fire), `pickup-shield` (one free hit), `pickup-freeze` (bubbles stop). Rounded tokens
that read at 50 px.

### Arena furniture

- `platform-tile`, 9-slice capable, 256 × 64 px: a ledge the player stands on and bubbles bounce off.
- `ladder-tile`, vertically repeating, 128 × 128 px.
- `harpoon-tip`, 64 × 64 px, and a 1-unit-high `harpoon-line` segment, 32 × 128 px, both
  optional (the line is currently a glowing stroke).

### Backgrounds, 8 cities

One tileable skyline strip per city, 2048 × 512 px, transparent above the rooftops, plus two sky
colours (top, bottom) per city for the gradient the game draws behind it. The order the player
meets them: Celerina, Milano, Paris, Cairo, Tokyo, Hong Kong, Sydney, New York. Celerina is an
Engadin village in winter, not a big city: chalets, the church tower, larch woods, mountains.

### Interface

`star-on`, `star-off`, `heart` (96 px), `icon-pause`, `icon-fire`, stick base and knob
(128 px), and `app-icon` 1024 × 1024 px with no transparency and no text.

### Effects

`particle-soft` 64 px (pop spray), `particle-spark` 64 px (lightning).

## 2. Style directions

Pick one; the prompt below has a slot for it.

**A. Paper postcards (recommended).** Layered cut-paper with soft drop shadows, slightly grainy
texture, a travel-journal feel. Each city is a postcard: three to four paper layers of skyline.
Bubbles are glossy balloons on paper. Fits the "64 levels across 8 cities" hook, scales to every
screen shape because the layers are flat, and looks good on both the small outer screen and the
open Duo.

**B. Chunky arcade.** Pixel art, 32 px base grid, limited palette, CRT scanline option. A direct
homage to Pang. Cheap to produce, very readable, but the fold and the big inner screen show the
pixels large, so the grid has to be chosen for the open Duo, not the phone.

**C. Soft toy.** Rounded matte 3D render look, like a desk toy: squashy marble bubbles, a little
vinyl figure, clay platforms. Modern iOS look. More work for consistent lighting across 40 assets.

**D. Ink and watercolour.** Loose brush outlines, watercolour fills, paper white backgrounds with
a wash. Charming and distinct, but the lightest bubbles lose contrast against bright skies.

## 3. Prompt for an image model

Paste the block below. Replace `{STYLE}` with the direction, for example "layered cut-paper with
soft drop shadows and a fine paper grain, like a travel postcard". Run it once per asset group so
each run has one job.

```
You are producing game sprites for "Popcorn", a Pang-style bubble-popping game for iPhone.
Art style: {STYLE}. Keep one consistent style, line weight and light direction (top-left) across
every asset in this set, so they sit together on one screen.

Technical rules, no exceptions:
- Square canvas, transparent background, PNG, exactly the pixel size requested.
- One object per image, centred, filling about 90% of the canvas, no shadow outside the object,
  no text, no watermark, no border.
- Flat colour areas and clean silhouettes: the game scales sprites down to a quarter of this
  size and they must still read.
- Where I give a hex colour it is the identity of that object; keep that hue dominant.

Asset group: BUBBLES (12 images, 512 × 512 px). Bubbles are round, glossy, slightly
translucent, with one highlight at top-left. Size is told by hue, type by a mark in the middle.
1. bubble-plain-large: purple #B084F5, no mark.
2. bubble-plain-medium: blue #5AA9FF, no mark.
3. bubble-plain-small: green #5BE38A, no mark.
4. bubble-plain-tiny: yellow #FFD84D, no mark.
5–8. bubble-flipped-large/medium/small/tiny: same four hues but darker and moodier, with a bold
   white upward arrow in the middle.
9. bubble-armored: grey #9AA3AD, metallic, a riveted band around the middle.
10. bubble-lightning: cyan #5CE6FF, a white lightning bolt in the middle, faint electric arcs.
11. bubble-triple: pink #FF6FD8, three small white dots in a triangle in the middle.
12. bubble-golden: gold #FFC53D, a white five-point star in the middle, a soft sparkle.

Asset group: PLAYERS (2 characters, 256 px tall on a 256 × 256 canvas, feet on the bottom edge,
centred horizontally). A small round bubble-buster with a cap and big eyes, facing right, holding
nothing (the harpoon is drawn by the game). Player 1 wears teal #3DD6D0, player 2 coral #FF7A7A;
same body, different colour and cap. Frames per player: standing, walk-a, walk-b (opposite leg),
climb (both hands up on a ladder), hit (knocked back, eyes shut), cheer (arms up).

Asset group: POWER-UPS (5 tokens, 192 × 192 px). Rounded square tokens with a thick white rim
and a single bold black glyph, readable at 50 px:
pickup-double orange #FF9F43 glyph two vertical lines; pickup-sticky light green #B8E986 glyph a
line with a blob on top; pickup-rapid red #FF5E7E glyph three vertical lines; pickup-shield light
blue #6FC3FF glyph a shield; pickup-freeze pale ice #CFF6FF glyph a snowflake.

Asset group: ARENA (3 images). platform-tile 256 × 64 px, a ledge with distinct left cap,
repeating middle and right cap, top edge lighter; ladder-tile 128 × 128 px, two rails and two
rungs, must repeat vertically with no seam; harpoon-tip 64 × 64 px, a small upward arrowhead in
pale yellow #FFF3B0.

Asset group: SKYLINES (8 images, 2048 × 512 px, transparent above the rooftops, must tile
left-to-right with no seam). Silhouette style with two or three depth layers in the same image,
darker in front. No sky in the image. One per city, with one recognisable landmark and otherwise
generic buildings:
celerina (Engadin village in winter: chalets, church tower, larch trees, mountains behind),
milano (Duomo spires, tram wires), paris (Eiffel Tower, mansard roofs), cairo (pyramids,
minarets, palms), tokyo (Tokyo Tower, neon signs, Fuji far behind), hongkong (dense towers,
Bank of China angles, harbour cranes), sydney (Opera House sails, Harbour Bridge), newyork
(Empire State, water towers, bridges).
Also give two sky colours per city (hex) for a vertical gradient behind the skyline, night at the
top and a warmer tone at the horizon.

Asset group: INTERFACE (8 images). star-on gold #FFD166 and star-off (same shape, 20% white),
96 × 96 px; heart pink #FF5E7E 96 × 96 px; icon-pause and icon-fire (an upward arrow) white on
transparent, 128 × 128 px; stick-base (a soft ring) and stick-knob (a filled circle) in white,
128 × 128 px; app-icon 1024 × 1024 px with NO transparency: a single large glossy purple bubble
on a night-to-dawn sky with a thin pale harpoon rising from the bottom edge towards it, no text.

Deliver each asset as a separate file named exactly as listed.
```

## 4. Where the files go

Drop the PNGs into `Popcorn/Assets.xcassets` as image sets named exactly as in section 1.
`TextureFactory` already looks for those names first and only draws its Core Graphics placeholder
when an image set is missing, so each asset switches over the moment its image set exists; no code
changes and no call-site changes. Names it looks for today:

- `bubble-plain-large` … `bubble-plain-tiny`, `bubble-flipped-large` … `bubble-flipped-tiny`,
  `bubble-armored`, `bubble-lightning`, `bubble-triple`, `bubble-golden`
- `player-1`, `player-2` (standing frame; the extra frames are not wired up yet)
- `pickup-double`, `pickup-sticky`, `pickup-rapid`, `pickup-shield`, `pickup-freeze`
- `star-on`, `star-off`, `heart`, `particle-soft`
- `skyline-celerina`, `skyline-milano`, `skyline-paris`, `skyline-cairo`, `skyline-tokyo`,
  `skyline-hongkong`, `skyline-sydney`, `skyline-newyork`: the tileable strip, drawn across the
  bottom third of the screen over the gradient the game still draws from the two sky colours
  in `cities.json`.

Still to wire up when the art arrives: platform and ladder (drawn as paths in
`GameScene.rebuildStatic`, to become tiled sprites), the harpoon tip and line, the pause, fire and
stick icons, `particle-spark`, and the player animation frames. The app icon goes into
`AppIcon.appiconset` in place of the generated one.
