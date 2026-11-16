#!/usr/bin/env python3
"""Generates the game's music: ten seamless loops synthesised from scratch (pads, electric piano,
plucks, bass, soft drums, rain), so every track is original and owned by the project.

Needs numpy; encodes to Ogg Vorbis with ffmpeg (falls back to WAV without it).
Run from the project root:  python3 tools/generate_music.py
Output goes to assets/music/. Each track's reverb tail is wrapped back into its start, so it loops
without a click.
"""
import os
import shutil
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "music")
TAIL = 4.0


def midi(note):
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def chord(root, kind):
    shapes = {
        "maj7": [0, 4, 7, 11], "maj9": [0, 4, 7, 11, 14], "m7": [0, 3, 7, 10], "m9": [0, 3, 7, 10, 14],
        "7": [0, 4, 7, 10], "13": [0, 4, 10, 14, 21], "7b9": [0, 4, 7, 10, 13], "6": [0, 4, 7, 9],
        "add9": [0, 4, 7, 14], "m": [0, 3, 7], "sus2": [0, 2, 7], "5": [0, 7, 12],
    }
    return [root + i for i in shapes[kind]]


class Track:
    """A stereo buffer with helpers to place notes in beats; rendered with reverb and looped."""

    def __init__(self, bpm, bars, seed):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.length = bars * 4 * self.beat
        self.buf = np.zeros((int((self.length + TAIL) * SR), 2))
        self.rng = np.random.default_rng(seed)

    def add(self, signal, start_beat, pan=0.0, gain=1.0):
        start = int(start_beat * self.beat * SR)
        end = min(start + len(signal), len(self.buf))
        if start >= len(self.buf):
            return
        piece = signal[: end - start] * gain
        self.buf[start:end, 0] += piece * np.sqrt(0.5 * (1.0 - pan))
        self.buf[start:end, 1] += piece * np.sqrt(0.5 * (1.0 + pan))

    def add_noise_bed(self, gain, low, high, pan_drift=0.0):
        """Filtered noise across the whole track (rain, hiss, city hum)."""
        n = len(self.buf)
        for ch in range(2):
            spectrum = np.fft.rfft(self.rng.standard_normal(n))
            freqs = np.fft.rfftfreq(n, 1.0 / SR)
            spectrum *= ((freqs > low) & (freqs < high)) / np.sqrt(np.maximum(freqs, 20.0) / low)
            self.buf[:, ch] += np.fft.irfft(spectrum, n) * gain * (1.0 + pan_drift * (1 if ch else -1))

    def render(self, reverb=0.25, decay=2.2, lowpass=None):
        out = self.buf.copy()
        if reverb > 0.0:
            ir_len = int(decay * SR)
            t = np.arange(ir_len) / SR
            for ch in range(2):
                ir = self.rng.standard_normal(ir_len) * np.exp(-t * 6.9 / decay)
                ir[: int(0.02 * SR)] = 0.0
                size = len(out) + ir_len
                wet = np.fft.irfft(np.fft.rfft(out[:, ch], size) * np.fft.rfft(ir, size), size)[: len(out)]
                out[:, ch] += wet * reverb / np.max(np.abs(ir)) * 0.06
        if lowpass:
            freqs = np.fft.rfftfreq(len(out), 1.0 / SR)
            curve = 1.0 / np.sqrt(1.0 + (freqs / lowpass) ** 4)
            for ch in range(2):
                out[:, ch] = np.fft.irfft(np.fft.rfft(out[:, ch]) * curve, len(out))
        loop = int(self.length * SR)
        tail = out[loop:]
        out = out[:loop]
        out[: len(tail)] += tail
        out = np.tanh(out / (np.max(np.abs(out)) + 1e-9) * 1.2) * 0.85
        return out


# --- Instruments -----------------------------------------------------------------------------

def envelope(n, attack, release, hold=None):
    t = np.arange(n) / SR
    env = np.minimum(1.0, t / max(attack, 1e-4))
    if hold is not None:
        env *= np.where(t > hold, np.exp(-(t - hold) / max(release, 1e-4)), 1.0)
    else:
        env *= np.exp(-t / max(release, 1e-4))
    return env


def additive(freq, seconds, harmonics, rolloff=1.0, detune=0.0, phase_seed=0):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    rng = np.random.default_rng(phase_seed)
    for k in range(1, harmonics + 1):
        if freq * k > SR * 0.45:
            break
        for d in ((-detune, detune) if detune else (0.0,)):
            out += np.sin(2 * np.pi * freq * k * (1 + d) * t + rng.uniform(0, 6.28)) / (k ** rolloff)
    return out


