#!/usr/bin/env python3
"""Generates the game's placeholder sound effects as 16-bit mono WAV files.

Everything is synthesised from noise and sine waves, so the sounds are original and free to use.
Run from the project root:  python3 tools/generate_sfx.py
Output goes to assets/audio/. Swap any file for a real recording with the same name later.
"""
import math
import os
import random
import struct
import wave

SAMPLE_RATE = 22050  # Slightly lo-fi on purpose, to match the retro look.
OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio")


def seconds(duration):
    return int(duration * SAMPLE_RATE)


def noise(n, rng):
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def lowpass(samples, cutoff):
    """One-pole low-pass filter."""
    rc = 1.0 / (2.0 * math.pi * cutoff)
    alpha = (1.0 / SAMPLE_RATE) / (rc + 1.0 / SAMPLE_RATE)
    out, y = [], 0.0
    for x in samples:
        y += alpha * (x - y)
        out.append(y)
    return out


def highpass(samples, cutoff):
    low = lowpass(samples, cutoff)
    return [x - l for x, l in zip(samples, low)]


def envelope(n, attack, decay):
    """Exponential decay with a short linear attack (both in seconds)."""
    a = max(1, seconds(attack))
    return [(i / a if i < a else 1.0) * math.exp(-(i / SAMPLE_RATE) / decay) for i in range(n)]


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]


def place(track, offset, length):
    """Returns `track` shifted to start at `offset` seconds inside a buffer of `length` seconds."""
    out = [0.0] * seconds(length)
    start = seconds(offset)
    for i, v in enumerate(track):
        if start + i < len(out):
            out[start + i] += v
    return out


def normalize(samples, peak=0.89):
    m = max(abs(s) for s in samples) or 1.0
    return [s / m * peak for s in samples]


def soft_clip(samples, drive):
    return [math.tanh(s * drive) for s in samples]


def crossfade_loop(samples, fade):
    """Makes a seamless loop by fading the tail into the head; the result is `fade` shorter."""
    f = seconds(fade)
    body = samples[:-f]
    for i in range(f):
        t = i / f
        body[i] = body[i] * t + samples[len(samples) - f + i] * (1.0 - t)
    return body


def write(name, samples):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name)
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SAMPLE_RATE)
        f.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples))
    print("wrote", path)


def click(rng, freq=2600.0, length=0.05, decay=0.008):
    n = seconds(length)
    env = envelope(n, 0.0005, decay)
    ring = [math.sin(2 * math.pi * freq * i / SAMPLE_RATE) for i in range(n)]
    hiss = highpass(noise(n, rng), 1500)
    return [(r * 0.6 + h * 0.5) * e for r, h, e in zip(ring, hiss, env)]


def rifle_shot(rng):
    n = seconds(0.6)
    crack = [s * e for s, e in zip(highpass(noise(n, rng), 1200), envelope(n, 0.0005, 0.012))]
    body = [s * e * 1.4 for s, e in zip(lowpass(noise(n, rng), 1800), envelope(n, 0.001, 0.07))]
    thump = []
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 45.0 + 110.0 * math.exp(-t * 30.0)
        phase += 2 * math.pi * freq / SAMPLE_RATE
        thump.append(math.sin(phase) * math.exp(-t / 0.07) * 1.2)
    # Street echo: a quieter, darker copy of the blast bouncing off the buildings.
    tail = [s * e * 0.35 for s, e in zip(lowpass(noise(n, rng), 700), envelope(n, 0.03, 0.22))]
    return normalize(soft_clip(mix(crack, body, thump, tail), 1.8))


def reload_sound(rng):
    mag_out = mix(click(rng, 1900, 0.08, 0.012), place(click(rng, 1200, 0.08, 0.02), 0.03, 0.12))
    mag_in = mix(click(rng, 2400, 0.06, 0.01), place(click(rng, 3000, 0.06, 0.006), 0.05, 0.12))
    slide_n = seconds(0.18)
    slide = [s * (math.sin(math.pi * i / slide_n) ** 2) * 0.35 for i, s in enumerate(lowpass(noise(slide_n, rng), 3000))]
    bolt = mix(slide, place(click(rng, 3300, 0.07, 0.01), 0.17, 0.25))
    total = 1.95
    return normalize(mix(place(mag_out, 0.15, total), place(mag_in, 0.95, total), place(bolt, 1.5, total)), 0.75)


def dry_fire(rng):
    return normalize(click(rng, 3200, 0.07, 0.006), 0.6)


def footstep(rng):
    n = seconds(0.16)
    scuff = [s * e for s, e in zip(lowpass(noise(n, rng), 900), envelope(n, 0.003, 0.03))]
    grit = [s * e * 0.25 for s, e in zip(highpass(noise(n, rng), 3000), envelope(n, 0.002, 0.015))]
    return normalize(mix(scuff, grit), 0.5)


