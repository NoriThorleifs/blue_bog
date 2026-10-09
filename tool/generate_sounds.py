"""Generates assets/sounds/<name>_ai_generated.wav, placeholder sound
effects for combat, synthesised from scratch: oscillators, filtered noise
and envelopes, no samples.

They are proof-of-concept placeholders like the card art; a sound designer
can replace any file by dropping in one with the same name.

    python3 tool/generate_sounds.py

Needs numpy and scipy.
"""

import os
import wave

import numpy as np
from scipy.signal import butter, sosfilt

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sounds')
rng = np.random.default_rng(27)


def t(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def env(n, attack=0.005, decay=None, curve=4.0):
    """Quick attack, then an exponential fall to silence by the end."""
    x = np.arange(n) / RATE
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    d = np.exp(-curve * x / (decay or (n / RATE)))
    return a * d


def sweep(f0, f1, seconds, shape='sine', curve=1.0):
    """An oscillator gliding from f0 to f1."""
    x = t(seconds)
    f = f0 + (f1 - f0) * (x / seconds) ** curve
    phase = 2 * np.pi * np.cumsum(f) / RATE
    if shape == 'square':
        return np.sign(np.sin(phase))
    if shape == 'saw':
        return 2 * ((phase / (2 * np.pi)) % 1) - 1
    if shape == 'tri':
        return 2 * np.abs(2 * ((phase / (2 * np.pi)) % 1) - 1) - 1
    return np.sin(phase)


def noise(seconds):
    return rng.uniform(-1, 1, int(RATE * seconds))


def lowpass(x, cutoff, order=2):
    return sosfilt(butter(order, cutoff, 'low', fs=RATE, output='sos'), x)


def highpass(x, cutoff, order=2):
    return sosfilt(butter(order, cutoff, 'high', fs=RATE, output='sos'), x)


def bandpass(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, hi], 'band', fs=RATE, output='sos'), x)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def at(seconds, x):
    """[x], starting [seconds] in."""
    return np.concatenate([np.zeros(int(RATE * seconds)), x])


def save(name, x, gain=0.8):
    x = x / max(np.max(np.abs(x)), 1e-9) * gain
    # Fade the last few milliseconds so nothing clicks.
    fade = min(len(x), int(RATE * 0.01))
    x[-fade:] *= np.linspace(1, 0, fade)
    data = (x * 32767).astype(np.int16)
    path = os.path.join(OUT, f'{name}_ai_generated.wav')
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


# Weapons ----------------------------------------------------------------------

def laser():
    """A bright zap falling in pitch."""
    s = 0.16
    tone = sweep(1800, 300, s, 'square', 0.6) * 0.5 + sweep(2400, 500, s, 'saw') * 0.3
    save('laser', lowpass(tone, 6000) * env(len(tone), 0.002, s, 5), 0.6)


def lance():
    """A short charge-up whine, then a smooth, deep beam with a slow wobble:
    heavier than a laser, without the grit."""
    charge = 0.07
    beam = 0.34
    whine = sweep(500, 1400, charge, 'sine', 0.5) * np.linspace(0.2, 0.6, int(RATE * charge))
    x = t(beam)
    wobble = 1 + 0.03 * np.sin(2 * np.pi * 9 * x)
    phase = 2 * np.pi * np.cumsum(140 * wobble) / RATE
    body = (
        np.sin(phase) * 0.6
        + np.sin(2 * phase) * 0.3
        + np.sin(3 * phase) * 0.12
    )
    shimmer = np.sin(2 * np.pi * np.cumsum(np.full(len(x), 1120.0)) / RATE) * 0.08
    e = env(len(x), 0.01, beam, 2.5)
    save('lance', mix(whine, at(charge, (body + shimmer) * e)), 0.65)


def missile_launch():
    """A whoosh of rising, filtered noise."""
    s = 0.45
    n = noise(s)
    swept = np.concatenate([
        bandpass(chunk, 300 + 2500 * k / 20, 900 + 4000 * k / 20)
        for k, chunk in enumerate(np.array_split(n, 20))
    ])
    e = np.sin(np.pi * np.linspace(0, 1, len(swept))) ** 1.5
    save('missile_launch', swept * e, 0.5)


def explosion_small():
    """A short, punchy blast."""
    s = 0.45
    body = lowpass(noise(s), 1200, 4) * env(int(RATE * s), 0.002, s, 6)
    thump = sweep(140, 40, s) * env(int(RATE * s), 0.002, s * 0.6, 6)
    save('explosion_small', mix(body, thump * 0.8), 0.75)


def teleport():
    """A shimmering rise that snaps into a pop."""
    rise = 0.32
    shimmer = mix(
        sweep(300, 2400, rise, 'sine', 2) * 0.5,
        sweep(450, 3600, rise, 'sine', 2) * 0.3,
    ) * np.linspace(0.1, 1, int(RATE * rise)) * (1 + 0.5 * np.sin(2 * np.pi * 30 * t(rise)))
    pop = lowpass(noise(0.25), 3000, 2) * env(int(RATE * 0.25), 0.001, 0.25, 8)
    boom = sweep(180, 50, 0.3) * env(int(RATE * 0.3), 0.001, 0.3, 6)
    save('teleport', mix(shimmer, at(rise, pop), at(rise, boom * 0.8)), 0.7)


