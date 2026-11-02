#!/usr/bin/env python3
"""Generate the synthesized sounds (Python 3 standard library only).

A fixed random seed makes every run produce byte-identical files.
pulse_pass.wav was generated for the project earlier and is not rewritten
here; only the sounds listed in SOUNDS are produced.

  crash.wav       44100 Hz  soft low thud (run ends)
  near_miss.wav   44100 Hz  airy whoosh with a bright zing (late dodge)
  spark.wav       44100 Hz  two-note glassy pickup chime
  multiplier.wav  44100 Hz  rising square-wave blip run (multiplier burst)
  mission.wav     44100 Hz  short synth chord stab (mission complete)
  level_up.wav    44100 Hz  rising synth arpeggio fanfare (pilot level up)
  music_loop.wav  16000 Hz  driving synthwave loop, 120 bpm, 8 bars, seamless

Everything is mono 16-bit PCM. The music runs at 16 kHz so the 16 s loop
stays near 0.5 MB. It is rendered on a circular timeline (note tails wrap
around the end and every filter/delay runs over two tiled periods keeping the
second), so the last sample flows into the first without a click.

Usage: python3 tool/generate_sounds.py
"""

import math
import os
import random
import struct
import wave

RATE = 44100
PEAK = 0.708  # about -3 dBFS
MUSIC_RATE = 16000
MUSIC_PEAK = 0.282  # about -11 dBFS
TAU = 2.0 * math.pi


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


def midi_hz(note):
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def lowpass(x, cutoff, rate):
    """One-pole low-pass."""
    a = 1.0 - math.exp(-TAU * cutoff / rate)
    y = 0.0
    out = []
    for s in x:
        y += a * (s - y)
        out.append(y)
    return out


def highpass(x, cutoff, rate):
    lp = lowpass(x, cutoff, rate)
    return [s - l for s, l in zip(x, lp)]


def mix_into(buf, sig, start, wrap=False):
    n = len(buf)
    for i, s in enumerate(sig):
        j = start + i
        if wrap:
            buf[j % n] += s
        elif j < n:
            buf[j] += s


def feedback_delay(x, delay, feedback, damp_hz, rate):
    """Echo tail only (wet minus dry)."""
    a = 1.0 - math.exp(-TAU * damp_hz / rate)
    wet = [0.0] * len(x)
    out = [0.0] * len(x)
    lp = 0.0
    for i in range(len(x)):
        if i >= delay:
            lp += a * (wet[i - delay] - lp)
            wet[i] = x[i] + feedback * lp
        else:
            wet[i] = x[i]
        out[i] = wet[i] - x[i]
    return out


def circular(effect, x, *args):
    """Run a stateful effect over two tiled periods and keep the second."""
    n = len(x)
    return effect(x + x, *args)[n:]


def saw(phase, harmonics):
    """Band-limited saw from a few partials (no aliasing at 16 kHz)."""
    return sum(math.sin(TAU * k * phase) / k for k in range(1, harmonics + 1))


def square(phase, harmonics):
    return sum(math.sin(TAU * k * phase) / k
               for k in range(1, 2 * harmonics, 2))


def synth_note(freq, dur, rate, wave_fn, harmonics, attack=0.004,
               decay=6.0, release=0.02, detune=0.0):
    n = int(dur * rate)
    out = []
    for i in range(n):
        t = i / rate
        ph = freq * t
        v = wave_fn(ph, harmonics)
        if detune:
            v = 0.5 * (v + wave_fn(ph * (1 + detune), harmonics))
        out.append(v * envelope_rate(i, n, attack, release, rate)
                   * math.exp(-t * decay))
    return out


def envelope_rate(i, n, attack, release, rate):
    a = max(1, int(attack * rate))
    r = max(1, int(release * rate))
    gain = 1.0
    if i < a:
        gain = i / a
    if i > n - r:
        gain = min(gain, max(0.0, (n - i) / r))
    return gain


# --------------------------------------------------------------------------
# New one-shots
# --------------------------------------------------------------------------