def pad(freqs, seconds, brightness=6, detune=0.003):
    sig = sum(additive(f, seconds, brightness, 1.2, detune, i) for i, f in enumerate(freqs))
    return sig * envelope(len(sig), seconds * 0.35, seconds * 0.3, hold=seconds * 0.6) / len(freqs)


def epiano(freq, seconds=1.6, tremolo=0.0):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    mod = np.sin(2 * np.pi * freq * 2.0 * t) * 1.6 * np.exp(-t * 5.0)
    tone = np.sin(2 * np.pi * freq * t + mod) + 0.25 * np.sin(2 * np.pi * freq * 4.0 * t) * np.exp(-t * 9.0)
    if tremolo:
        tone *= 1.0 - tremolo * (0.5 + 0.5 * np.sin(2 * np.pi * 5.0 * t))
    return tone * envelope(n, 0.004, 1.1) * 0.5


def pluck(freq, seconds=0.9, brightness=8, decay=0.35):
    sig = additive(freq, seconds, brightness, 1.6)
    return sig * envelope(len(sig), 0.002, decay) * 0.5


def koto(freq, seconds=1.4):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    bend = 1.0 + 0.012 * np.exp(-t * 18.0)
    sig = sum(np.sin(2 * np.pi * freq * k * bend * t) * np.exp(-t * (2.5 + k * 1.5)) / k for k in range(1, 7))
    return sig * envelope(n, 0.001, 0.9) * 0.6


def bell(freq, seconds=2.5):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    sig = sum(np.sin(2 * np.pi * freq * r * t) * np.exp(-t * d) * a for r, d, a in ((1, 1.2, 1.0), (2.76, 2.5, 0.4), (5.4, 5.0, 0.2)))
    return sig * envelope(n, 0.002, 2.0) * 0.4


def lead(freq, seconds, vibrato=0.006, harmonics=7):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    wobble = 1.0 + vibrato * np.sin(2 * np.pi * 5.2 * t) * np.minimum(1.0, t / 0.3)
    phase = 2 * np.pi * freq * np.cumsum(wobble) / SR
    sig = sum(np.sin(phase * k) / k ** 1.4 for k in range(1, harmonics + 1))
    return sig * envelope(n, 0.04, seconds * 0.4, hold=seconds * 0.7) * 0.4


def bass(freq, seconds=0.5, harmonics=4):
    sig = additive(freq, seconds, harmonics, 1.8)
    return sig * envelope(len(sig), 0.005, seconds * 0.6, hold=seconds * 0.5) * 0.7


def kick(punch=1.0, length=0.35):
    n = int(length * SR)
    t = np.arange(n) / SR
    sig = np.sin(2 * np.pi * (45 * t + 110 / 30.0 * (1 - np.exp(-t * 30)))) * np.exp(-t / (0.12 * punch))
    return sig * 0.9


def snare(rng, length=0.25, tone=0.3):
    n = int(length * SR)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    noise = np.convolve(noise, np.ones(4) / 4, mode="same")
    return (noise * np.exp(-t / 0.06) * 0.5 + np.sin(2 * np.pi * 190 * t) * np.exp(-t / 0.04) * tone)


def hat(rng, length=0.06, open_=False):
    n = int((0.25 if open_ else length) * SR)
    t = np.arange(n) / SR
    noise = np.diff(rng.standard_normal(n + 1))
    return noise * np.exp(-t / (0.08 if open_ else 0.015)) * 0.18


def shaker(rng):
    n = int(0.09 * SR)
    t = np.arange(n) / SR
    return np.diff(rng.standard_normal(n + 1)) * np.sin(np.pi * t / t[-1]) * 0.08


def metal_hit(rng, length=0.6):
    n = int(length * SR)
    t = np.arange(n) / SR
    sig = sum(np.sin(2 * np.pi * f * t) for f in rng.uniform(300, 2600, 6)) * np.exp(-t / 0.15)
    return sig * 0.12


def crackle(track, gain=0.02, density=30):
    n = len(track.buf)
    clicks = np.zeros(n)
    positions = track.rng.integers(0, n, int(density * n / SR))
    clicks[positions] = track.rng.uniform(-1, 1, len(positions))
    clicks = np.convolve(clicks, [1.0, -0.6, 0.2], mode="same") * gain
    track.buf[:, 0] += clicks
    track.buf[:, 1] += np.roll(clicks, 37)


