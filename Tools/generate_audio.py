#!/usr/bin/env python3
"""Generates the placeholder sound effects in Popcorn/Audio as small mono 16-bit WAV files.

They are synthesised blips with short envelopes, so the game has sound from the first build.
Swap any file for a real recording with the same name and the code does not change.
"""
import math
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Popcorn" / "Audio"
RATE = 22050


def env(t, duration, attack=0.005, release=None):
    release = release if release is not None else duration * 0.6
    if t < attack:
        return t / attack
    if t > duration - release:
        return max(0.0, (duration - t) / release)
    return 1.0


def render(name, duration, voice, gain=0.6):
    n = int(RATE * duration)
    frames = bytearray()
    for i in range(n):
        t = i / RATE
        s = max(-1.0, min(1.0, voice(t) * env(t, duration) * gain))
        frames += struct.pack("<h", int(s * 32767))
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(frames))


def sine(f):
    return lambda t: math.sin(2 * math.pi * f * t)


def sweep(f0, f1, duration):
    def v(t):
        k = t / duration
        f = f0 * (f1 / f0) ** k
        return math.sin(2 * math.pi * f * t)
    return v


def noise(seed=1):
    state = [seed]

    def v(t):
        state[0] = (state[0] * 1103515245 + 12345) & 0x7FFFFFFF
        return (state[0] / 0x7FFFFFFF) * 2 - 1
    return v


def mix(*voices):
    return lambda t: sum(v(t) for v in voices) / len(voices)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    # Pops rise through a pentatonic scale with the combo.
    scale = [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5, 1174.7, 1318.5]
    for i, f in enumerate(scale):
        render(f"pop{i}", 0.14, mix(sweep(f * 1.6, f, 0.14), sine(f * 2)), gain=0.55)
    render("fire", 0.12, sweep(900, 300, 0.12), gain=0.35)
    render("hit", 0.45, mix(sweep(220, 60, 0.45), noise()), gain=0.6)
    render("pickup", 0.28, lambda t: math.sin(2 * math.pi * (660 if t < 0.12 else 990) * t), gain=0.5)
    render("clear", 0.9, lambda t: math.sin(2 * math.pi * [523.25, 659.25, 783.99, 1046.5][min(3, int(t / 0.2))] * t), gain=0.5)
    render("over", 1.0, lambda t: math.sin(2 * math.pi * [440, 392, 349.2, 261.6][min(3, int(t / 0.25))] * t), gain=0.5)
    render("click", 0.05, sine(1800), gain=0.3)
    render("armor", 0.12, mix(sine(2400), sine(3100), noise(7)), gain=0.4)
    render("lightning", 0.25, mix(noise(3), sweep(2000, 400, 0.25)), gain=0.5)
    render("freeze", 0.6, mix(sweep(1200, 2400, 0.6), sine(1800)), gain=0.4)
    render("shield", 0.3, mix(sweep(600, 1400, 0.3), sine(900)), gain=0.5)
    render("block", 0.06, sine(400), gain=0.3)
    print(f"wrote {len(list(OUT.glob('*.wav')))} sounds to {OUT}")


if __name__ == "__main__":
    main()