def near_miss():
    """Band-passed noise whoosh sweeping up, topped with a short zing."""
    rng = random.Random(21)
    n = int(0.42 * RATE)
    out = []
    lp1 = lp2 = 0.0
    phase = 0.0
    for i in range(n):
        t = i / RATE
        cutoff = 600 + 5200 * (t / 0.42)
        a = 1.0 - math.exp(-TAU * cutoff / RATE)
        noise = rng.uniform(-1.0, 1.0)
        lp1 += a * (noise - lp1)
        lp2 += 0.04 * (lp1 - lp2)
        whoosh = (lp1 - lp2) * math.sin(math.pi * min(1.0, t / 0.42)) * 1.4
        freq = 1400 + 1800 * min(1.0, t / 0.12)
        phase += freq / RATE
        zing = math.sin(TAU * phase) * 0.35 * math.exp(-max(0.0, t - 0.05) * 14) \
            * min(1.0, t / 0.05)
        out.append((whoosh + zing) * envelope(i, n, 0.005, 0.08))
    return out


def spark():
    """Glassy two-note chime (E6 then B6)."""
    out = [0.0] * int(0.45 * RATE)
    for start, note in ((0.0, 88), (0.07, 95)):
        f = midi_hz(note)
        n = int(0.36 * RATE)
        tone = []
        for i in range(n):
            t = i / RATE
            v = (math.sin(TAU * f * t) + 0.4 * math.sin(TAU * 2 * f * t)
                 + 0.15 * math.sin(TAU * 3.01 * f * t))
            tone.append(v * math.exp(-t * 11) * envelope(i, n, 0.002, 0.04))
        mix_into(out, tone, int(start * RATE))
    return out


def multiplier():
    """Rising square blips: A5 C#6 E6 A6."""
    out = [0.0] * int(0.5 * RATE)
    for k, note in enumerate((81, 85, 88, 93)):
        tone = synth_note(midi_hz(note), 0.14, RATE, square, 6,
                          attack=0.002, decay=14, release=0.03)
        mix_into(out, [0.6 * v for v in tone], int(k * 0.055 * RATE))
    return lowpass(out, 7000, RATE)


def mission():
    """Bright detuned saw stab on an A major add9 chord."""
    out = [0.0] * int(0.7 * RATE)
    for note in (69, 73, 76, 83):
        tone = synth_note(midi_hz(note), 0.65, RATE, saw, 10, attack=0.004,
                          decay=5.0, release=0.12, detune=0.006)
        mix_into(out, tone, 0)
    return lowpass(out, 4200, RATE)


def level_up():
    """Rising arpeggio A4 C#5 E5 A5 C#6 E6 then a held A6 chord."""
    out = [0.0] * int(1.25 * RATE)
    for k, note in enumerate((69, 73, 76, 81, 85, 88)):
        tone = synth_note(midi_hz(note), 0.22, RATE, square, 5,
                          attack=0.003, decay=8, release=0.05)
        mix_into(out, [0.5 * v for v in tone], int(k * 0.07 * RATE))
    for note in (81, 85, 88, 93):
        tone = synth_note(midi_hz(note), 0.75, RATE, saw, 8, attack=0.01,
                          decay=3.2, release=0.25, detune=0.005)
        mix_into(out, [0.45 * v for v in tone], int(0.42 * RATE))
    return lowpass(out, 6000, RATE)


# --------------------------------------------------------------------------
# Music: driving synthwave loop
# --------------------------------------------------------------------------
# 120 bpm, 4/4, 8 bars = 16 s. Progression (2 bars each):
#   Am | F | C | G   -> G resolves back into Am at the loop point.
# Octave-pumping eighth-note saw bass, four-on-the-floor kick, snare on 2 and
# 4, off-beat hats, a detuned pad ducked by the kick, and a sixteenth-note
# arpeggio with a dotted-eighth echo.

BPM = 120.0
BEAT = 60.0 / BPM
BARS = 8
CHORDS = [  # (bass root midi, chord tones for pad/arp)
    (45, (57, 60, 64)),   # Am
    (41, (57, 60, 65)),   # F
    (48, (55, 60, 64)),   # C
    (43, (55, 59, 62)),   # G
]