def drums(track, bars, pattern, swing=0.0, gains=(1.0, 0.7, 1.0)):
    """pattern: 16 steps of 'k', 's', 'h', 'H' (open hat), 'r' (rim) or '.' per bar."""
    for bar in range(bars):
        for step, hit in enumerate(pattern):
            beat = bar * 4 + step * 0.25 + (swing * 0.25 if step % 2 else 0.0)
            if "k" in hit:
                track.add(kick(), beat, 0.0, gains[0])
            if "s" in hit:
                track.add(snare(track.rng), beat, 0.05, gains[1])
            if "h" in hit:
                track.add(hat(track.rng), beat, 0.25, gains[2])
            if "H" in hit:
                track.add(hat(track.rng, open_=True), beat, 0.25, gains[2])
            if "r" in hit:
                track.add(snare(track.rng, 0.08, 0.6) * 0.5, beat, -0.2, gains[1])


def walking_bass(track, progression, beats_per_chord, octave_shift=-24, gain=0.9):
    beat = 0.0
    for root, kind in progression:
        notes = chord(root, kind)
        for i in range(beats_per_chord):
            note = [notes[0], notes[1], notes[2], notes[0] + 12][i % 4] + octave_shift
            track.add(bass(midi(note), track.beat * 0.95), beat + i, 0.0, gain)
        beat += beats_per_chord


# --- Tracks ----------------------------------------------------------------------------------

def street():
    tr = Track(72, 16, 1)
    prog = [(53, "maj9"), (52, "m7"), (50, "m9"), (48, "maj7")]
    for i in range(8):
        root, kind = prog[i % 4]
        tr.add(pad([midi(n) for n in chord(root, kind)], tr.beat * 8.6), i * 8, 0.0, 0.55)
        tr.add(bass(midi(root - 12), tr.beat * 7.5, 3), i * 8, 0.0, 0.5)
        notes = chord(root + 12, kind)
        for step in range(16):
            if tr.rng.random() < 0.55:
                note = notes[(step * 2 + i) % len(notes)] + (12 if step % 5 == 0 else 0)
                tr.add(pluck(midi(note), 1.2, 4, 0.5), i * 8 + step * 0.5, float(np.sin(step)) * 0.6, 0.18)
    tr.add_noise_bed(0.012, 600, 7000)
    tr.add_noise_bed(0.03, 40, 160)
    return tr.render(0.45, 3.2, 6000)


def elevator():
    tr = Track(104, 16, 2)
    prog = [(50, "m9"), (55, "13"), (48, "maj9"), (57, "7b9")]
    for bar in range(16):
        root, kind = prog[bar % 4]
        for hit in (0, 1.5, 2.5):
            for note in chord(root, kind):
                tr.add(epiano(midi(note), 1.4, 0.25), bar * 4 + hit, 0.2, 0.22)
        tr.add(bass(midi(root - 24), tr.beat * 1.4), bar * 4, 0.0, 0.8)
        tr.add(bass(midi(root - 17), tr.beat * 0.9), bar * 4 + 1.5, 0.0, 0.6)
        tr.add(bass(midi(root - 24), tr.beat * 0.9), bar * 4 + 2.5, 0.0, 0.6)
        for step in range(8):
            tr.add(shaker(tr.rng), bar * 4 + step * 0.5, 0.4, 1.0)
        tr.add(snare(tr.rng, 0.08, 0.6) * 0.4, bar * 4 + 1.0, -0.3, 0.6)
        tr.add(snare(tr.rng, 0.08, 0.6) * 0.4, bar * 4 + 2.75, -0.3, 0.5)
    melody = [74, 76, 77, 79, 81, None, 79, 77, 76, None, 74, 72, 74, None, None, None]
    for phrase in (4, 12):
        for i, note in enumerate(melody):
            if note:
                tr.add(lead(midi(note), tr.beat * 0.9, 0.008, 3), phrase * 4 + i * 0.5, -0.2, 0.32)
    return tr.render(0.3, 1.8, 7000)


