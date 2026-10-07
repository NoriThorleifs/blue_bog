"""Four procedural concept mockups of the Mourner event.

Proof-of-concept placeholders, not final art. Writes
concept_art/mourner_<n>_ai_generated.png (see the naming rule in CLAUDE.md).

    python3 tool/generate_mourner_concepts.py

The scene, from The-Mourner.md: in Hell, whose space is an amber,
alcoholic murk, a planet hangs at the lip of a black hole. Something vast
and unknowable holds it there, forever pulling it back from the brink and
never quite far enough.

Needs numpy, scipy and Pillow.
"""

import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

W, H = 1536, 1024
OUT = os.path.join(os.path.dirname(__file__), '..', 'concept_art')
YY, XX = np.mgrid[0:H, 0:W].astype(np.float32)

AMBER = np.array([1.0, 0.62, 0.25])
BRANDY = np.array([0.55, 0.16, 0.10])
CRIMSON = np.array([0.85, 0.12, 0.30])
HOT = np.array([1.0, 0.93, 0.78])
GOLD = np.array([1.0, 0.78, 0.35])
SEA = np.array([0.25, 0.55, 0.55])
VOID = np.array([0.02, 0.01, 0.015])


def smooth(edge0, edge1, x):
    t = np.clip((x - edge0) / (edge1 - edge0), 0, 1)
    return t * t * (3 - 2 * t)


def noise(rng, sigma, shape=(H, W)):
    n = ndimage.gaussian_filter(rng.standard_normal(shape).astype(np.float32), sigma)
    return (n - n.min()) / (n.max() - n.min() + 1e-6)


def fbm(rng, sigmas=(160, 60, 20, 6), weights=(0.5, 0.28, 0.15, 0.07)):
    return sum(w * noise(rng, s) for s, w in zip(sigmas, weights))


def murk(rng, dark, light, strength=1.0):
    """Hell's sea: an amber fog, darker toward the edges."""
    f = fbm(rng) ** 1.6
    vignette = 1 - 0.85 * smooth(0.3, 1.0, np.hypot((XX - W / 2) / (W * 0.6),
                                                    (YY - H / 2) / (H * 0.6)))
    t = (f * vignette * strength)[..., None]
    return dark * (1 - t) + light * t


def motes(img, rng, n, colour, size=1.2):
    """Specks drifting in the sea: Hell's version of a starfield."""
    layer = np.zeros((H, W), np.float32)
    xs, ys = rng.integers(0, W, n), rng.integers(0, H, n)
    layer[ys, xs] = rng.uniform(0.3, 1.0, n)
    layer = ndimage.gaussian_filter(layer, size) * size * 6
    return img + layer[..., None] * colour


def glow(mask, sigma, gain=1.0):
    return ndimage.gaussian_filter(mask.astype(np.float32), sigma) * gain


def add(img, intensity, colour):
    return img + intensity[..., None] * colour


def over(img, alpha, colour):
    a = np.clip(alpha, 0, 1)[..., None]
    return img * (1 - a) + colour * a


def black_hole(img, rng, cx, cy, r, tilt=0.22, disk_out=3.2, angle=0.0,
               hot=HOT, warm=AMBER):
    """A black hole with its accretion disk, lensed over the top and under
    the bottom of the shadow, drawn in the right order."""
    ca, sa = math.cos(angle), math.sin(angle)
    dx, dy = XX - cx, YY - cy
    u = dx * ca + dy * sa
    v = -dx * sa + dy * ca
    vd = v / tilt
    rd = np.hypot(u, vd)
    theta = np.arctan2(vd, u)
    streaks = noise(rng, (1, 40)) * 0.6 + 0.4
    band = smooth(r * 1.5, r * 1.9, rd) * (1 - smooth(r * 2.2, r * disk_out, rd))
    doppler = 1 + 0.7 * np.cos(theta + 0.4)
    disk = band * doppler * (0.6 + 0.8 * streaks) * (r * 1.6 / np.maximum(rd, r)) ** 0.8
    colour_t = smooth(r * 1.5, r * disk_out, rd)[..., None]
    disk_col = hot * (1 - colour_t) + warm * colour_t
    back = (v < 0)
    front = ~back
    dist = np.hypot(dx, dy)
    # The far side of the disk, bent up over the shadow and under it.
    lens_top = np.exp(-((dist - r * 1.35) / (r * 0.12)) ** 2) * smooth(0.0, 0.6, -v / r)
    lens_bottom = np.exp(-((dist - r * 1.15) / (r * 0.06)) ** 2) * smooth(0.0, 0.4, v / r) * 0.5
    img = img + (disk * back)[..., None] * disk_col * 1.1
    img = add(img, (lens_top * 1.4 + lens_bottom) * (0.7 + 0.3 * np.cos(np.arctan2(dy, dx) + 0.4)), hot)
    img = add(img, glow(disk > 0.2, r * 0.6, 0.5), warm)
    shadow = smooth(r * 1.02, r * 0.97, dist)
    img = over(img, shadow, VOID)
    img = add(img, np.exp(-((dist - r * 1.03) / (r * 0.025)) ** 2) * 1.2, hot)
    img = img + (disk * front)[..., None] * disk_col * 1.3
    return img


