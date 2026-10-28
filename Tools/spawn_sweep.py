#!/usr/bin/env python3
"""Diagnostic: which levels knock down a player who does nothing after the level starts?

Ports the bubble physics of Engine/GameModel.swift (gravity, wall and platform bounces, fixed apex
per size, width-scaled horizontal speed, the 2 s starting grace and the 2.5 s starting
invulnerability) and plays every level in every arena shape with the players standing still at
their spawn points. Prints the first hit per level/shape/player
count within the horizon. Harpoons, pickups and input are not simulated.

    python3 Tools/spawn_sweep.py            # 4 s horizon
    python3 Tools/spawn_sweep.py 8          # longer horizon

Keep the constants below in step with GameModel, BubbleSize, Player and ArenaSpec.
"""
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEVELS = ROOT / "Popcorn" / "Content" / "levels.json"

ARENAS = {"tall": (9.0, 16.0), "wide": (16.0, 12.0), "upright": (12.0, 16.0)}
RADIUS = {"large": 1.4, "medium": 0.95, "small": 0.6, "tiny": 0.35}
HSPEED = {"large": 2.8, "medium": 3.4, "small": 4.0, "tiny": 4.8}
APEX = {"large": 0.82, "medium": 0.64, "small": 0.46, "tiny": 0.30}
GRAVITY = 14.0
STEP = 1.0 / 120.0
PLATFORM_THICKNESS = 0.4
PLAYER_W, PLAYER_H = 0.9, 1.4
START_INVULNERABLE = 2.5   # GameModel.startInvulnerability
SPAWN_GRACE = 2.0          # GameModel.startGrace


def bounce_speed(size, height):
    climb = max(APEX[size] * height - RADIUS[size], 1.0)
    return math.sqrt(2 * GRAVITY * climb)


def closest(box, x, y):
    x0, y0, x1, y1 = box
    return min(max(x, x0), x1), min(max(y, y0), y1)


def spawn_points(width, count):
    if count <= 1:
        return [(width / 2, 0.0)]
    return [(width * 0.35, 0.0), (width * 0.65, 0.0)]


def first_hit(level, mode, players, horizon):
    w, h = ARENAS[mode]
    plats = [(p["x"] * w, p["y"] * h - PLATFORM_THICKNESS, (p["x"] + p["w"]) * w, p["y"] * h) for p in level["platforms"]]
    hscale = w / 9.0  # ArenaSpec.horizontalScale: constant crossing time in every shape
    bubbles = [{"x": b["x"] * w, "y": b["y"] * h, "vx": b["dir"] * HSPEED[b["size"]] * hscale, "vy": 0.0,
                "size": b["size"], "flipped": b["kind"] == "flipped", "grace": SPAWN_GRACE} for b in level["bubbles"]]
    boxes = [(sx - PLAYER_W / 2, sy, sx + PLAYER_W / 2, sy + PLAYER_H) for sx, sy in spawn_points(w, players)]
    t = 0.0
    while t < horizon:
        t += STEP
        for b in bubbles:
            r = RADIUS[b["size"]]
            g = -GRAVITY if b["flipped"] else GRAVITY
            b["vy"] -= g * STEP
            b["x"] += b["vx"] * STEP
            b["y"] += b["vy"] * STEP
            if b["x"] - r < 0:
                b["x"], b["vx"] = r, abs(b["vx"])
            elif b["x"] + r > w:
                b["x"], b["vx"] = w - r, -abs(b["vx"])
            if b["y"] - r < 0:
                b["y"] = r
                b["vy"] = abs(b["vy"]) if b["flipped"] else bounce_speed(b["size"], h)
            elif b["y"] + r > h:
                b["y"] = h - r
                b["vy"] = -bounce_speed(b["size"], h) if b["flipped"] else -abs(b["vy"])
            for box in plats:
                cx, cy = closest(box, b["x"], b["y"])
                dx, dy = b["x"] - cx, b["y"] - cy
                dist = math.hypot(dx, dy)
                if dist >= r:
                    continue
                nx, ny = (0.0, 1.0) if dist < 1e-6 else (dx / dist, dy / dist)
                pen = r - dist
                if abs(ny) >= abs(nx):
                    if ny > 0:
                        b["y"] += pen
                        b["vy"] = abs(b["vy"]) if b["flipped"] else bounce_speed(b["size"], h)
                    else:
                        b["y"] -= pen
                        b["vy"] = -bounce_speed(b["size"], h) if b["flipped"] else -abs(b["vy"])
                else:
                    b["x"] += nx * pen
                    b["vx"] = abs(b["vx"]) if nx > 0 else -abs(b["vx"])
            b["grace"] -= STEP
        if t <= START_INVULNERABLE:
            continue
        for pi, box in enumerate(boxes):
            for b in bubbles:
                if b["grace"] > 0:
                    continue
                cx, cy = closest(box, b["x"], b["y"])
                if math.hypot(b["x"] - cx, b["y"] - cy) < RADIUS[b["size"]]:
                    return t, pi, b["size"]
    return None


def main():
    horizon = float(sys.argv[1]) if len(sys.argv) > 1 else 4.0
    levels = json.loads(LEVELS.read_text())
    rows = []
    for level in levels:
        for mode in ARENAS:
            for players in (1, 2):
                hit = first_hit(level, mode, players, horizon)
                if hit:
                    rows.append((hit[0], level["id"], level["name"], mode, players, hit[1] + 1, hit[2]))
    rows.sort()
    print(f"Standing still at spawn, a player is hit within {horizon:g}s in these cases "
          f"(invulnerable for the first {START_INVULNERABLE:g}s):")
    for t, id_, name, mode, players, player, size in rows:
        print(f"  level {id_:2d} {name:15s} {mode:8s} {players}p  at {t:4.1f}s  player {player}, {size} bubble")
    total = len(levels) * len(ARENAS) * 2
    print(f"{len(rows)} of {total} level/shape/player-count combinations")


if __name__ == "__main__":
    main()