def noodle():
    tr = Track(80, 16, 3)
    prog = [(57, "m9"), (50, "m9"), (55, "7"), (48, "maj7")]
    for bar in range(16):
        root, kind = prog[bar % 4]
        for hit in (0, 2.5):
            for note in chord(root, kind):
                tr.add(epiano(midi(note), 2.0, 0.15), bar * 4 + hit, -0.15, 0.2)
        tr.add(bass(midi(root - 24), tr.beat * 1.8, 3), bar * 4, 0.0, 0.75)
        tr.add(bass(midi(root - 24), tr.beat * 0.8, 3), bar * 4 + 2.75, 0.0, 0.5)
    drums(tr, 16, ["k", ".", "h", ".", "s", ".", "h", "k", ".", "k", "h", ".", "s", ".", "h", "h"], 0.12, (0.8, 0.55, 0.7))
    crackle(tr, 0.04)
    tr.add_noise_bed(0.006, 1000, 6000)
    return tr.render(0.2, 1.5, 4200)


def bar():
    tr = Track(92, 16, 4)
    prog = [(48, "m9"), (53, "13"), (46, "maj9"), (51, "maj7")]
    walking_bass(tr, prog * 4, 4)
    for bar_index in range(16):
        root, kind = prog[bar_index % 4]
        for hit in (1.5, 3.0):
            for note in chord(root + 12, kind)[:4]:
                tr.add(epiano(midi(note), 1.2), bar_index * 4 + hit, 0.25, 0.16)
        for beat in range(4):
            tr.add(hat(tr.rng, open_=True) * 0.6, bar_index * 4 + beat, -0.3, 1.0)
            tr.add(hat(tr.rng) * 0.8, bar_index * 4 + beat + 0.66, -0.3, 1.0)
    phrase = [72, 75, 77, 79, 82, 79, 77, 75, 74, 70, 72, None]
    for start in (8, 40):
        for i, note in enumerate(phrase):
            if note:
                tr.add(lead(midi(note), tr.beat * 1.3, 0.01, 6), start + i * 1.0, -0.15, 0.3)
    return tr.render(0.35, 2.0, 5500)


def cyberware():
    tr = Track(110, 16, 5)
    prog = [(50, "m"), (46, "maj7"), (48, "sus2"), (45, "m")]
    for bar_index in range(16):
        root, kind = prog[bar_index % 4]
        tr.add(pad([midi(n) for n in chord(root - 12, kind)], tr.beat * 4.4, 4, 0.006), bar_index * 4, 0.0, 0.35)
        notes = chord(root + 12, kind)
        for step in range(16):
            if tr.rng.random() < 0.8:
                repeat = 2 if tr.rng.random() < 0.15 else 1
                for r in range(repeat):
                    tr.add(pluck(midi(notes[step % len(notes)]), 0.25, 3, 0.08), bar_index * 4 + step * 0.25 + r * 0.125, float(np.sin(step * 1.7)) * 0.7, 0.2)
    drums(tr, 16, ["k", ".", "h", ".", ".", ".", "hr", ".", "k", ".", "h", "k", ".", ".", "hr", "."], 0.0, (0.7, 0.5, 0.6))
    return tr.render(0.25, 1.4, 6500)


def clinic():
    tr = Track(66, 8, 6)
    prog = [(60, "add9"), (55, "6"), (57, "m7"), (53, "maj7")]
    for i in range(8):
        root, kind = prog[i % 4]
        tr.add(pad([midi(n) for n in chord(root - 12, kind)], tr.beat * 4.6, 3, 0.002), i * 4, 0.0, 0.5)
        for j, note in enumerate(chord(root + 12, kind)):
            if tr.rng.random() < 0.6:
                tr.add(bell(midi(note)), i * 4 + j * 1.0, float(j % 2) * 0.6 - 0.3, 0.25)
    return tr.render(0.5, 3.5, 8000)


def guns():
    tr = Track(96, 16, 7)
    for bar_index in range(16):
        root = 40 if bar_index % 4 != 3 else 41
        tr.add(bass(midi(root - 12), tr.beat * 3.8, 6), bar_index * 4, 0.0, 0.7)
        for step in (0, 0.75, 1.5, 2.5, 3.25):
            tr.add(np.tanh(kick(1.4) * 3.0) * 0.6, bar_index * 4 + step, 0.0, 0.9)
        tr.add(metal_hit(tr.rng), bar_index * 4 + 1.0, -0.4, 0.8)
        tr.add(metal_hit(tr.rng), bar_index * 4 + 3.0, 0.4, 0.8)
        for step in range(8):
            tr.add(hat(tr.rng) * 0.7, bar_index * 4 + step * 0.5 + 0.25, 0.3, 1.0)
    tr.add_noise_bed(0.015, 50, 400)
    return tr.render(0.2, 1.2, 4000)


