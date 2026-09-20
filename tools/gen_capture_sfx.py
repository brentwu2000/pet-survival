"""Deterministic capture placeholders; run with Python 3.10+, no packages."""

import math
from pathlib import Path
import struct
import wave

RATE = 44100
FADE = round(RATE * 0.002)  # Two milliseconds at both ends, including zero endpoints.
TARGET = 32768 * 10 ** (-3 / 20)
ROOT = Path(__file__).resolve().parent.parent


def noise(count, seed):
    """Fixed-seed 32-bit LCG, never dependent on global random state."""
    result = []
    for _ in range(count):
        seed = (1664525 * seed + 1013904223) & 0xFFFFFFFF
        result.append(seed / 2147483648 - 1)
    return result


def lowpass(samples, cutoff):
    state = 0.0
    result = []
    for i, sample in enumerate(samples):
        alpha = 1 - math.exp(-2 * math.pi * cutoff(i / RATE) / RATE)
        state += alpha * (sample - state)
        result.append(state)
    return result


def blank(seconds):
    return [0.0] * round(seconds * RATE)


def tone(out, start, duration, frequency, gain, decay, brightness=0.0):
    """Soft attack and release on each note as well as the finished file."""
    offset = round(start * RATE)
    count = round(duration * RATE)
    for i in range(min(count, len(out) - offset)):
        t = i / RATE
        envelope = min(1.0, i / FADE, (count - 1 - i) / FADE)
        phase = 2 * math.pi * frequency * t
        voice = math.sin(phase) + brightness * (
            0.5 * math.sin(2 * phase) + 0.25 * math.sin(3 * phase))
        out[offset + i] += gain * envelope * math.exp(-t / decay) * voice


def throw():
    out = blank(0.18)
    raw = noise(len(out), 101)
    # Moving low-pass minus a low shelf makes a descending, broad noise band.
    swept = lowpass(raw, lambda t: 6500 * (650 / 6500) ** (t / 0.18))
    bass = lowpass(raw, lambda t: 250)
    for i in range(len(out)):
        u = i / (len(out) - 1)
        out[i] = (swept[i] - bass[i]) * math.sin(math.pi * u) ** 1.2
    return out


def land():
    out = blank(0.15)
    for i in range(len(out)):
        t = i / RATE
        # Integrate a pitch fall from 190 Hz towards 85 Hz.
        phase = 2 * math.pi * (85 * t + 105 * 0.018 * (1 - math.exp(-t / 0.018)))
        out[i] = math.sin(phase) * math.exp(-t / 0.025)
    tone(out, 0.079, 0.06, 155, 0.24, 0.014, 0.1)
    return out


def shake():
    out = blank(0.10)
    soft_noise = lowpass(noise(len(out), 202), lambda t: 1800)
    for i in range(len(out)):
        out[i] = 0.22 * soft_noise[i] * math.exp(-(i / RATE) / 0.009)
    tone(out, 0, 0.065, 780, 0.75, 0.010, 0.12)
    tone(out, 0.028, 0.06, 590, 0.32, 0.009)
    return out


def success():
    out = blank(0.9)
    # C5 E5 G5 C6: clearly rising major arpeggio with brighter harmonics.
    for start, frequency in zip((0, 0.12, 0.24, 0.36), (523.251, 659.255, 783.991, 1046.502)):
        tone(out, start, 0.42, frequency, 0.7, 0.105, 0.65)
    dry = out[:]
    # Sparse, diminishing early reflections; no feedback or random delays.
    for delay, gain in ((0.061, 0.19), (0.113, 0.12), (0.173, 0.075)):
        shift = round(delay * RATE)
        for i in range(shift, len(out)):
            out[i] += gain * dry[i - shift]
    return out


def fail():
    out = blank(0.5)
    # G3 down to C3, rounded timbre and a soft exhale, without a buzzer.
    tone(out, 0, 0.27, 195.998, 0.8, 0.095, 0.06)
    tone(out, 0.19, 0.31, 130.813, 0.7, 0.085, 0.04)
    breath = lowpass(noise(len(out), 303), lambda t: 950)
    for i in range(len(out)):
        t = i / RATE
        if t >= 0.12:
            u = (t - 0.12) / 0.38
            out[i] += 0.24 * breath[i] * math.sin(math.pi * u) ** 2
    return out


def encode(samples):
    for i in range(FADE):
        gain = i / (FADE - 1)
        samples[i] *= gain
        samples[-1 - i] *= gain
    scale = TARGET / max(abs(value) for value in samples)
    pcm = [round(value * scale) for value in samples]
    assert max(abs(value) for value in pcm) < 32767
    return struct.pack('<' + 'h' * len(pcm), *pcm)


def main():
    destination = ROOT / 'assets/sfx/capture'
    destination.mkdir(parents=True, exist_ok=True)
    report = ['Capture SFX: 44100 Hz, mono, signed 16-bit PCM',
              'Metrics measured from decoded WAV; dBFS reference = 32768.',
              'File          Duration (s)  Samples  Peak (dBFS)  RMS (dBFS)']
    for synth in (throw, land, shake, success, fail):
        path = destination / (synth.__name__ + '.wav')
        payload = encode(synth())
        with wave.open(str(path), 'wb') as wav:
            wav.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
            wav.writeframes(payload)
        with wave.open(str(path), 'rb') as wav:
            assert (wav.getnchannels(), wav.getsampwidth(), wav.getframerate(), wav.getcomptype()) == (1, 2, RATE, 'NONE')
            count = wav.getnframes()
            decoded = wav.readframes(count)
        assert decoded == payload
        pcm = struct.unpack('<' + 'h' * count, decoded)
        peak = max(abs(value) for value in pcm)
        rms = math.sqrt(sum(value * value for value in pcm) / count)
        assert rms > 0 and 0 < peak < 32767 and pcm[0] == pcm[-1] == 0
        report.append(f'{path.name:<13} {count / RATE:>12.6f} {count:>8} '
                      f'{20 * math.log10(peak / 32768):>12.4f} '
                      f'{20 * math.log10(rms / 32768):>11.4f}')
    text = '\n'.join(report) + '\n'
    (ROOT / 'tools/capture_sfx_report.txt').write_bytes(text.encode('ascii'))
    print(text, end='')


if __name__ == '__main__':
    main()
