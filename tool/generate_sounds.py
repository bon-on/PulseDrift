#!/usr/bin/env python3
"""Generate the synthesized sound effects (Python 3 standard library only).

Writes mono, 44100 Hz, 16-bit PCM wav files to assets/audio/. A fixed random
seed makes every run produce byte-identical files. pulse_pass.wav and
background_loop.wav were generated for the project earlier and are not
rewritten here; only the sounds listed in SOUNDS are produced.

Usage: python3 tool/generate_sounds.py
"""

import math
import os
import random
import struct
import wave

RATE = 44100
PEAK = 0.708  # about -3 dBFS


def envelope(i, n, attack, release):
    """Linear attack and release ramps so the file starts and ends at zero."""
    a = max(1, int(attack * RATE))
    r = max(1, int(release * RATE))
    gain = 1.0
    if i < a:
        gain = i / a
    if i > n - r:
        gain = min(gain, max(0.0, (n - i) / r))
    return gain


def triangle(phase):
    return 2.0 * abs(2.0 * (phase - math.floor(phase + 0.5))) - 1.0


def crash():
    """Soft low thud: falling sine/triangle glide plus a short muffled burst."""
    rng = random.Random(7)
    n = int(0.36 * RATE)
    samples = []
    phase = 0.0
    noise_state = 0.0
    for i in range(n):
        t = i / RATE
        freq = 55.0 + 140.0 * math.exp(-t * 11.0)
        phase += freq / RATE
        tone = math.sin(2.0 * math.pi * phase) * 0.8
        tone += triangle(phase * 0.5) * 0.25
        # One-pole low-passed noise keeps the burst dull, not hissy.
        noise_state += 0.12 * (rng.uniform(-1.0, 1.0) - noise_state)
        burst = noise_state * 1.6 * math.exp(-t * 28.0)
        decay = math.exp(-t * 7.5)
        samples.append((tone * decay + burst) * envelope(i, n, 0.004, 0.06))
    return samples


SOUNDS = {"crash": crash}


def write_wav(path, samples):
    peak = max(abs(s) for s in samples) or 1.0
    scale = PEAK / peak
    with wave.open(path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(
            b"".join(
                struct.pack("<h", int(round(max(-1.0, min(1.0, s * scale)) * 32767)))
                for s in samples
            )
        )


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    target = os.path.join(root, "assets", "audio")
    os.makedirs(target, exist_ok=True)
    for name, build in SOUNDS.items():
        path = os.path.join(target, name + ".wav")
        write_wav(path, build())
        print("wrote", os.path.relpath(path, root), os.path.getsize(path), "bytes")


if __name__ == "__main__":
    main()
