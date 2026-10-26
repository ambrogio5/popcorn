#!/usr/bin/env python3
"""Generates Popcorn/Content/levels.json and cities.json.

Levels are authored on a normalised 0..1 grid and mapped to both arena shapes at runtime. This
script validates every level with the same rules as Engine/Level.swift (LevelValidator), so the
content and the engine agree. Deterministic: same seed, same levels.
"""
import json
import math
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Popcorn" / "Content"

ARENAS = {"tall": (9.0, 16.0), "wide": (16.0, 12.0)}
RADIUS = {"large": 1.4, "medium": 0.95, "small": 0.6, "tiny": 0.35}
PLATFORM_THICKNESS = 0.4
MIN_PLATFORM_WIDTH = 0.15
MIN_PLATFORM_Y, MAX_PLATFORM_Y = 0.2, 0.78
MIN_VERTICAL_GAP = 0.2
SPAWN_CLEARANCE = 2.0

CITIES = [
    {"name": "Celerina", "skyTop": "#0F1B3D", "skyBottom": "#7FB2E5", "ground": "#F2F6FA", "accent": "#FFD166"},
    {"name": "Milano", "skyTop": "#3A1F4B", "skyBottom": "#F4A261", "ground": "#4A3B2E", "accent": "#FFB4A2"},
    {"name": "Paris", "skyTop": "#1D2B53", "skyBottom": "#C9B6E4", "ground": "#3B3A4F", "accent": "#FFE066"},
    {"name": "Cairo", "skyTop": "#4A1E0B", "skyBottom": "#F7C59F", "ground": "#8C6239", "accent": "#FFF1B5"},
    {"name": "Tokyo", "skyTop": "#0B0F2B", "skyBottom": "#FF5EA8", "ground": "#1E1B3A", "accent": "#5CE6FF"},
    {"name": "Hong Kong", "skyTop": "#09132A", "skyBottom": "#2EC4B6", "ground": "#1B2A41", "accent": "#FFBF69"},
    {"name": "Sydney", "skyTop": "#0B3C5D", "skyBottom": "#FFD6A5", "ground": "#2E4057", "accent": "#FF8E72"},
    {"name": "New York", "skyTop": "#101820", "skyBottom": "#5C6B8A", "ground": "#0E1116", "accent": "#F2A541"},
]

LEVEL_NAMES = {
    "Celerina": ["First Flakes", "Inn Valley", "Chairlift", "Powder Day", "Bobsleigh", "Larch Woods", "Ice Rink", "Summit"],
    "Milano": ["Tram Stop", "Navigli", "Duomo Steps", "Aperitivo", "La Scala", "Fashion Week", "Risotto", "Derby"],
    "Paris": ["Café Crème", "Métro", "Montmartre", "Louvre", "Catacombs", "Bateau", "Rooftops", "Eiffel"],
    "Cairo": ["Bazaar", "Felucca", "Papyrus", "Oasis", "Sandstorm", "Sphinx", "Obelisk", "Pyramid"],
    "Tokyo": ["Shibuya", "Ramen", "Capsule", "Arcade", "Shinkansen", "Sakura", "Neon", "Fuji"],
    "Hong Kong": ["Star Ferry", "Dim Sum", "Tram", "Night Market", "Typhoon", "Peak", "Harbour", "Skyline"],
    "Sydney": ["Ferry", "Bondi", "Koala", "Didgeridoo", "Harbour Bridge", "Surf", "Outback", "Opera House"],
    "New York": ["Subway", "Bagel", "Yellow Cab", "Brooklyn", "Rooftop", "Broadway", "Central Park", "Skyscraper"],
}