def music_loop():
    rate = MUSIC_RATE
    total = int(BARS * 4 * BEAT * rate)
    bass = [0.0] * total
    pad = [0.0] * total
    arp = [0.0] * total
    drums = [0.0] * total
    duck = [1.0] * total
    rng = random.Random(1984)
    eighth = BEAT / 2
    six = BEAT / 4

    for bar in range(BARS):
        root, tones = CHORDS[(bar // 2) % len(CHORDS)]
        bar_start = bar * 4 * BEAT
        # Bass: root / octave eighths.
        for e in range(8):
            note = root + (12 if e % 2 else 0)
            tone = synth_note(midi_hz(note), eighth * 0.92, rate, saw, 12,
                              attack=0.003, decay=3.5, release=0.02)
            mix_into(bass, tone, int((bar_start + e * eighth) * rate), wrap=True)
        # Arp: 16ths over the chord, up two octaves pattern.
        pattern = [0, 1, 2, 1, 0, 2, 1, 2, 0, 1, 2, 1, 2, 1, 0, 2]
        for k in range(16):
            octave = 12 if k % 8 >= 4 else 0
            note = tones[pattern[k]] + 12 + octave
            tone = synth_note(midi_hz(note), six * 0.8, rate, square, 4,
                              attack=0.002, decay=9, release=0.015)
            mix_into(arp, tone, int((bar_start + k * six) * rate), wrap=True)
        # Pad: one sustained chord per two bars.
        if bar % 2 == 0:
            for note in tones:
                tone = synth_note(midi_hz(note), 8 * BEAT, rate, saw, 6,
                                  attack=0.6, decay=0.05, release=0.6,
                                  detune=0.007)
                mix_into(pad, tone, int(bar_start * rate), wrap=True)
        # Drums.
        for beat in range(4):
            t0 = int((bar_start + beat * BEAT) * rate)
            kick_n = int(0.28 * rate)
            phase = 0.0
            kick = []
            for i in range(kick_n):
                t = i / rate
                f = 48 + 110 * math.exp(-t * 32)
                phase += f / rate
                kick.append(math.sin(TAU * phase) * math.exp(-t * 9)
                            * envelope_rate(i, kick_n, 0.001, 0.03, rate))
            mix_into(drums, [1.1 * v for v in kick], t0, wrap=True)
            # Sidechain-style duck for pad and bass.
            for i in range(int(0.22 * rate)):
                g = 0.45 + 0.55 * (i / (0.22 * rate))
                j = (t0 + i) % total
                duck[j] = min(duck[j], g)
            if beat in (1, 3):
                sn_n = int(0.22 * rate)
                snare = []
                for i in range(sn_n):
                    t = i / rate
                    snare.append((rng.uniform(-1, 1) * 0.7
                                  + 0.4 * math.sin(TAU * 190 * t))
                                 * math.exp(-t * 16)
                                 * envelope_rate(i, sn_n, 0.001, 0.03, rate))
                mix_into(drums, [0.55 * v for v in snare], t0, wrap=True)
            hat_t = int((bar_start + beat * BEAT + eighth) * rate)
            hat_n = int(0.05 * rate)
            hat = [rng.uniform(-1, 1) * math.exp(-(i / rate) * 70)
                   for i in range(hat_n)]
            hat = highpass(hat, 5000, rate)
            mix_into(drums, [0.35 * v for v in hat], hat_t, wrap=True)

    bass = circular(lowpass, bass, 900, rate)
    pad = circular(lowpass, pad, 1800, rate)
    arp = circular(lowpass, arp, 3200, rate)
    echo = circular(feedback_delay, arp, int(round(six * 3 * rate)), 0.4,
                    2000, rate)
    mix = []
    for i in range(total):
        d = duck[i]
        mix.append(0.55 * bass[i] * d + 0.22 * pad[i] * d
                   + 0.16 * (arp[i] + 0.5 * echo[i]) + 0.5 * drums[i])
    return circular(highpass, mix, 30, rate)


SOUNDS = {
    "crash": (crash, RATE, PEAK),
    "near_miss": (near_miss, RATE, PEAK),
    "spark": (spark, RATE, PEAK),
    "multiplier": (multiplier, RATE, PEAK),
    "mission": (mission, RATE, PEAK),
    "level_up": (level_up, RATE, PEAK),
    "music_loop": (music_loop, MUSIC_RATE, MUSIC_PEAK),
}


def write_wav(path, samples, rate=RATE, peak_target=PEAK):
    peak = max(abs(s) for s in samples) or 1.0
    scale = peak_target / peak
    with wave.open(path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(rate)
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
    for name, (build, rate, peak) in SOUNDS.items():
        path = os.path.join(target, name + ".wav")
        write_wav(path, build(), rate, peak)
        print("wrote", os.path.relpath(path, root), os.path.getsize(path), "bytes")


if __name__ == "__main__":
    main()