def planet(img, rng, cx, cy, r, ocean=SEA, land=np.array([0.42, 0.35, 0.22]),
           light=(-0.6, -0.4), rim=AMBER):
    dx, dy = (XX - cx) / r, (YY - cy) / r
    d2 = dx * dx + dy * dy
    inside = d2 < 1
    z = np.sqrt(np.clip(1 - d2, 0, 1))
    lx, ly = light
    lz = math.sqrt(max(0.0, 1 - lx * lx - ly * ly))
    lam = np.clip(dx * lx + dy * ly + z * lz, 0, 1)
    cont = noise(rng, max(2, r / 6)) > 0.55
    surf = np.where(cont[..., None], land, ocean)
    clouds = smooth(0.6, 0.8, noise(rng, max(2, r / 10)))
    surf = surf * (1 - clouds[..., None] * 0.6) + clouds[..., None] * 0.6
    shaded = surf * (0.05 + 0.95 * lam[..., None])
    edge = smooth(1.0, 0.97, np.sqrt(d2))
    img = over(img, edge * inside, shaded)
    atmo = np.exp(-((np.sqrt(d2) - 1.0) / 0.05) ** 2) * (0.3 + 0.7 * np.clip(dx * lx + dy * ly + 0.3, 0, 1))
    return add(img, atmo * 0.9, rim)


def strokes(curves, width, blur, size=(W, H)):
    """Draws curves as soft light and returns the intensity."""
    layer = Image.new('L', size, 0)
    d = ImageDraw.Draw(layer)
    for pts, w, a in curves:
        d.line(pts, fill=int(255 * a), width=max(1, int(w * width)), joint='curve')
    arr = np.asarray(layer, np.float32) / 255
    return ndimage.gaussian_filter(arr, blur) if blur else arr


def bezier(p0, p1, p2, p3, n=60):
    out = []
    for i in range(n + 1):
        t = i / n
        a, b, c, e = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t * t, t ** 3
        out.append((a * p0[0] + b * p1[0] + c * p2[0] + e * p3[0],
                    a * p0[1] + b * p1[1] + c * p2[1] + e * p3[1]))
    return out


def finish(img, name, grain_rng, grain=0.025):
    img = img + grain_rng.standard_normal(img.shape[:2])[..., None] * grain
    img = 1 - np.exp(-np.clip(img, 0, None) * 1.25)  # soft tonemap
    out = Image.fromarray((np.clip(img, 0, 1) ** (1 / 1.05) * 255).astype(np.uint8))
    out.save(os.path.join(OUT, f'{name}_ai_generated.png'), optimize=True)
    return out


# 1. The cradle ----------------------------------------------------------------
# Wide shot. Countless threads of light reach in from outside the frame and
# cradle the planet at the very edge of the disk.
def cradle():
    rng = np.random.default_rng(11)
    img = murk(rng, VOID + 0.01, BRANDY * 0.6)
    img = motes(img, rng, 900, AMBER * 0.6)
    img = black_hole(img, rng, 640, 560, 150, tilt=0.2, angle=-0.12)
    px, py, pr = 1010, 470, 46
    curves = []
    for k in range(70):
        sx = rng.uniform(1100, 1700)
        sy = rng.uniform(-200, 120)
        a = rng.uniform(0, 2 * math.pi)
        ex, ey = px + math.cos(a) * pr * 1.25, py + math.sin(a) * pr * 1.25
        c1 = (sx - rng.uniform(100, 400), sy + rng.uniform(250, 500))
        c2 = (ex + rng.uniform(-200, 200), ey + rng.uniform(-300, 100))
        curves.append((bezier((sx, sy), c1, c2, (ex, ey)), rng.uniform(0.5, 2.5),
                       rng.uniform(0.2, 0.7)))
    threads = strokes(curves, 1.6, 1.2)
    img = add(img, glow(threads, 10, 2.0), GOLD * 0.5)
    img = add(img, threads * 0.9, HOT * 0.8)
    img = planet(img, rng, px, py, pr, light=(-0.9, 0.1))
    img = add(img, glow(np.hypot(XX - px, YY - py) < pr * 1.4, 30, 0.6), GOLD)
    finish(img, 'mourner_1', rng)