# Hand-made platform layouts. Each: platforms (x, y, w) and ladders (x, y0, y1), normalised.
LAYOUTS = [
    {"platforms": [], "ladders": []},
    {"platforms": [(0.3, 0.4, 0.4)], "ladders": [(0.5, 0.0, 0.4)]},
    {"platforms": [(0.0, 0.35, 0.3), (0.7, 0.35, 0.3)], "ladders": [(0.15, 0.0, 0.35), (0.85, 0.0, 0.35)]},
    {"platforms": [(0.25, 0.3, 0.5), (0.35, 0.6, 0.3)], "ladders": [(0.5, 0.0, 0.3), (0.5, 0.3, 0.6)]},
    {"platforms": [(0.0, 0.3, 0.3), (0.35, 0.5, 0.3), (0.7, 0.7, 0.3)], "ladders": [(0.15, 0.0, 0.3), (0.5, 0.0, 0.5), (0.85, 0.0, 0.7)]},
    {"platforms": [(0.1, 0.45, 0.8)], "ladders": [(0.2, 0.0, 0.45), (0.8, 0.0, 0.45)]},
    {"platforms": [(0.05, 0.5, 0.25), (0.7, 0.5, 0.25), (0.35, 0.7, 0.3)], "ladders": [(0.17, 0.0, 0.5), (0.83, 0.0, 0.5), (0.5, 0.0, 0.7)]},
    {"platforms": [(0.2, 0.25, 0.6), (0.0, 0.55, 0.3), (0.7, 0.55, 0.3)], "ladders": [(0.5, 0.0, 0.25), (0.15, 0.0, 0.55), (0.85, 0.0, 0.55)]},
    {"platforms": [(0.0, 0.4, 0.45), (0.55, 0.65, 0.45)], "ladders": [(0.2, 0.0, 0.4), (0.75, 0.0, 0.65)]},
    {"platforms": [(0.3, 0.25, 0.4), (0.3, 0.5, 0.4), (0.3, 0.75, 0.4)], "ladders": [(0.4, 0.0, 0.25), (0.6, 0.25, 0.5), (0.4, 0.5, 0.75)]},
    {"platforms": [(0.0, 0.3, 0.2), (0.8, 0.3, 0.2), (0.3, 0.55, 0.4)], "ladders": [(0.1, 0.0, 0.3), (0.9, 0.0, 0.3), (0.5, 0.0, 0.55)]},
    {"platforms": [(0.1, 0.6, 0.35), (0.55, 0.6, 0.35)], "ladders": [(0.27, 0.0, 0.6), (0.72, 0.0, 0.6)]},
    {"platforms": [(0.0, 0.25, 0.25), (0.75, 0.25, 0.25), (0.0, 0.5, 0.25), (0.75, 0.5, 0.25)],
     "ladders": [(0.12, 0.0, 0.25), (0.88, 0.0, 0.25), (0.12, 0.25, 0.5), (0.88, 0.25, 0.5)]},
    {"platforms": [(0.35, 0.35, 0.3), (0.0, 0.6, 0.3), (0.7, 0.6, 0.3)], "ladders": [(0.5, 0.0, 0.35), (0.15, 0.0, 0.6), (0.85, 0.0, 0.6)]},
]

# Per city: which layouts are used (indexes into LAYOUTS, one per level), bubble count range,
# and the kinds that may appear with weights.
CITY_PLANS = [
    {"layouts": [0, 0, 1, 0, 1, 2, 1, 5], "bubbles": (1, 3), "kinds": {"plain": 1.0}, "sizes": {"large": 0.6, "medium": 0.4}},
    {"layouts": [2, 1, 3, 5, 2, 11, 3, 6], "bubbles": (2, 4), "kinds": {"plain": 0.9, "golden": 0.1}, "sizes": {"large": 0.55, "medium": 0.35, "small": 0.1}},
    {"layouts": [5, 11, 4, 7, 3, 8, 6, 9], "bubbles": (3, 4), "kinds": {"plain": 0.75, "armored": 0.2, "golden": 0.05}, "sizes": {"large": 0.5, "medium": 0.35, "small": 0.15}},
    {"layouts": [8, 10, 7, 12, 4, 13, 9, 6], "bubbles": (3, 5), "kinds": {"plain": 0.6, "armored": 0.2, "triple": 0.15, "golden": 0.05}, "sizes": {"large": 0.5, "medium": 0.35, "small": 0.15}},
    {"layouts": [10, 13, 9, 6, 12, 7, 4, 8], "bubbles": (4, 5), "kinds": {"plain": 0.5, "armored": 0.15, "triple": 0.15, "flipped": 0.15, "golden": 0.05}, "sizes": {"large": 0.5, "medium": 0.3, "small": 0.2}},
    {"layouts": [6, 12, 10, 13, 9, 3, 8, 7], "bubbles": (4, 6), "kinds": {"plain": 0.45, "armored": 0.15, "triple": 0.12, "flipped": 0.13, "lightning": 0.1, "golden": 0.05}, "sizes": {"large": 0.45, "medium": 0.35, "small": 0.2}},
    {"layouts": [13, 9, 12, 6, 10, 4, 7, 8], "bubbles": (5, 6), "kinds": {"plain": 0.4, "armored": 0.17, "triple": 0.13, "flipped": 0.13, "lightning": 0.12, "golden": 0.05}, "sizes": {"large": 0.5, "medium": 0.3, "small": 0.2}},
    {"layouts": [12, 13, 6, 9, 10, 7, 4, 2], "bubbles": (5, 7), "kinds": {"plain": 0.35, "armored": 0.18, "triple": 0.15, "flipped": 0.15, "lightning": 0.12, "golden": 0.05}, "sizes": {"large": 0.55, "medium": 0.3, "small": 0.15}},
]