def city_ambience(rng):
    length = 12.0
    n = seconds(length)
    # Brown-ish rumble of distant traffic and machinery.
    brown, y = [], 0.0
    for v in noise(n, rng):
        y = (y + v * 0.02) * 0.995
        brown.append(y)
    rumble = lowpass(normalize(brown), 400)
    hum = [0.12 * math.sin(2 * math.pi * 50 * i / SAMPLE_RATE) * (0.7 + 0.3 * math.sin(i / SAMPLE_RATE * 0.9)) for i in range(n)]
    # A far-away siren gliding once through the loop.
    siren = []
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 650 + 180 * math.sin(t * 2.4)
        phase += 2 * math.pi * freq / SAMPLE_RATE
        fade = math.exp(-((t - 6.0) / 2.2) ** 2)
        siren.append(math.sin(phase) * 0.05 * fade)
    return normalize(crossfade_loop(mix(rumble, hum, siren), 2.0), 0.5)


def neon_buzz(rng):
    n = seconds(2.0)
    buzz = []
    for i in range(n):
        t = i / SAMPLE_RATE
        base = sum(math.sin(2 * math.pi * 120 * k * t) / k for k in (1, 2, 3, 5, 7))
        crackle = rng.uniform(-1, 1) * 0.3 if rng.random() < 0.002 else 0.0
        buzz.append(base * 0.3 + crackle)
    return normalize(crossfade_loop(lowpass(buzz, 2500), 0.25), 0.35)


def dragon_hum(rng):
    n = seconds(6.0)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        wobble = 1.0 + 0.04 * math.sin(t * 2 * math.pi * 0.5)
        tone = sum(math.sin(2 * math.pi * 55 * k * wobble * t) / (k * k) for k in (1, 2, 3, 4))
        out.append(tone)
    whine = [0.08 * math.sin(2 * math.pi * 880 * i / SAMPLE_RATE) * (0.5 + 0.5 * math.sin(i / SAMPLE_RATE * 1.3)) for i in range(n)]
    air = [s * 0.4 for s in lowpass(noise(n, rng), 500)]
    return normalize(crossfade_loop(mix(out, whine, air), 1.0), 0.6)


def glass_shatter(rng):
    length = 1.1
    n = seconds(length)
    crack = [s * e for s, e in zip(highpass(noise(n, rng), 2500), envelope(n, 0.0005, 0.018))]
    body = [s * e * 0.6 for s, e in zip(lowpass(noise(n, rng), 5000), envelope(n, 0.001, 0.06))]
    tinkles = [0.0] * n
    for _ in range(46):
        start = seconds(min(length - 0.1, rng.expovariate(1.0 / 0.16)))
        freq = rng.uniform(2400, 7800)
        decay = rng.uniform(0.012, 0.05)
        amp = rng.uniform(0.15, 0.5) * math.exp(-start / SAMPLE_RATE * 2.5)
        for i in range(seconds(decay * 5)):
            if start + i < n:
                tinkles[start + i] += amp * math.sin(2 * math.pi * freq * i / SAMPLE_RATE) * math.exp(-(i / SAMPLE_RATE) / decay)
    return normalize(lowpass(mix(crack, body, tinkles), 7000), 0.8)


def body_hit(rng):
    n = seconds(0.22)
    thump = []
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        phase += 2 * math.pi * (70 + 90 * math.exp(-t * 40)) / SAMPLE_RATE
        thump.append(math.sin(phase) * math.exp(-t / 0.05))
    slap = [s * e * 0.7 for s, e in zip(lowpass(noise(n, rng), 1600), envelope(n, 0.001, 0.025))]
    return normalize(soft_clip(mix(thump, slap), 1.5), 0.7)


def body_fall(rng):
    n = seconds(0.7)
    impact = [s * e for s, e in zip(lowpass(noise(n, rng), 500), envelope(n, 0.002, 0.09))]
    thud = [math.sin(2 * math.pi * 55 * i / SAMPLE_RATE) * math.exp(-(i / SAMPLE_RATE) / 0.08) for i in range(n)]
    rustle = [s * e * 0.25 for s, e in zip(highpass(lowpass(noise(n, rng), 3000), 600), envelope(n, 0.02, 0.18))]
    second = place([v * 0.4 for v in impact[: seconds(0.2)]], 0.16, 0.7)
    return normalize(mix(impact, thud, rustle, second), 0.65)


def metal_ping(rng, freqs, decay, length):
    n = seconds(length)
    ring = [sum(math.sin(2 * math.pi * f * i / SAMPLE_RATE) * a for f, a in freqs) * math.exp(-(i / SAMPLE_RATE) / decay) for i in range(n)]
    tick = [s * e for s, e in zip(highpass(noise(n, rng), 2000), envelope(n, 0.0005, 0.006))]
    return mix(ring, tick)


def prop_hit_metal(rng):
    return normalize(metal_ping(rng, [(1350, 0.6), (2230, 0.35), (3900, 0.2)], 0.06, 0.3), 0.6)