def pawn():
    tr = Track(86, 16, 8)
    prog = [(52, "m7"), (57, "7"), (50, "m7"), (55, "7")]
    for bar_index in range(16):
        root, kind = prog[bar_index % 4]
        for hit in (0.5, 1.75, 2.5, 3.5):
            for note in chord(root + 12, kind)[:3]:
                tr.add(pluck(midi(note) * 1.003, 0.3, 9, 0.09), bar_index * 4 + hit, 0.3, 0.15)
        for hit, note in ((0, root - 24), (0.75, root - 24), (1.5, root - 12), (2.5, root - 17), (3.25, root - 19)):
            tr.add(bass(midi(note), tr.beat * 0.6), bar_index * 4 + hit, 0.0, 0.75)
    drums(tr, 16, ["k", ".", "h", "h", "s", ".", "h", ".", ".", "k", "h", "k", "s", ".", "h", "h"], 0.15, (0.8, 0.6, 0.6))
    crackle(tr, 0.03)
    return tr.render(0.2, 1.4, 5000)


def sushi():
    tr = Track(76, 8, 9)
    scale = [62, 64, 65, 69, 70, 74, 76, 77, 81]
    for bar_index in range(8):
        tr.add(pad([midi(n) for n in (50, 57, 62, 65)], tr.beat * 4.5, 3, 0.003), bar_index * 4, 0.0, 0.4)
        for step in range(8):
            if tr.rng.random() < 0.6:
                note = scale[int(tr.rng.integers(0, len(scale)))]
                tr.add(koto(midi(note)), bar_index * 4 + step * 0.5, float(np.cos(step)) * 0.5, 0.3)
        tr.add(snare(tr.rng, 0.06, 0.9) * 0.3, bar_index * 4 + 3.5, 0.4, 0.7)
    return tr.render(0.4, 2.8, 7000)


def apartment_radio():
    tr = Track(70, 8, 10)
    prog = [(53, "maj7"), (55, "6"), (52, "m7"), (57, "m9")]
    for bar_index in range(8):
        root, kind = prog[bar_index % 4]
        for note in chord(root, kind):
            tr.add(epiano(midi(note), 3.0, 0.1), bar_index * 4, 0.0, 0.2)
            tr.add(epiano(midi(note), 1.5, 0.1), bar_index * 4 + 2.5, 0.0, 0.12)
        tr.add(bass(midi(root - 24), tr.beat * 3.5, 3), bar_index * 4, 0.0, 0.6)
        for step in range(8):
            tr.add(shaker(tr.rng) * 0.6, bar_index * 4 + step * 0.5, 0.0, 1.0)
    tr.add_noise_bed(0.01, 2000, 5000)
    out = tr.render(0.25, 1.6, None)
    # Small radio speaker: thin band, slightly narrow.
    freqs = np.fft.rfftfreq(len(out), 1.0 / SR)
    band = ((freqs > 250) & (freqs < 4200)).astype(float)
    for ch in range(2):
        out[:, ch] = np.fft.irfft(np.fft.rfft(out[:, ch]) * band, len(out))
    mid = out.mean(axis=1, keepdims=True)
    return np.tanh((mid + (out - mid) * 0.3) * 1.5) * 0.8


TRACKS = {
    "street": street, "elevator": elevator, "noodle": noodle, "bar": bar, "cyberware": cyberware,
    "clinic": clinic, "guns": guns, "pawn": pawn, "sushi": sushi, "apartment_radio": apartment_radio,
}


def write(name, samples):
    os.makedirs(OUT_DIR, exist_ok=True)
    pcm = (np.clip(samples, -1, 1) * 32767).astype("<i2")
    ffmpeg = shutil.which("ffmpeg")
    target = os.path.join(OUT_DIR, name + (".ogg" if ffmpeg else ".wav"))
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = os.path.join(tmp, name + ".wav") if ffmpeg else target
        with wave.open(wav_path, "wb") as f:
            f.setnchannels(2)
            f.setsampwidth(2)
            f.setframerate(SR)
            f.writeframes(pcm.tobytes())
        if ffmpeg:
            subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", "4", target], check=True)
    print("wrote", target, "(%.1f s)" % (len(samples) / SR))


def main():
    for name, make in TRACKS.items():
        write(name, make())


if __name__ == "__main__":
    main()