def hellfire():
    """A roar with crackle in it."""
    s = 0.5
    roar = lowpass(noise(s), 700, 4) * 1.5
    crackle = noise(s) * (rng.uniform(0, 1, int(RATE * s)) > 0.985) * 3
    growl = sweep(90, 60, s, 'saw') * 0.6
    e = env(int(RATE * s), 0.03, s, 3)
    save('hellfire', mix(roar, crackle, growl) * e, 0.75)


def ion():
    """An electric buzz: a steady, overdriven hum like a high-voltage arc,
    two slightly detuned tones beating against each other, and a few faint
    sparks on top."""
    s = 0.38
    x = t(s)
    jitter = 1 + 0.006 * lowpass(rng.uniform(-1, 1, len(x)), 40, 1) * 40
    hum = mix(
        sweep(110, 110, s, 'saw') * jitter,
        sweep(111.5, 111.5, s, 'square') * 0.7,
    )
    # Overdrive for the harsh harmonics, then keep the buzzy middle.
    buzz = bandpass(np.tanh(hum * 3), 250, 3500)
    sparks = highpass(noise(s), 3500) * (rng.uniform(0, 1, len(x)) > 0.97) * 0.4
    e = np.minimum(1, x / 0.01) * np.minimum(1, (s - x) / 0.08)
    save('ion', (buzz + sparks) * e, 0.5)


def flak():
    """Three quick pops."""
    pop = lambda: (
        bandpass(noise(0.08), 400, 2500) * env(int(RATE * 0.08), 0.001, 0.08, 7)
    )
    save('flak', mix(pop(), at(0.07, pop() * 0.8), at(0.15, pop() * 0.9)), 0.6)


def rail():
    """A heavy, impactful thunk: a sharp click, a short chunk of noise and a
    deep body that drops away fast, saturated so it hits hard, with a faint
    metallic ring from the rails."""
    s = 0.5
    x = t(s)
    body = sweep(110, 38, s, 'sine', 0.35) * env(len(x), 0.001, 0.28, 4)
    click = highpass(noise(0.004), 3000) * 0.9
    chunk = bandpass(noise(0.025), 180, 900, 2) * env(int(RATE * 0.025), 0.0005, 0.025, 5)
    ring = sum(
        np.sin(2 * np.pi * f * x) * a for f, a in ((523, 0.05), (1187, 0.03), (1913, 0.02))
    ) * env(len(x), 0.002, 0.3, 5)
    thunk = np.tanh(mix(body * 1.6, click, chunk * 1.2, ring) * 2.2)
    save('rail', thunk, 0.9)


def rail_glance():
    """The slug skipping off a shield: a bright metallic ping, falling away."""
    s = 0.4
    x = t(s)
    ping = sum(
        sweep(f, f * 0.6, s, 'sine', 0.7) * a
        for f, a in ((2600, 0.5), (3900, 0.3), (5300, 0.15))
    )
    scrape = bandpass(noise(0.05), 2000, 6000) * env(int(RATE * 0.05), 0.001, 0.05, 6)
    save('rail_glance', mix(ping * env(len(x), 0.001, s, 5), scrape * 0.6), 0.45)


# Hell's own cards ----------------------------------------------------------------

def teeth():
    """A chattering bite: a quick run of hard clacks and a wet crunch."""
    clack = lambda: (
        bandpass(noise(0.018), 1800, 6000, 4) * env(int(RATE * 0.018), 0.0005, 0.018, 6)
    )
    gaps = [0, 0.028, 0.05, 0.085]
    clacks = mix(*[at(g, clack() * (1 - k * 0.15)) for k, g in enumerate(gaps)])
    crunch = (
        lowpass(noise(0.09), 1400, 2)
        * (rng.uniform(0, 1, int(RATE * 0.09)) > 0.6)
        * env(int(RATE * 0.09), 0.002, 0.09, 4)
    )
    save('teeth', mix(clacks, at(0.1, crunch * 0.8)), 0.9)


def brandy_mist():
    """Hell's shield rising: a wet sizzle, and something gurgling under it."""
    s = 0.45
    x = t(s)
    hiss = bandpass(noise(s), 2500, 7000) * (0.6 + 0.4 * np.sin(2 * np.pi * 13 * x))
    bubbles = mix(*[
        at(rng.uniform(0, s - 0.06), sweep(f, f * 1.8, 0.05, 'sine') * env(int(RATE * 0.05), 0.002, 0.05, 4))
        for f in rng.uniform(120, 320, 9)
    ])
    bubbles = np.pad(bubbles, (0, max(0, len(x) - len(bubbles))))[:len(x)]
    e = np.sin(np.pi * np.linspace(0, 1, len(x))) ** 1.2
    save('brandy_mist', (hiss * 0.5 + bubbles * 0.9) * e, 0.4)