def spawn_points(width, count):
    if count <= 1:
        return [(width / 2, 0.0)]
    return [(width * 0.35, 0.0), (width * 0.65, 0.0)]


def platform_box(p, w, h):
    top = p["y"] * h
    return (p["x"] * w, top - PLATFORM_THICKNESS, (p["x"] + p["w"]) * w, top)


def overlaps_circle(box, cx, cy, r):
    x0, y0, x1, y1 = box
    qx = min(max(cx, x0), x1)
    qy = min(max(cy, y0), y1)
    return math.hypot(cx - qx, cy - qy) < r


def validate(level):
    """Mirror of LevelValidator.problems(in:)."""
    eps = 1e-6
    problems = []
    plats = level["platforms"]
    if not level["name"]:
        problems.append("missing name")
    if level["id"] != 0 and level["par"] <= 0:
        problems.append("par must be positive")
    if level["id"] != 0 and not level["bubbles"]:
        problems.append("no bubbles")
    for i, p in enumerate(plats):
        if p["x"] < -eps or p["x"] + p["w"] > 1 + eps:
            problems.append(f"platform {i} leaves the arena")
        if p["w"] < MIN_PLATFORM_WIDTH - eps:
            problems.append(f"platform {i} is too narrow")
        if p["y"] < MIN_PLATFORM_Y - eps or p["y"] > MAX_PLATFORM_Y + eps:
            problems.append(f"platform {i} height out of range")
        for j, q in enumerate(plats):
            if j <= i:
                continue
            overlap_x = p["x"] < q["x"] + q["w"] - eps and p["x"] + p["w"] > q["x"] + eps
            if overlap_x and abs(p["y"] - q["y"]) < MIN_VERTICAL_GAP - eps:
                problems.append(f"platforms {i} and {j} are too close")

    def platform_at(y, x):
        for k, p in enumerate(plats):
            if abs(p["y"] - y) < eps and p["x"] - eps <= x <= p["x"] + p["w"] + eps:
                return k
        return None

    for i, l in enumerate(level["ladders"]):
        if l["x"] < 0.02 or l["x"] > 0.98:
            problems.append(f"ladder {i} leaves the arena")
        if l["y1"] <= l["y0"] + eps:
            problems.append(f"ladder {i} has no height")
        if platform_at(l["y1"], l["x"]) is None:
            problems.append(f"ladder {i} top is not on a platform")
        if abs(l["y0"]) > eps and platform_at(l["y0"], l["x"]) is None:
            problems.append(f"ladder {i} bottom is neither the floor nor a platform")

    reachable = set()
    changed = True
    while changed:
        changed = False
        for l in level["ladders"]:
            from_floor = abs(l["y0"]) < eps
            src = platform_at(l["y0"], l["x"])
            from_reachable = src is not None and src in reachable
            top = platform_at(l["y1"], l["x"])
            if (from_floor or from_reachable) and top is not None and top not in reachable:
                reachable.add(top)
                changed = True
    for i in range(len(plats)):
        if i not in reachable:
            problems.append(f"platform {i} cannot be reached")

    for i, b in enumerate(level["bubbles"]):
        if b["dir"] not in (-1, 1):
            problems.append(f"bubble {i} has an invalid direction")
        for mode, (w, h) in ARENAS.items():
            cx, cy = b["x"] * w, b["y"] * h
            r = RADIUS[b["size"]]
            if cx - r < -eps or cx + r > w + eps or cy - r < -eps or cy + r > h + eps:
                problems.append(f"bubble {i} leaves the {mode} arena")
            for j, p in enumerate(plats):
                if overlaps_circle(platform_box(p, w, h), cx, cy, r + 0.1):
                    problems.append(f"bubble {i} starts inside platform {j} in {mode} mode")
            for j, other in enumerate(level["bubbles"]):
                if j <= i:
                    continue
                ox, oy = other["x"] * w, other["y"] * h
                if math.hypot(ox - cx, oy - cy) < r + RADIUS[other["size"]]:
                    problems.append(f"bubbles {i} and {j} overlap in {mode} mode")
            for count in (1, 2):
                for sx, sy in spawn_points(w, count):
                    if math.hypot(sx - cx, sy + 0.7 - cy) < r + SPAWN_CLEARANCE:
                        problems.append(f"bubble {i} starts on top of a player in {mode} mode")
    return problems