def prop_hit_wood(rng):
    n = seconds(0.15)
    knock = [s * e for s, e in zip(lowpass(noise(n, rng), 1200), envelope(n, 0.001, 0.02))]
    tone = [math.sin(2 * math.pi * 320 * i / SAMPLE_RATE) * math.exp(-(i / SAMPLE_RATE) / 0.03) * 0.5 for i in range(n)]
    return normalize(mix(knock, tone), 0.55)


def prop_break_metal(rng):
    crunch = [s * e for s, e in zip(lowpass(noise(seconds(0.9), rng), 2500), envelope(seconds(0.9), 0.002, 0.12))]
    clangs = [place(metal_ping(rng, [(rng.uniform(600, 1800), 0.6), (rng.uniform(2000, 3500), 0.3)], 0.12, 0.5), rng.uniform(0.0, 0.45), 1.0) for _ in range(4)]
    return normalize(soft_clip(mix(crunch, *clangs), 1.4), 0.75)


def prop_break_wood(rng):
    n = seconds(0.7)
    crack = [s * e for s, e in zip(highpass(lowpass(noise(n, rng), 3500), 300), envelope(n, 0.001, 0.05))]
    splinters = [place([v * 0.5 for v in lowpass(noise(seconds(0.08), rng), 2500)], rng.uniform(0.03, 0.4), 0.7) for _ in range(6)]
    return normalize(mix(crack, *splinters), 0.7)


def prop_break_concrete(rng):
    n = seconds(1.0)
    rumble = [s * e for s, e in zip(lowpass(noise(n, rng), 700), envelope(n, 0.003, 0.15))]
    bits = [place([v * 0.3 for v in lowpass(noise(seconds(0.05), rng), 1800)], rng.uniform(0.1, 0.8), 1.0) for _ in range(10)]
    return normalize(mix(rumble, *bits), 0.7)


def spark_zap(rng):
    n = seconds(0.25)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        buzz = math.sin(2 * math.pi * 120 * t) * (1 if rng.random() < 0.6 else -1)
        out.append(buzz * math.exp(-t / 0.06) * (0.5 + 0.5 * rng.random()))
    return normalize(lowpass(mix(out, [s * 0.4 for s in highpass(noise(n, rng), 3000)]), 6000), 0.5)


def explosion(rng):
    length = 2.8
    n = seconds(length)
    blast = [s * e for s, e in zip(lowpass(noise(n, rng), 1200), envelope(n, 0.002, 0.18))]
    crack = [s * e * 0.8 for s, e in zip(highpass(noise(n, rng), 1500), envelope(n, 0.0008, 0.03))]
    boom = []
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        phase += 2 * math.pi * (32 + 70 * math.exp(-t * 8)) / SAMPLE_RATE
        boom.append(math.sin(phase) * math.exp(-t / 0.4) * 1.3)
    rumble = [s * e * 0.6 for s, e in zip(lowpass(noise(n, rng), 250), envelope(n, 0.05, 0.9))]
    rattles = [place([v * 0.25 for v in highpass(lowpass(noise(seconds(0.06), rng), 4000), 800)], rng.uniform(0.3, 1.8), length) for _ in range(14)]
    return normalize(soft_clip(mix(blast, crack, boom, rumble, *rattles), 2.2), 0.95)


def fire_loop(rng):
    n = seconds(4.0)
    roar = [s * 0.5 for s in lowpass(noise(n, rng), 400)]
    crackles = [0.0] * n
    for _ in range(140):
        start = rng.randrange(n - seconds(0.02))
        amp = rng.uniform(0.2, 0.7)
        for i in range(seconds(rng.uniform(0.003, 0.012))):
            crackles[start + i] += rng.uniform(-1, 1) * amp
    return normalize(crossfade_loop(mix(roar, highpass(crackles, 1200)), 0.5), 0.55)


def main():
    rng = random.Random(2077)
    write("rifle_shot.wav", rifle_shot(rng))
    write("rifle_reload.wav", reload_sound(rng))
    write("rifle_dry_fire.wav", dry_fire(rng))
    write("footstep.wav", footstep(rng))
    write("city_ambience.wav", city_ambience(rng))
    write("neon_buzz.wav", neon_buzz(rng))
    write("dragon_hum.wav", dragon_hum(rng))
    write("glass_shatter_1.wav", glass_shatter(rng))
    write("glass_shatter_2.wav", glass_shatter(rng))
    write("body_hit.wav", body_hit(rng))
    write("body_fall.wav", body_fall(rng))
    write("prop_hit_metal.wav", prop_hit_metal(rng))
    write("prop_hit_wood.wav", prop_hit_wood(rng))
    write("prop_break_metal.wav", prop_break_metal(rng))
    write("prop_break_wood.wav", prop_break_wood(rng))
    write("prop_break_concrete.wav", prop_break_concrete(rng))
    write("spark_zap.wav", spark_zap(rng))
    write("explosion.wav", explosion(rng))
    write("fire_loop.wav", fire_loop(rng))


if __name__ == "__main__":
    main()