# 2. Hands -------------------------------------------------------------------------
# Close up. Two dark hands, far too large, rise toward the planet, the
# author's pick of the four. They are only visible where the disk light
# catches their edges.
def hand(d, cx, cy, s, flip):
    sgn = -1 if flip else 1
    d.ellipse([cx - 120 * s, cy - 70 * s, cx + 120 * s, cy + 90 * s], fill=255)
    for i, (dx, length, bend) in enumerate([(-95, 230, 0.35), (-40, 300, 0.25),
                                            (20, 310, 0.18), (80, 270, 0.12)]):
        x0, y0 = cx + dx * s * sgn, cy - 40 * s
        x1 = x0 + sgn * length * bend * s * 0.9
        y1 = y0 - length * s
        pts = bezier((x0, y0), (x0, y0 - length * 0.5 * s),
                     (x1 - sgn * 40 * s, y1 + 60 * s), (x1, y1), 30)
        d.line(pts, fill=255, width=int((46 - i * 3) * s), joint='curve')
        d.ellipse([x1 - 22 * s, y1 - 22 * s, x1 + 22 * s, y1 + 22 * s], fill=255)
    thumb = bezier((cx + sgn * 110 * s, cy + 10 * s), (cx + sgn * 230 * s, cy - 10 * s),
                   (cx + sgn * 250 * s, cy - 120 * s), (cx + sgn * 190 * s, cy - 190 * s), 30)
    d.line(thumb, fill=255, width=int(50 * s), joint='curve')


def hands():
    rng = np.random.default_rng(23)
    img = murk(rng, VOID + 0.015, BRANDY * 0.5)
    img = motes(img, rng, 600, AMBER * 0.5, 1.6)
    img = black_hole(img, rng, 768, 120, 260, tilt=0.16, disk_out=3.6, angle=0.05)
    mask_img = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(mask_img)
    hand(d, 560, 1020, 1.55, flip=False)
    hand(d, 980, 1020, 1.55, flip=True)
    mask = ndimage.gaussian_filter(np.asarray(mask_img, np.float32) / 255, 2)
    rim = np.clip(mask - ndimage.gaussian_filter(mask, 9) * 1.0, 0, 1)
    rim *= smooth(H, 0, YY) ** 0.6
    img = over(img, mask * 0.97, VOID * 0.5)
    img = add(img, rim * 3.0, GOLD)
    img = add(img, glow(rim, 18, 3.0), AMBER * 0.6)
    img = planet(img, rng, 768, 560, 120, light=(0.0, -0.95), rim=GOLD)
    finish(img, 'mourner_2', rng)