def weighted(rng, table):
    roll = rng.random() * sum(table.values())
    for key, weight in table.items():
        roll -= weight
        if roll <= 0:
            return key
    return next(iter(table))


def place_bubbles(rng, level, count, plan):
    """Random valid starting positions; retries until the validator is happy."""
    for _attempt in range(3000):
        bubbles = []
        for _ in range(count):
            size = weighted(rng, plan["sizes"])
            kind = weighted(rng, plan["kinds"])
            r = RADIUS[size]
            # Keep inside both arenas: x margin from the narrow (tall) arena, y margin from the low (wide) one.
            x = rng.uniform(r / 9.0 + 0.02, 1 - r / 9.0 - 0.02)
            y = rng.uniform(0.3, 1 - r / 12.0 - 0.02)
            bubbles.append({"x": round(x, 3), "y": round(y, 3), "size": size, "kind": kind, "dir": rng.choice([-1, 1])})
        level["bubbles"] = bubbles
        if not validate(level):
            return True
    return False


def build():
    rng = random.Random(20261026)
    levels = []
    level_id = 1
    for city_index, (city, plan) in enumerate(zip(CITIES, CITY_PLANS)):
        names = LEVEL_NAMES[city["name"]]
        for slot in range(8):
            layout = LAYOUTS[plan["layouts"][slot]]
            lo, hi = plan["bubbles"]
            count = lo + (hi - lo) * slot // 7
            level = {
                "id": level_id,
                "name": names[slot],
                "city": city_index,
                "par": 1.0,  # replaced below once the bubbles are known
                "platforms": [{"x": x, "y": y, "w": w} for x, y, w in layout["platforms"]],
                "ladders": [{"x": x, "y0": y0, "y1": y1} for x, y0, y1 in layout["ladders"]],
                "bubbles": [],
            }
            # Busy layouts cannot always fit the full count in the narrow arena; ease off one at a time.
            while not place_bubbles(rng, level, count, plan):
                count -= 1
                if count < 1:
                    sys.exit(f"could not place bubbles for level {level_id}")
            # Par: generous. A large bubble is 15 hits (1+2+4+8), medium 7, small 3.
            hits = {"large": 15, "medium": 7, "small": 3, "tiny": 1}
            total = sum(hits[b["size"]] * (3 if b["kind"] == "triple" else 1) + (1 if b["kind"] == "armored" else 0) for b in level["bubbles"])
            level["par"] = float(20 + total * 2 + len(level["platforms"]) * 3)
            problems = validate(level)
            if problems:
                sys.exit(f"level {level_id} invalid: {problems}")
            levels.append(level)
            level_id += 1
    return levels


def main():
    levels = build()
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "levels.json").write_text(json.dumps(levels, indent=1) + "\n")
    (OUT / "cities.json").write_text(json.dumps(CITIES, indent=1) + "\n")
    kinds = {}
    for l in levels:
        for b in l["bubbles"]:
            kinds[b["kind"]] = kinds.get(b["kind"], 0) + 1
    print(f"wrote {len(levels)} levels across {len(CITIES)} cities; bubble kinds: {kinds}")


if __name__ == "__main__":
    main()