def hell_clock():
    """A clock ticking backwards: each tick swells in instead of snapping."""
    tick = lambda f: (
        bandpass(noise(0.05), f, f * 2.5, 2) * env(int(RATE * 0.05), 0.0005, 0.05, 7)
    )[::-1]
    ticks = mix(*[at(k * 0.22, tick(2200 if k % 2 == 0 else 1600)) for k in range(4)])
    drone = sweep(70, 55, len(ticks) / RATE, 'sine') * 0.25
    save('hell_clock', mix(ticks, drone), 0.5)


# Defences and ship systems ------------------------------------------------------

def shield_block():
    """A glassy ping as a shot splashes on the shield."""
    s = 0.3
    x = t(s)
    ping = sum(
        np.sin(2 * np.pi * f * x) * a for f, a in ((1320, 0.6), (1980, 0.3), (2970, 0.2))
    )
    save('shield_block', ping * env(len(x), 0.002, s, 6), 0.45)


def shield_charge():
    """A soft hum rising into place."""
    s = 0.35
    hum = sweep(165, 330, s, 'tri') * 0.6 + sweep(247, 495, s, 'sine') * 0.4
    e = np.sin(np.pi * np.linspace(0, 1, len(hum))) ** 2
    save('shield_charge', hum * e, 0.3)


def drone_built():
    """A little two-note chirp."""
    a = sweep(1200, 1600, 0.05, 'tri')
    b = sweep(1800, 2200, 0.06, 'tri')
    x = np.concatenate([a, b])
    save('drone_built', x * env(len(x), 0.002, 0.11, 2), 0.35)


def repair():
    """Ascending blips, and a hiss of welding."""
    blips = np.concatenate([
        sweep(f, f, 0.06, 'tri') * env(int(RATE * 0.06), 0.002, 0.06, 3)
        for f in (660, 880, 1100)
    ])
    weld = highpass(noise(0.18), 4000) * 0.15
    save('repair', mix(blips, weld), 0.4)


def jammed():
    """A teleport that fizzles out: falling shimmer into static."""
    s = 0.4
    fall = sweep(2000, 200, s, 'sine', 0.5) * np.linspace(1, 0.2, int(RATE * s))
    static = highpass(noise(s), 3000) * np.linspace(0, 0.5, int(RATE * s))
    save('jammed', (fall + static) * env(int(RATE * s), 0.002, s, 2), 0.5)


def out_of_ammo():
    """A dry click."""
    click = bandpass(noise(0.03), 1500, 5000) * env(int(RATE * 0.03), 0.0005, 0.03, 8)
    save('out_of_ammo', mix(click, at(0.06, click * 0.6)), 0.4)


# Endings ------------------------------------------------------------------------

def ship_explode():
    """A big, rolling blast with debris."""
    s = 1.6
    body = lowpass(noise(s), 800, 4) * env(int(RATE * s), 0.005, s, 4)
    thump = sweep(90, 30, s) * env(int(RATE * s), 0.002, s * 0.5, 4)
    debris = mix(*[
        at(rng.uniform(0.1, 1.0), bandpass(noise(0.06), 800, 3000)
           * env(int(RATE * 0.06), 0.001, 0.06, 6) * rng.uniform(0.2, 0.5))
        for _ in range(12)
    ])
    save('ship_explode', mix(body, thump * 1.2, debris), 0.85)


def boarded():
    """Something heavy lands aboard, and a low, wrong chord swells."""
    s = 2.0
    x = t(s)
    hit = lowpass(noise(0.3), 400, 4) * env(int(RATE * 0.3), 0.001, 0.3, 5)
    chord = sum(np.sin(2 * np.pi * f * x) for f in (55, 58.3, 82.4, 87.3)) / 4
    swell = np.sin(np.pi * np.clip(x / s, 0, 1)) ** 1.5
    save('boarded', mix(hit * 1.5, chord * swell), 0.85)


def victory():
    """A short rising fanfare in fifths."""
    notes = [(392, 0.12), (523, 0.12), (784, 0.35)]
    x = np.concatenate([
        (sweep(f, f, d, 'tri') * 0.7 + sweep(f * 1.5, f * 1.5, d, 'sine') * 0.3)
        * env(int(RATE * d), 0.005, d, 2)
        for f, d in notes
    ])
    save('victory', x, 0.45)


def defeat():
    """A falling, detuned phrase."""
    notes = [(330, 0.2), (311, 0.2), (262, 0.6)]
    x = np.concatenate([
        (sweep(f, f * 0.98, d, 'saw') * 0.4 + sweep(f * 1.005, f, d, 'tri') * 0.6)
        * env(int(RATE * d), 0.01, d, 2)
        for f, d in notes
    ])
    save('defeat', lowpass(x, 2500), 0.45)


ALL = [laser, lance, missile_launch, explosion_small, teleport, hellfire, ion,
       flak, rail, rail_glance, teeth, brandy_mist, hell_clock, shield_block, shield_charge, drone_built, repair, jammed,
       out_of_ammo, ship_explode, boarded, victory, defeat]

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for make in ALL:
        make()
    print(f'{len(ALL)} sounds in {os.path.abspath(OUT)}')