# 3. From the bridge ------------------------------------------------------------------
# The captain's view through a triangular canopy. The Mourner is a colossal
# veil of falling light with a hollow where a face would be, the planet held
# at its heart, the black hole a line of fire across the sky.
def bridge():
    rng = np.random.default_rng(37)
    img = murk(rng, VOID + 0.01, BRANDY * 0.7)
    img = motes(img, rng, 1200, AMBER * 0.7, 1.0)
    img = black_hole(img, rng, 768, 640, 90, tilt=0.08, disk_out=7.5, angle=0.0)
    cx = 768
    curves = []
    for k in range(160):
        x = cx + rng.normal(0, 260)
        top = rng.uniform(-100, 120)
        bottom = rng.uniform(520, 900)
        sway = (x - cx) * 0.25
        hollow = 1 if abs(x - cx) > 70 else 0.15
        curves.append((bezier((x, top), (x - sway, top + 200), (x + sway * 0.5, bottom - 200),
                              (x + rng.normal(0, 30), bottom), 40),
                       rng.uniform(0.6, 2.0), rng.uniform(0.15, 0.55) * hollow))
    veil = strokes(curves, 1.4, 1.5)
    veil *= smooth(-50, 250, YY) * (1 - smooth(500, 900, YY))
    img = add(img, glow(veil, 14, 1.5), AMBER * 0.6)
    img = add(img, veil * 0.8, HOT * 0.7)
    img = planet(img, rng, cx, 430, 34, light=(0.3, 0.8), rim=GOLD)
    # Canopy: three dark struts in a triangle, with a faint reflection.
    canopy = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(canopy)
    top, left, right = (768, -260), (-180, 1180), (1716, 1180)
    for a, b in ((top, left), (top, right), (left, right)):
        d.line([a, b], fill=255, width=90)
    frame = ndimage.gaussian_filter(np.asarray(canopy, np.float32) / 255, 3)
    img = over(img, frame, np.array([0.03, 0.03, 0.04]))
    edge = np.clip(frame - ndimage.gaussian_filter(frame, 6), 0, 1)
    img = add(img, edge * 1.6, np.array([0.45, 0.85, 1.0]) * 0.5)
    img = add(img, smooth(0.0, 1.0, (XX - YY) / W) * 0.035, np.array([0.4, 0.8, 1.0]))
    finish(img, 'mourner_3', rng)


# 4. Lore plate -----------------------------------------------------------------------
# A flat, printed-looking plate, like a tarot card: a hooded figure that is
# mostly absence holds the world up to the black hole.
def plate():
    rng = np.random.default_rng(53)
    ink = np.array([0.07, 0.03, 0.04])
    paper = np.array([0.80, 0.52, 0.28])
    img = np.zeros((H, W, 3), np.float32) + ink
    tex = noise(rng, 3) * 0.08 + noise(rng, 40) * 0.12
    card = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(card)
    x0, x1 = 448, 1088
    d.rounded_rectangle([x0, 40, x1, 984], radius=24, fill=255)
    card_mask = np.asarray(card, np.float32) / 255
    img = over(img, card_mask, paper * 0.25)
    img = add(img, card_mask * tex, paper * 0.4)
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    gold = (232, 178, 90)
    crimson = (200, 40, 70)
    d.rounded_rectangle([x0 + 18, 58, x1 - 18, 966], radius=16, outline=gold, width=4)
    d.rounded_rectangle([x0 + 30, 70, x1 - 30, 954], radius=12, outline=gold, width=1)
    cx, cy = 768, 360
    for r, w in ((210, 3), (180, 8), (150, 2), (128, 14)):
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=gold, width=w)
    d.ellipse([cx - 110, cy - 110, cx + 110, cy + 110], fill=(4, 2, 3))
    for k in range(24):
        a = k * math.pi / 12
        d.line([(cx + 225 * math.cos(a), cy + 225 * math.sin(a)),
                (cx + 250 * math.cos(a), cy + 250 * math.sin(a))], fill=gold, width=3)
    hood = [(768, 470), (690, 560), (650, 700), (600, 900), (936, 900), (886, 700),
            (846, 560)]
    d.polygon(hood, fill=(14, 6, 8), outline=gold)
    d.ellipse([728, 520, 808, 610], fill=(2, 1, 2))
    for side in (-1, 1):
        arm = bezier((768 + side * 70, 640), (768 + side * 160, 600),
                     (768 + side * 120, 470), (768 + side * 40, 420), 30)
        d.line(arm, fill=gold, width=5, joint='curve')
    d.ellipse([738, 388, 798, 448], fill=crimson, outline=gold, width=3)
    try:
        font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf', 44)
    except OSError:
        font = ImageFont.load_default()
    d.text((768, 925), 'THE MOURNER', fill=gold, font=font, anchor='mb')
    art = np.asarray(layer, np.float32) / 255
    alpha = art[..., 3]
    img = over(img, alpha, art[..., :3])
    lines = (alpha > 0) & (art[..., :3].max(axis=2) > 0.3)
    img = add(img, glow(lines, 6, 0.4) * card_mask, GOLD * 0.3)
    img = add(img, glow(card_mask > 0, 60, 0.25) * (1 - card_mask), AMBER * 0.6)
    finish(img, 'mourner_4', rng, grain=0.03)


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for draw in (cradle, hands, bridge, plate):
        draw()
    print('4 mockups in', os.path.normpath(OUT))
