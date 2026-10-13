"""Eleven procedural app icon mockups, each a different part of the story, and
the app icon made from one of them.

Proof-of-concept placeholders, not final art. Writes
concept_art/icon_<n>_ai_generated.png, a contact sheet of them all as a
phone's launcher would mask them (concept_art/icon_mockups_ai_generated.png),
and the chosen one as the app icon in assets/icon/:

- app_icon_ai_generated.png: the full icon, for iOS, the web and desktops.
- app_icon_background_ai_generated.png and
  app_icon_foreground_ai_generated.png: the two layers of Android's adaptive
  icon. flutter_launcher_icons insets the foreground by 16% a side, and the
  emblem is shrunk a little more, so it stays inside the circle every
  launcher's mask keeps (33 of the canvas's 108 dp from the middle).

    python3 tool/generate_icon_concepts.py          # icon from mockup 1
    python3 tool/generate_icon_concepts.py --icon 4 # icon from mockup 4
    dart run flutter_launcher_icons                 # then write every size

The mockups, from lore/ and the author's own picture of each species:

1. The triforce: the ship's nine slots, three small triangles in one big one.
   The app icon.
2. A gateway: the ancient ring, its barrier split into thirds for traffic.
3. Hell: a black hole in the amber murk, and the planet the Mourner holds.
4. The Tern: a nanobot hive that counts everything in threes.
5. The Gor: gangly and muscular, four legs under a lower body at 45°, an
   upright upper body with two arms a side.
6. The Ál: black, from the dark deep of Úlamora's sea; like the Sentinels
   of The Matrix, but alive, with thick tentacles.
7. The Bhrun: a massive beetle of grey rock plates on four massive legs, with
   a face of moving plates.
8. The Unfortunates: immortal machines of smooth white metal and platinum,
   elvish-inspired but not elves, and cracked since the gatecrash.
9. The Hellborn: humans changed by millennia in Hell, behind a horned helm.
10. A demon: Lovecraftian, all eyes, tentacles and teeth.
11. The Havi: ethereal and godlike, an amoeba-like cloud of golden smoke
    and gel.

Needs numpy, scipy and Pillow.
"""

import argparse
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

S = 1024
ROOT = os.path.join(os.path.dirname(__file__), '..')
CONCEPTS = os.path.join(ROOT, 'concept_art')
ICON_DIR = os.path.join(ROOT, 'assets', 'icon')
YY, XX = np.mgrid[0:S, 0:S].astype(np.float32)
C = S / 2

CYAN = np.array([0.3, 0.88, 1.0])
ICE = np.array([0.6, 0.88, 1.0])
WHITE = np.array([1.0, 1.0, 1.0])
HOT = np.array([1.0, 0.93, 0.78])
AMBER = np.array([1.0, 0.62, 0.25])
GOLD = np.array([1.0, 0.8, 0.38])
BRANDY = np.array([0.5, 0.15, 0.08])
CRIMSON = np.array([0.9, 0.14, 0.12])
STEEL = np.array([0.45, 0.5, 0.58])
VOID = np.array([0.01, 0.01, 0.015])


def hexcol(h):
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])


def smooth(edge0, edge1, x):
    t = np.clip((x - edge0) / (edge1 - edge0), 0, 1)
    return t * t * (3 - 2 * t)


def noise(rng, sigma):
    n = ndimage.gaussian_filter(rng.standard_normal((S, S)).astype(np.float32), sigma)
    return (n - n.min()) / (n.max() - n.min() + 1e-6)


def radial(inner, outer, cx=C, cy=C, r=S * 0.75):
    t = smooth(0, 1, np.hypot(XX - cx, YY - cy) / r)[..., None]
    return inner * (1 - t) + outer * t


def stars(img, rng, n, colour=ICE, size=0.8):
    layer = np.zeros((S, S), np.float32)
    layer[rng.integers(0, S, n), rng.integers(0, S, n)] = rng.uniform(0.2, 1, n) ** 3
    return img + ndimage.gaussian_filter(layer, size)[..., None] * 8 * colour


# Shapes, drawn twice the size and shrunk, for smooth edges --------------------

def _mask(draw):
    layer = Image.new('L', (S * 2, S * 2), 0)
    draw(ImageDraw.Draw(layer), 2)
    return np.asarray(layer.resize((S, S), Image.LANCZOS), np.float32) / 255


def polygon(points):
    return _mask(lambda d, k: d.polygon([(x * k, y * k) for x, y in points], fill=255))


def ellipse(cx, cy, rx, ry):
    return _mask(lambda d, k: d.ellipse([(cx - rx) * k, (cy - ry) * k,
                                         (cx + rx) * k, (cy + ry) * k], fill=255))


def lines(paths, width):
    """Polylines [width] wide; each path a list of points."""
    def draw(d, k):
        for pts in paths:
            d.line([(x * k, y * k) for x, y in pts], fill=255, width=int(width * k),
                   joint='curve')
            for x, y in (pts[0], pts[-1]):
                r = width * k / 2
                d.ellipse([x * k - r, y * k - r, x * k + r, y * k + r], fill=255)
    return _mask(draw)


def tapered(pts, w0, w1):
    """A stroke along [pts] that narrows from w0 to w1, as a mask."""
    def draw(d, k):
        n = len(pts)
        for i, (x, y) in enumerate(pts):
            r = (w0 + (w1 - w0) * i / (n - 1)) * k / 2
            d.ellipse([x * k - r, y * k - r, x * k + r, y * k + r], fill=255)
    return _mask(draw)


def bezier(p0, p1, p2, p3, n=90):
    out = []
    for i in range(n + 1):
        t = i / n
        a, b, c, e = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t * t, t ** 3
        out.append((a * p0[0] + b * p1[0] + c * p2[0] + e * p3[0],
                    a * p0[1] + b * p1[1] + c * p2[1] + e * p3[1]))
    return out


def glow(mask, sigma, gain=1.0):
    return ndimage.gaussian_filter(mask.astype(np.float32), sigma) * gain


# An emblem: light and paint over a background, kept apart so Android's
# adaptive icon can have them as separate layers ------------------------------

class Emblem:
    def __init__(self):
        self.rgb = np.zeros((S, S, 3), np.float32)  # premultiplied
        self.a = np.zeros((S, S), np.float32)

    def paint(self, mask, colour):
        """Opaque paint, [colour] a colour or an image."""
        m = np.clip(mask, 0, 1)
        col = colour if np.ndim(colour) == 3 else np.broadcast_to(colour, (S, S, 3))
        self.rgb = self.rgb * (1 - m[..., None]) + col * m[..., None]
        self.a = self.a + m * (1 - self.a)

    def light(self, intensity, colour):
        """Light added on top, like a glow."""
        self.rgb = self.rgb + intensity[..., None] * colour

    def over(self, bg):
        return bg * (1 - self.a[..., None]) + self.rgb

    def layer(self):
        """The emblem alone, as straight colour and alpha. Glows become
        partly see-through light."""
        alpha = np.clip(self.a + self.rgb.max(axis=2) * (1 - self.a), 0, 1)
        colour = self.rgb / np.maximum(alpha, 1e-4)[..., None]
        return colour, alpha


def shaded_sphere(cx, cy, r, base, light=(-0.55, -0.6), ambient=0.12):
    dx, dy = (XX - cx) / r, (YY - cy) / r
    z = np.sqrt(np.clip(1 - dx * dx - dy * dy, 0, 1))
    lx, ly = light
    lz = math.sqrt(max(0.0, 1 - lx * lx - ly * ly))
    lam = np.clip(dx * lx + dy * ly + z * lz, 0, 1)
    return base * (ambient + (1 - ambient) * lam[..., None])


# 1. The triforce -----------------------------------------------------------------

def triforce(rng):
    bg = radial(np.array([0.05, 0.13, 0.22]), np.array([0.01, 0.02, 0.05]))
    bg = stars(bg, rng, 260)
    e = Emblem()
    side = S * 0.8
    h = side * math.sqrt(3) / 2
    top = np.array([C, C - h * 0.56])
    left = top + [-side / 2, h]
    right = top + [side / 2, h]

    def split(t):
        a, b, c = t
        ab, ac, bc = (a + b) / 2, (a + c) / 2, (b + c) / 2
        return [[a, ab, ac], [ab, b, bc], [ac, bc, c]]

    small = split([top, left, right])
    slots = [s for t in small for s in split(t)]
    # The card colours, a ship's worth: lasers on top, shields and plating
    # bottom left, missiles and drones bottom right.
    colours = ['4DE1FF', '4DE1FF', 'FFE066', '7FA8FF', '7FA8FF', '9FB2C8',
               'FFA24D', 'FFA24D', '5CFF8A']
    edges = []
    for t in small:
        edges.append([tuple(p) for p in t] + [tuple(t[0])])
    outline = lines(edges, S * 0.009)
    e.light(glow(outline, 12, 0.7), CYAN)
    for slot, hexc in zip(slots, colours):
        centre = sum(slot) / 3
        inner = [centre + (p - centre) * 0.8 for p in slot]
        col = hexcol(hexc)
        mask = polygon([tuple(p) for p in inner])
        # Lit from its top corner, like a card catching the light.
        shade = smooth(inner[1][1], inner[0][1], YY)[..., None]
        e.paint(mask, col * (0.3 + 0.55 * shade))
        rim = lines([[tuple(p) for p in inner] + [tuple(inner[0])]], S * 0.007)
        e.light(glow(rim, 6, 0.5), col)
        e.paint(rim, np.minimum(col * 1.15, 1))
    e.paint(outline, CYAN * 0.95)
    return bg, e


# 2. A gateway ----------------------------------------------------------------------

def gateway(rng):
    bg = radial(np.array([0.12, 0.07, 0.24]), np.array([0.01, 0.01, 0.03]))
    neb = noise(rng, 60) * 0.7 + noise(rng, 20) * 0.3
    bg = bg + (smooth(0.5, 0.95, neb) * 0.25)[..., None] * np.array([0.5, 0.25, 0.8])
    bg = stars(bg, rng, 400)
    e = Emblem()
    r = S * 0.36
    d = np.hypot(XX - C, YY - C)
    ang = np.arctan2(YY - C, XX - C)
    # The energy barrier, shimmering.
    barrier = smooth(r * 0.86, r * 0.8, d)
    shimmer = noise(rng, 18) * 0.6 + noise(rng, 6) * 0.4
    e.paint(barrier * 0.55, np.array([0.04, 0.16, 0.24]))
    e.light(barrier * (0.25 + 0.5 * shimmer) * smooth(0, r * 0.85, d), CYAN * 0.5)
    # Traffic lanes: in at the bottom left, out at the bottom right, and the
    # top third split again by a flipped divider: emergencies in the
    # middle, drone lanes at the top left and right.
    lane = {'in': (np.pi * 0.5, np.pi * (5 / 6)), 'out': (np.pi / 6, np.pi * 0.5)}
    for (a0, a1), col in zip(lane.values(), [hexcol('5CFF8A'), hexcol('FFB547')]):
        sector = ((ang > a0) & (ang < a1)).astype(np.float32)
        e.light(ndimage.gaussian_filter(sector, 3) * barrier * 0.22, col)
    hub = (C, C - r * 0.38)
    spokes = [
        [(C, C), (C, C + r * 0.84)],
        [(C, C), (C - r * 0.84 * math.cos(np.pi / 6), C - r * 0.84 * 0.5)],
        [(C, C), (C + r * 0.84 * math.cos(np.pi / 6), C - r * 0.84 * 0.5)],
        [hub, (C, C - r * 0.84)],
        [hub, (C - r * 0.19, C - r * 0.11)],
        [hub, (C + r * 0.19, C - r * 0.11)],
    ]
    div = lines(spokes, S * 0.008)
    e.light(glow(div, 8, 1.2), CYAN)
    e.paint(div, ICE)
    emergency = polygon([(C, C), (C - r * 0.19, C - r * 0.11), hub, (C + r * 0.19, C - r * 0.11)])
    e.light(ndimage.gaussian_filter(emergency, 2) * 0.45, CRIMSON)
    # The ring itself: old metal, lit from the top left, with a glowing lip.
    ring = smooth(r * 0.84, r * 0.86, d) * smooth(r * 1.12, r * 1.1, d)
    tube = np.clip(1 - np.abs(d - r * 0.98) / (r * 0.14), 0, 1)
    lit = 0.25 + 0.75 * np.clip(-np.cos(ang + np.pi * 0.25) * 0.5 + 0.5, 0, 1)
    metal = STEEL * (0.3 + 0.7 * tube[..., None] * lit[..., None])
    for k in range(12):  # the segments it was built in
        seg = np.abs(np.sin((ang - k * np.pi / 6) / 2)) < 0.012
        metal = metal * (1 - 0.5 * seg[..., None])
    e.paint(ring, metal)
    lip = np.exp(-((d - r * 0.86) / (r * 0.015)) ** 2)
    e.light(lip * 1.2 + glow(lip, 10, 0.8), CYAN)
    return bg, e


# 3. Hell ----------------------------------------------------------------------------

def hell(rng):
    f = (noise(rng, 120) * 0.5 + noise(rng, 40) * 0.3 + noise(rng, 10) * 0.2) ** 1.5
    bg = VOID * (1 - f[..., None]) + BRANDY * 0.8 * f[..., None]
    bg = stars(bg, rng, 500, AMBER * 0.7, 1.2)
    e = Emblem()
    cx, cy, r, tilt, angle = C * 0.94, C * 1.02, S * 0.13, 0.24, -0.18
    ca, sa = math.cos(angle), math.sin(angle)
    dx, dy = XX - cx, YY - cy
    u, v = dx * ca + dy * sa, -dx * sa + dy * ca
    rd = np.hypot(u, v / tilt)
    theta = np.arctan2(v / tilt, u)
    streaks = ndimage.gaussian_filter(rng.standard_normal((S, S)).astype(np.float32), (1, 30))
    streaks = (streaks - streaks.min()) / (streaks.max() - streaks.min())
    band = smooth(r * 1.4, r * 1.8, rd) * (1 - smooth(r * 2.2, r * 3.4, rd))
    disk = band * (1 + 0.7 * np.cos(theta + 0.4)) * (0.5 + 0.9 * streaks)
    t = smooth(r * 1.4, r * 3.4, rd)[..., None]
    disk_col = HOT * (1 - t) + AMBER * t
    dist = np.hypot(dx, dy)
    back, front = (v < 0), (v >= 0)
    e.rgb += (disk * back)[..., None] * disk_col
    lens = np.exp(-((dist - r * 1.3) / (r * 0.12)) ** 2) * smooth(0, 0.6, -v / r)
    e.light(lens * 1.3, HOT)
    e.light(glow(disk > 0.3, r * 0.5, 0.5), AMBER)
    e.paint(smooth(r * 1.02, r * 0.97, dist), VOID)
    e.light(np.exp(-((dist - r * 1.03) / (r * 0.025)) ** 2) * 1.2, HOT)
    e.rgb += (disk * front)[..., None] * disk_col * 1.2
    # The planet at the lip, held back from the edge.
    px, py, pr = cx + r * 2.75, cy - r * 1.05, S * 0.055
    sea = np.array([0.22, 0.5, 0.52])
    land = np.array([0.42, 0.34, 0.2])
    cont = noise(rng, 9) > 0.55
    surf = np.where(cont[..., None], land, sea)
    e.paint(ellipse(px, py, pr, pr), shaded_sphere(px, py, pr, surf, (-0.9, 0.2), 0.04))
    rim = np.exp(-((np.hypot(XX - px, YY - py) - pr) / (pr * 0.08)) ** 2)
    e.light(rim * 0.9 + glow(ellipse(px, py, pr * 1.3, pr * 1.3), 25, 0.35), GOLD)
    return bg, e


# 4. The Tern ------------------------------------------------------------------------

def tern(rng):
    bg = radial(np.array([0.03, 0.16, 0.2]), np.array([0.0, 0.03, 0.05]))
    e = Emblem()
    side, rows = S * 0.72, 12
    h = side * math.sqrt(3) / 2
    top = np.array([C, C - h * 0.58])
    pts = []
    for i in range(rows + 1):
        for j in range(i + 1):
            p = top + np.array([(j - i / 2) * side / rows, i * h / rows])
            pts.append(p)
    pts = np.array(pts)
    centroid = top + [0, h * 2 / 3]
    # Nanobots: the lattice holds in the middle and comes apart at the edges.
    edge = np.hypot(*(pts - centroid).T) / (h * 0.66)
    jitter = rng.normal(0, 1, pts.shape) * (S * 0.012) * edge[:, None] ** 3
    pts = pts + jitter
    net = []
    for i, p in enumerate(pts):
        for q in pts[i + 1:]:
            if np.hypot(*(p - q)) < side / rows * 1.15:
                net.append([tuple(p), tuple(q)])
    e.light(lines(net, S * 0.003) * 0.35, CYAN)
    dots = np.zeros((S, S), np.float32)
    for p, ed in zip(pts, edge):
        x, y = int(p[0]), int(p[1])
        if 0 <= x < S and 0 <= y < S:
            dots[y, x] = 1.4 - 0.6 * min(ed, 1)
    e.light(glow(dots, 3, 60), ICE)
    e.light(glow(dots, 12, 120), CYAN * 0.5)
    # The hive's core: a triad.
    core = [centroid + np.array([math.cos(a), math.sin(a)]) * S * 0.05
            for a in (-np.pi / 2, np.pi / 6, np.pi * 5 / 6)]
    for p in core:
        e.paint(ellipse(p[0], p[1], S * 0.018, S * 0.018), WHITE)
        e.light(glow(ellipse(p[0], p[1], S * 0.03, S * 0.03), 14, 1.4), CYAN)
    return bg, e


# The Hellborn --------------------------------------------------------------------------

def hellborn(rng):
    bg = radial(np.array([0.35, 0.05, 0.04]), np.array([0.04, 0.0, 0.0]))
    bg = bg * (0.85 + 0.3 * noise(rng, 30))[..., None]
    e = Emblem()
    bone = np.array([0.88, 0.8, 0.66])
    for sgn in (-1, 1):
        horn = bezier((C + sgn * S * 0.14, C - S * 0.1), (C + sgn * S * 0.38, C - S * 0.05),
                      (C + sgn * S * 0.44, C - S * 0.3), (C + sgn * S * 0.3, C - S * 0.42))
        m = tapered(horn, S * 0.11, S * 0.012)
        grain = 0.75 + 0.25 * np.sin(np.hypot(XX - C, YY - C) * 0.12)[..., None]
        e.paint(m, bone * grain * (0.55 + 0.45 * smooth(C + S * 0.2, C - S * 0.4, YY))[..., None])
    helm = [(C, C - S * 0.28), (C + S * 0.17, C - S * 0.2), (C + S * 0.22, C + S * 0.05),
            (C + S * 0.15, C + S * 0.3), (C, C + S * 0.4), (C - S * 0.15, C + S * 0.3),
            (C - S * 0.22, C + S * 0.05), (C - S * 0.17, C - S * 0.2)]
    m = polygon(helm)
    iron = np.array([0.2, 0.17, 0.17])
    plate = iron * (0.6 + 0.9 * smooth(C + S * 0.2, C - S * 0.3, XX * 0.4 + YY * 0.8 - C * 0.2))[..., None]
    e.paint(m, plate)
    e.light(glow(lines([helm + [helm[0]]], S * 0.006), 3, 1.0) * m, np.array([0.9, 0.5, 0.35]))
    ridge = lines([[(C, C - S * 0.27), (C, C + S * 0.38)]], S * 0.012)
    e.paint(ridge * 0.8, iron * 1.8)
    for sgn in (-1, 1):
        slit = polygon([(C + sgn * S * 0.04, C + S * 0.03), (C + sgn * S * 0.17, C - S * 0.04),
                        (C + sgn * S * 0.16, C + S * 0.0), (C + sgn * S * 0.05, C + S * 0.06)])
        e.paint(slit, np.array([1.0, 0.55, 0.15]))
        e.light(glow(slit, 16, 2.5), np.array([1.0, 0.3, 0.05]))
    return bg, e


# 6. The Ál ----------------------------------------------------------------------------

def al(rng):
    """Like the Sentinels of The Matrix, but alive: a black body, a cluster
    of eyes and thick tentacles trailing behind. Black, having evolved where
    little light reaches: seen by the faint light from far above, and by
    their own."""
    depth = smooth(0, S, YY)[..., None]
    bg = np.array([0.03, 0.14, 0.18]) * (1 - depth) + np.array([0.0, 0.015, 0.035]) * depth
    # A dim shaft of light from the surface, far above: enough to show a
    # silhouette.
    shaft = np.exp(-((XX - C - (YY - C) * 0.15) / (S * 0.28)) ** 2) * (1 - depth[..., 0]) ** 1.5
    bg = bg + (shaft * 0.12)[..., None] * ICE
    snow = np.zeros((S, S), np.float32)
    snow[rng.integers(0, S, 500), rng.integers(0, S, 500)] = rng.uniform(0.2, 1, 500)
    bg = bg + ndimage.gaussian_filter(snow, 1.0)[..., None] * 3 * np.array([0.5, 0.7, 0.75])
    e = Emblem()
    black = np.array([0.025, 0.025, 0.035])
    sheen_col = np.array([0.35, 0.6, 0.75])
    photophore = np.array([0.3, 0.95, 1.0])
    above = (1 - YY / S)  # the sheen is brighter where light falls from above

    def sheen(mask, width):
        edge = np.clip(mask - ndimage.gaussian_filter(mask, width), 0, 1) * 2.2
        return np.clip(edge, 0, 1) * (0.35 + 0.65 * above)

    bx, by, br = C, S * 0.34, S * 0.19
    lights = np.zeros((S, S), np.float32)
    # Tentacles trailing down and behind, as if it is rising.
    for k in range(7):
        a = np.pi / 2 + (k - 3) * 0.32 + rng.uniform(-0.06, 0.06)
        sway = rng.choice([-1, 1]) * rng.uniform(0.6, 1.0)
        r1 = S * rng.uniform(0.5, 0.64)
        p0 = (bx + math.cos(a) * br * 0.7, by + math.sin(a) * br * 0.7)
        p1 = (bx + math.cos(a) * r1 * 0.4 + sway * S * 0.16, by + math.sin(a) * r1 * 0.4)
        p2 = (bx + math.cos(a) * r1 * 0.7 - sway * S * 0.22, by + math.sin(a) * r1 * 0.7)
        p3 = (bx + math.cos(a) * r1 + sway * S * 0.1, by + math.sin(a) * r1)
        path = bezier(p0, p1, p2, p3)
        m = tapered(path, S * 0.15, S * 0.03)
        e.paint(m, black)
        e.light(sheen(m, 6) * 0.55, sheen_col)
        # Their own lights, in a row down each arm.
        for i in range(10, len(path) - 6, 9):
            x, y = path[i]
            if 0 <= int(x) < S and 0 <= int(y) < S:
                lights[int(y), int(x)] = 1.6 * (1 - i / len(path)) + 0.4
    body = ellipse(bx, by, br, br * 0.95)
    e.paint(body, shaded_sphere(bx, by, br, black * 2.2, (-0.4, -0.7), 0.4))
    e.light(sheen(body, 9) * 0.6, sheen_col)
    spec = np.exp(-(((XX - bx + S * 0.08) / (S * 0.05)) ** 2 + ((YY - by + S * 0.13) / (S * 0.025)) ** 2))
    e.light(spec * body * 0.35, sheen_col)
    for k in range(9):  # a ring of lights round the mantle
        t = np.pi * (1.1 + 0.8 * k / 8)
        x, y = bx + math.cos(t) * br * 0.85, by + math.sin(t) * br * 0.8
        lights[int(y), int(x)] = 1.3
    e.light(glow(lights, 2.2, 45), WHITE * 0.7)
    e.light(glow(lights, 9, 90), photophore * 0.6)

    def eye(x, y, r, bar=True):
        """Pale and made for the dark, shining back at the light."""
        e.paint(ellipse(x, y, r * 1.14, r * 1.14), np.array([0.05, 0.08, 0.1]))
        iris = ellipse(x, y, r, r)
        d = np.hypot(XX - x, YY - y) / r
        fibres = 0.8 + 0.2 * np.sin(np.arctan2(YY - y, XX - x) * 48 + noise(rng, 3) * 6)
        tone = (0.55 + 0.45 * smooth(1.0, 0.3, d)) * fibres
        e.paint(iris, np.array([0.5, 0.78, 0.85]) * tone[..., None])
        e.paint(iris * smooth(0.8, 1.0, d) * 0.8, np.array([0.04, 0.12, 0.16]))
        e.light(glow(iris, r * 0.2, 0.5), photophore * 0.6)
        # An octopus's pupil: a bar with rounded ends.
        pw, ph = (r * 0.62, r * 0.19) if bar else (r * 0.3, r * 0.3)
        pupil = _mask(lambda dr, k: dr.rounded_rectangle(
            [(x - pw) * k, (y - ph) * k, (x + pw) * k, (y + ph) * k], radius=ph * k, fill=255))
        e.paint(pupil, VOID)
        e.paint(ellipse(x - r * 0.4, y - r * 0.45, r * 0.16, r * 0.16), WHITE)

    eye(bx, by, S * 0.085)
    # A cluster of smaller eyes round the big one, as a Sentinel has.
    for t in (0.2, 0.8, 1.2, 1.8):
        a = np.pi * t - np.pi / 2
        eye(bx + math.cos(a) * S * 0.135, by + math.sin(a) * S * 0.125, S * 0.027, bar=False)
    return bg, e


# 7. The Bhrun ----------------------------------------------------------------------

def rot_ellipse(cx, cy, rx, ry, angle, n=48):
    ca, sa = math.cos(angle), math.sin(angle)
    return [(cx + rx * math.cos(t) * ca - ry * math.sin(t) * sa,
             cy + rx * math.cos(t) * sa + ry * math.sin(t) * ca)
            for t in np.linspace(0, 2 * np.pi, n, endpoint=False)]


def bhrun(rng):
    """A massive beetle of a creature in grey, rock-like plates, on four
    massive legs, with a face of plates that move. Maybe made of silicon."""
    horizon = S * 0.62
    sky = smooth(0, horizon, YY)[..., None]
    bg = np.array([0.62, 0.58, 0.45]) * (1 - sky) + np.array([0.93, 0.83, 0.6]) * sky
    ground = smooth(horizon - 2, horizon + 2, YY)[..., None]
    dirt = np.array([0.42, 0.37, 0.28]) * (0.8 + 0.4 * noise(rng, 6))[..., None]
    bg = bg * (1 - ground) + dirt * ground
    e = Emblem()
    rock = 0.75 + 0.35 * (noise(rng, 2) * 0.4 + noise(rng, 8) * 0.6)
    grey = np.array([0.5, 0.5, 0.48])
    lx, ly = -0.5, -0.7
    lz = math.sqrt(1 - lx * lx - ly * ly)

    def plated(mask, colour, cx, cy, r):
        """A rock plate, lit from the top left."""
        e.paint(mask, shaded_sphere(cx, cy, r, colour * rock[..., None], (lx, ly), 0.35))

    def segment(p0, p1, w0, w1, colour):
        """A leg segment: a plated cylinder from p0 to p1, w0 to w1 thick,
        with a dark rim where it meets the next."""
        p0, p1 = np.array(p0) * S, np.array(p1) * S
        u = (p1 - p0) / np.linalg.norm(p1 - p0)
        n = np.array([-u[1], u[0]])
        pts = [tuple(p0 + (p1 - p0) * t) for t in np.linspace(0, 1, 50)]
        m = tapered(pts, S * w0, S * w1)
        t = np.clip(((XX - p0[0]) * u[0] + (YY - p0[1]) * u[1]) / np.linalg.norm(p1 - p0), 0, 1)
        half = S * (w0 + (w1 - w0) * t) / 2
        side = np.clip(((XX - p0[0]) * n[0] + (YY - p0[1]) * n[1]) / half, -1, 1)
        z = np.sqrt(1 - side ** 2)
        lam = np.clip(side * (n[0] * lx + n[1] * ly) + z * lz, 0, 1)
        e.paint(m, colour * rock[..., None] * (0.3 + 0.75 * lam)[..., None])
        e.paint(np.clip(m - ndimage.gaussian_filter(m, 3), 0, 1) * 1.5, colour * 0.25)

    # Four massive legs: the back pair behind and darker, each in two
    # plated segments with a plate over the knee.
    for (coxa, knee, foot, w, shade) in [
        ((0.24, 0.58), (0.34, 0.7), (0.31, 0.9), (0.1, 0.085, 0.075), 0.55),
        ((0.3, 0.55), (0.43, 0.66), (0.39, 0.95), (0.15, 0.125, 0.105), 0.9),
    ]:
        for sgn in (-1, 1):
            c0, k0, f0 = ((0.5 + sgn * x, y) for x, y in (coxa, knee, foot))
            segment(c0, k0, w[0], w[1], grey * shade)
            segment(k0, f0, w[1], w[2], grey * shade * 0.92)
            kx, ky = k0[0] * S, k0[1] * S
            plated(ellipse(kx, ky, S * w[1] * 0.62, S * w[1] * 0.55), grey * shade * 1.05, kx, ky - S * 0.02, S * w[1])
            fx_, fy_ = f0[0] * S, f0[1] * S
            plated(ellipse(fx_, fy_, S * w[2] * 0.8, S * w[2] * 0.35), grey * shade * 0.8, fx_, fy_ - S * 0.02, S * w[2])
    # The shell: a dome of plates, cracked between them.
    cx, cy, rx, ry = C, S * 0.4, S * 0.4, S * 0.28
    shell = ellipse(cx, cy, rx, ry)
    seeds = []
    while len(seeds) < 24:
        p = rng.uniform(-1, 1, 2)
        if p @ p < 1:
            seeds.append((cx + p[0] * rx, cy + p[1] * ry))
    seeds = np.array(seeds)
    d = np.stack([np.hypot(XX - x, YY - y) for x, y in seeds])
    order = np.sort(d, axis=0)
    cell = np.argmin(d, axis=0)
    crack = smooth(S * 0.009, S * 0.002, order[1] - order[0])
    shade = rng.uniform(0.8, 1.15, len(seeds))[cell]
    tex = grey * (shade * rock)[..., None] * (1 - 0.75 * crack[..., None])
    e.paint(shell, shaded_sphere(cx, cy, rx, tex, (-0.5, -0.75), 0.3))
    e.light(np.clip(shell - ndimage.gaussian_filter(shell, 6), 0, 1) * 0.4 * (YY < cy), WHITE * 0.5)
    # The face: plates over plates, which move.
    fx, fy = C, S * 0.65
    e.paint(ellipse(fx, fy, S * 0.2, S * 0.155), grey * 0.22)
    for k in range(9):
        a = -np.pi / 2 + k * 2 * np.pi / 9
        px, py = fx + math.cos(a) * S * 0.1, fy + math.sin(a) * S * 0.08
        m = polygon(rot_ellipse(px, py, S * 0.08, S * 0.045, a + np.pi / 2))
        plated(m, grey * rng.uniform(0.7, 0.95), px, py - S * 0.02, S * 0.08)
        e.paint(np.clip(m - ndimage.gaussian_filter(m, 2.5), 0, 1) * 1.6, grey * 0.2)
    for k in range(3):
        a = -np.pi / 2 + k * 2 * np.pi / 3 + np.pi / 3
        px, py = fx + math.cos(a) * S * 0.035, fy + math.sin(a) * S * 0.035
        m = polygon(rot_ellipse(px, py, S * 0.05, S * 0.028, a + np.pi / 2))
        plated(m, grey * 0.65, px, py - S * 0.015, S * 0.05)
        e.paint(np.clip(m - ndimage.gaussian_filter(m, 2), 0, 1) * 1.6, grey * 0.15)
    for sgn in (-1, 1):  # eyes, deep between the plates
        ex, ey = fx + sgn * S * 0.14, fy - S * 0.07
        e.paint(ellipse(ex, ey, S * 0.016, S * 0.012), np.array([0.85, 0.6, 0.25]))
        e.light(glow(ellipse(ex, ey, S * 0.016, S * 0.012), 6, 0.6), AMBER)
    return bg, e


# 8. The Unfortunates ------------------------------------------------------------

def unfortunates(rng):
    """Immortal machines of smooth, curved white metal and platinum,
    elvish-inspired but not elves. Proud, cloistered and bitter, a shadow of
    what they were before the gatecrash: one of them, cracked, in front of a
    gate they won't admit to having built."""
    fog = noise(rng, 70) * 0.6 + noise(rng, 20) * 0.4
    bg = radial(np.array([0.13, 0.1, 0.22]), np.array([0.015, 0.01, 0.035]), cy=S * 0.4) \
        * (0.75 + 0.5 * fog)[..., None]
    d = np.hypot(XX - C, YY - S * 0.44)
    arc = np.exp(-((d - S * 0.43) / (S * 0.007)) ** 2)
    bg = bg + (arc * 0.5 + glow(arc, 14, 0.5))[..., None] * CYAN * 0.5
    bg = stars(bg, rng, 200, ICE * 0.6)
    e = Emblem()
    platinum = np.array([0.88, 0.89, 0.92])
    gold = np.array([0.95, 0.78, 0.42])
    eye_col = np.array([0.7, 0.95, 1.0])

    def chrome(cx, cy, rx, ry, tint=platinum):
        """Polished white metal: a soft diffuse light, a sky reflected in the
        top half and a darker floor in the bottom, and a hard highlight."""
        dx, dy = (XX - cx) / rx, (YY - cy) / ry
        z = np.sqrt(np.clip(1 - dx * dx - dy * dy, 0, 1))
        lam = np.clip(-0.45 * dx - 0.55 * dy + 0.7 * z, 0, 1)
        sky = smooth(0.35, -0.6, dy)  # reflected: bright above, dark below
        spec = np.clip(-0.45 * dx - 0.55 * dy + 0.7 * z, 0, 1) ** 24
        tone = 0.42 + 0.4 * lam + 0.35 * sky
        return tint * tone[..., None] + spec[..., None] * 0.7

    hx, hy = C, S * 0.47
    # The neck and collar.
    neck = polygon([(hx - S * 0.07, hy + S * 0.2), (hx + S * 0.07, hy + S * 0.2),
                    (hx + S * 0.09, hy + S * 0.38), (hx - S * 0.09, hy + S * 0.38)])
    e.paint(neck, chrome(hx, hy + S * 0.3, S * 0.12, S * 0.14) * 0.7)
    collar = polygon(rot_ellipse(hx, hy + S * 0.47, S * 0.36, S * 0.13, 0))
    e.paint(collar, chrome(hx, hy + S * 0.45, S * 0.36, S * 0.14))
    e.paint(lines([bezier((hx - S * 0.3, hy + S * 0.42), (hx - S * 0.1, hy + S * 0.36),
                          (hx + S * 0.1, hy + S * 0.36), (hx + S * 0.3, hy + S * 0.42))], S * 0.005), gold * 0.85)
    # The head: a long face, round at the crown, narrowing to a fine chin.
    outline = (bezier((hx, hy - S * 0.25), (hx + S * 0.17, hy - S * 0.25),
                      (hx + S * 0.16, hy + S * 0.02), (hx + S * 0.1, hy + S * 0.14))
               + bezier((hx + S * 0.1, hy + S * 0.14), (hx + S * 0.06, hy + S * 0.22),
                        (hx + S * 0.02, hy + S * 0.25), (hx, hy + S * 0.25))[1:])
    outline = outline + [(2 * hx - x, y) for x, y in reversed(outline[:-1])]
    face = polygon(outline)
    e.paint(face, chrome(hx, hy - S * 0.02, S * 0.16, S * 0.27))
    seams = [
        [(hx, hy - S * 0.25), (hx, hy - S * 0.1)],
        # Cheek plates, meeting under the eyes.
        bezier((hx - S * 0.13, hy + S * 0.04), (hx - S * 0.08, hy + S * 0.06),
               (hx - S * 0.05, hy + S * 0.12), (hx - S * 0.04, hy + S * 0.2)),
        bezier((hx + S * 0.13, hy + S * 0.04), (hx + S * 0.08, hy + S * 0.06),
               (hx + S * 0.05, hy + S * 0.12), (hx + S * 0.04, hy + S * 0.2)),
    ]
    e.paint(lines(seams, S * 0.0028) * face * 0.7, platinum * 0.35)
    # A thin gold circlet.
    e.paint(lines([bezier((hx - S * 0.145, hy - S * 0.1), (hx - S * 0.06, hy - S * 0.16),
                          (hx + S * 0.06, hy - S * 0.16), (hx + S * 0.145, hy - S * 0.1))], S * 0.007) * face,
            gold)
    e.paint(polygon([(hx, hy - S * 0.175), (hx + S * 0.018, hy - S * 0.145), (hx, hy - S * 0.12),
                     (hx - S * 0.018, hy - S * 0.145)]), eye_col)
    # Narrow eyes, slanting up and out.
    for sgn in (-1, 1):
        eye = polygon([(hx + sgn * S * 0.025, hy - S * 0.012), (hx + sgn * S * 0.07, hy - S * 0.026),
                       (hx + sgn * S * 0.118, hy - S * 0.05), (hx + sgn * S * 0.085, hy - S * 0.014),
                       (hx + sgn * S * 0.045, hy - S * 0.004)])
        e.paint(eye, eye_col)
        e.light(glow(eye, 8, 1.2), CYAN * 0.7)
    # The crack: down from one eye, showing the dark inside.
    crack = [(hx + S * 0.075, hy - S * 0.005), (hx + S * 0.085, hy + S * 0.04), (hx + S * 0.074, hy + S * 0.075),
             (hx + S * 0.098, hy + S * 0.12), (hx + S * 0.088, hy + S * 0.15)]
    e.paint(lines([crack], S * 0.0035) * face, VOID)
    e.paint(lines([[(hx + S * 0.085, hy + S * 0.04), (hx + S * 0.105, hy + S * 0.048)],
                   [(hx + S * 0.098, hy + S * 0.12), (hx + S * 0.113, hy + S * 0.116)]], S * 0.002) * face, VOID)
    return bg, e


# 9. The Gor ------------------------------------------------------------------------

def gor(rng):
    """Gangly and muscular: four legs carry a lower body that rises at 45°,
    and on a mobile joint an upright upper body with two arms a side.
    Against the sunset of Ur-Gor, the world they took."""
    horizon = S * 0.8
    sky = smooth(S * 0.05, horizon, YY)[..., None]
    bg = np.array([0.22, 0.07, 0.2]) * (1 - sky) + np.array([1.0, 0.5, 0.18]) * sky
    sx, sy = S * 0.6, S * 0.66
    sun = smooth(S * 0.2, S * 0.19, np.hypot(XX - sx, YY - sy))
    bg = bg * (1 - sun[..., None]) + np.array([1.0, 0.85, 0.55]) * sun[..., None]
    bg = bg + glow(sun, 60, 1.0)[..., None] * np.array([1.0, 0.55, 0.2]) * 0.6
    hills = horizon + S * 0.04 * np.sin(XX / S * 7 + 1) + S * 0.025 * np.sin(XX / S * 17)
    ground = smooth(hills - 1, hills + 1, YY)[..., None]
    bg = bg * (1 - ground) + np.array([0.12, 0.04, 0.05]) * ground
    e = Emblem()
    near, far = np.array([0.13, 0.06, 0.07]), np.array([0.07, 0.03, 0.04])
    union = np.zeros((S, S), np.float32)

    def limb(points, w0, w1, colour):
        nonlocal union
        pts = []
        for (x0, y0), (x1, y1) in zip(points, points[1:]):
            for t in np.linspace(0, 1, 30, endpoint=False):
                pts.append(((x0 + (x1 - x0) * t) * S, (y0 + (y1 - y0) * t) * S))
        pts.append((points[-1][0] * S, points[-1][1] * S))
        m = tapered(pts, S * w0, S * w1)
        e.paint(m, colour)
        union = np.maximum(union, m)

    def blob(mask, colour):
        nonlocal union
        e.paint(mask, colour)
        union = np.maximum(union, mask)

    ground_y = 0.86
    # The far legs and arms, in shadow.
    limb([(0.47, 0.5), (0.51, 0.67), (0.46, ground_y)], 0.04, 0.02, far)
    limb([(0.35, 0.66), (0.27, 0.76), (0.33, ground_y)], 0.045, 0.02, far)
    limb([(0.555, 0.22), (0.49, 0.28), (0.45, 0.19)], 0.048, 0.03, far)
    limb([(0.555, 0.31), (0.48, 0.36), (0.43, 0.3)], 0.042, 0.028, far)
    blob(ellipse(0.43 * S, 0.3 * S, S * 0.02, S * 0.02), far)
    blob(ellipse(0.45 * S, 0.19 * S, S * 0.022, S * 0.022), far)
    # The lower body, rising at 45°.
    limb([(0.26, 0.67), (0.52, 0.43)], 0.12, 0.15, near)
    blob(ellipse(0.545 * S, 0.43 * S, 0.055 * S, 0.055 * S), near)  # the joint
    # The near legs.
    limb([(0.52, 0.47), (0.58, 0.66), (0.55, ground_y)], 0.045, 0.022, near)
    limb([(0.3, 0.68), (0.2, 0.77), (0.26, ground_y)], 0.05, 0.022, near)
    for x in (0.55, 0.46, 0.26, 0.33):  # feet
        blob(ellipse(x * S + S * 0.012, ground_y * S, S * 0.025, S * 0.012), near)
    # The upper body, upright, broad in the chest.
    limb([(0.55, 0.44), (0.575, 0.2)], 0.1, 0.17, near)
    limb([(0.58, 0.19), (0.6, 0.13)], 0.07, 0.05, near)
    blob(polygon([(0.575 * S, 0.095 * S), (0.62 * S, 0.075 * S), (0.68 * S, 0.095 * S),
                  (0.715 * S, 0.125 * S), (0.665 * S, 0.145 * S), (0.595 * S, 0.155 * S)]), near)
    blob(polygon([(0.585 * S, 0.09 * S), (0.535 * S, 0.05 * S), (0.6 * S, 0.08 * S)]), near)  # crest
    # A spear, and the near arms: the upper one holds it, the lower one
    # reaches forward.
    e.paint(lines([[(0.79 * S, 0.0), (0.715 * S, 0.5 * S)]], S * 0.012), near)
    union = np.maximum(union, lines([[(0.79 * S, 0.0), (0.715 * S, 0.5 * S)]], S * 0.012))
    limb([(0.605, 0.22), (0.69, 0.28), (0.755, 0.17)], 0.06, 0.034, near)
    blob(ellipse(0.757 * S, 0.165 * S, S * 0.024, S * 0.024), near)
    limb([(0.6, 0.31), (0.67, 0.38), (0.73, 0.36)], 0.054, 0.032, near)
    blob(ellipse(0.733 * S, 0.358 * S, S * 0.021, S * 0.021), near)
    # The setting sun rims everything that faces it.
    edge = np.clip(union - ndimage.gaussian_filter(union, 4), 0, 1) * 2.2
    toward = np.exp(-np.hypot(XX - sx, YY - sy) / (S * 0.35))
    e.light(np.clip(edge, 0, 1) * (0.25 + 1.2 * toward), np.array([1.0, 0.6, 0.3]))
    eye = ellipse(0.665 * S, 0.105 * S, S * 0.008, S * 0.006)
    e.paint(eye, np.array([1.0, 0.85, 0.4]))
    e.light(glow(eye, 4, 1.2), np.array([1.0, 0.6, 0.2]))
    return bg, e


# 10. A demon -----------------------------------------------------------------------

def demon(rng):
    """Hell's own: no single shape, nothing anyone should look at for long.
    Eyes, tentacles, and a mouth that is mostly teeth."""
    f = (noise(rng, 120) * 0.5 + noise(rng, 40) * 0.3 + noise(rng, 10) * 0.2) ** 1.5
    bg = VOID * (1 - f[..., None]) + BRANDY * 0.8 * f[..., None]
    bg = stars(bg, rng, 500, AMBER * 0.7, 1.2)
    e = Emblem()
    flesh = np.array([0.2, 0.04, 0.06])
    veins = np.abs(noise(rng, 7) - 0.5) < 0.025
    skin = flesh * (0.7 + 0.5 * noise(rng, 5))[..., None] + glow(veins, 1.5, 0.6)[..., None] * CRIMSON * 0.6

    def sheen(mask, width):
        return np.clip(np.clip(mask - ndimage.gaussian_filter(mask, width), 0, 1) * 2.2, 0, 1)

    for k in range(11):
        a = k * 2 * np.pi / 11 + rng.uniform(-0.2, 0.2)
        curl = rng.choice([-1, 1]) * rng.uniform(0.6, 1.6)
        r1 = S * rng.uniform(0.38, 0.5)
        p0 = (C + math.cos(a) * S * 0.15, C + math.sin(a) * S * 0.15)
        p1 = (C + math.cos(a) * r1 * 0.6, C + math.sin(a) * r1 * 0.6)
        p2 = (C + math.cos(a + curl * 0.4) * r1, C + math.sin(a + curl * 0.4) * r1)
        p3 = (C + math.cos(a + curl * 0.9) * r1 * 0.85, C + math.sin(a + curl * 0.9) * r1 * 0.85)
        m = tapered(bezier(p0, p1, p2, p3), S * rng.uniform(0.06, 0.1), S * 0.01)
        e.paint(m, skin)
        e.light(sheen(m, 5) * 0.5, AMBER)
    # The body: no particular shape.
    d = np.hypot(XX - C, YY - C)
    edge = S * 0.24 * (0.85 + 0.35 * noise(rng, 30))
    body = smooth(edge + 2, edge - 2, d)
    e.paint(body, shaded_sphere(C, C, S * 0.26, skin * 1.4, (-0.3, -0.6), 0.35))
    e.light(sheen(body, 8) * 0.5, AMBER)
    # A mouth that is mostly teeth.
    mx, my, mw, mh = C, C + S * 0.06, S * 0.05, S * 0.12
    e.paint(ellipse(mx, my, mw, mh), VOID)
    bone = np.array([0.9, 0.84, 0.7])
    for side in (-1, 1):
        for k in range(9):
            t = -0.9 + 1.8 * k / 8
            y = my + t * mh
            x = mx + side * mw * math.sqrt(max(0, 1 - t * t))
            tooth = polygon([(x, y - S * 0.012), (x, y + S * 0.012), (x - side * S * 0.032, y + S * 0.004)])
            e.paint(tooth, bone)
    # Eyes, too many of them.
    placed = []
    while len(placed) < 10:
        a, r = rng.uniform(0, 2 * np.pi), rng.uniform(0.07, 0.2) * S
        x, y = C + math.cos(a) * r, C + math.sin(a) * r * 0.9
        er = rng.uniform(0.015, 0.04) * S
        if abs(x - mx) < mw + er * 1.4 and abs(y - my) < mh + er:
            continue
        if any(math.hypot(x - px, y - py) < er + pr + S * 0.01 for px, py, pr in placed):
            continue
        if math.hypot(x - C, y - C) + er > S * 0.22:
            continue
        placed.append((x, y, er))
        ball = ellipse(x, y, er, er)
        e.paint(ball, shaded_sphere(x, y, er, np.array([1.0, 0.78, 0.25]), (-0.4, -0.5), 0.4))
        e.light(glow(ball, er * 0.6, 0.6), AMBER)
        e.paint(ellipse(x, y, er * 0.18, er * 0.8), VOID)
    return bg, e


# 11. The Havi ------------------------------------------------------------------------

def havi(rng):
    """Ethereal and godlike, near invincible. They can take any shape, but
    mostly appear as an amoeba-like cloud of golden smoke and gel."""
    bg = radial(np.array([0.08, 0.06, 0.03]), np.array([0.005, 0.005, 0.01]))
    bg = stars(bg, rng, 500, GOLD * 0.8)
    e = Emblem()
    d = np.hypot(XX - C, YY - C)
    ang = np.arctan2(YY - C, XX - C)
    # The gel: a body with no fixed shape, reaching out in soft lobes.
    lobes = sum(rng.uniform(0.06, 0.12) * np.cos(k * ang + rng.uniform(0, 2 * np.pi)) for k in (2, 3, 5))
    edge = S * 0.2 * (1 + lobes) * (0.92 + 0.16 * noise(rng, 30))
    body = smooth(edge + 3, edge - 3, d)
    depth = np.clip(1 - d / np.maximum(edge, 1), 0, 1)
    inner = noise(rng, 12)
    swirl = np.abs(np.sin(ang * 3 + d / S * 18 + inner * 5))
    gel = GOLD * (0.25 + 0.55 * depth ** 0.7 + 0.25 * swirl * depth)[..., None]
    e.paint(body * 0.8, gel)
    # Gel, not glass: a soft brightening toward the edge, not a hard rim.
    fresnel = smooth(edge - S * 0.06, edge, d) * body
    e.light(fresnel * 0.45, HOT)
    veins = np.abs(noise(rng, 9) - 0.5) < 0.03
    e.light(glow(veins, 2, 0.8) * body * depth, HOT * 0.6)
    core = np.exp(-(d / (S * 0.07)) ** 2)
    e.light(core * 1.8 + glow(body, 30, 0.4), np.array([1.0, 0.85, 0.5]))
    # The smoke: curling around and out of it.
    smoke = np.zeros((S, S), np.float32)
    for k in range(7):
        a0 = k * 2 * np.pi / 7 + rng.uniform(-0.3, 0.3)
        turn = rng.choice([-1, 1]) * rng.uniform(1.2, 2.2)
        pts = []
        for t in np.linspace(0, 1, 80):
            r = S * (0.17 + 0.25 * t)
            a = a0 + turn * t
            pts.append((C + math.cos(a) * r, C + math.sin(a) * r))
        smoke = np.maximum(smoke, tapered(pts, S * 0.07, S * 0.01))
    streaks = ndimage.gaussian_filter(rng.standard_normal((S, S)).astype(np.float32), (2, 2))
    curl = ndimage.map_coordinates(noise(rng, 25), [YY + 40 * np.sin(ang * 2), XX + 40 * np.cos(ang * 2)],
                                   order=1, mode='reflect')
    wisps = ndimage.gaussian_filter(smoke, 16) * (0.35 + 0.9 * curl) + streaks * 0.02 * smoke
    e.light(np.clip(wisps, 0, 1) * 1.0 * (1 - body * 0.7), GOLD * 0.9)
    # Droplets of gel, drifting off.
    for _ in range(9):
        a, r = rng.uniform(0, 2 * np.pi), rng.uniform(0.28, 0.42) * S
        x, y, dr = C + math.cos(a) * r, C + math.sin(a) * r, rng.uniform(0.008, 0.02) * S
        drop = ellipse(x, y, dr, dr)
        e.paint(drop * 0.8, GOLD * 0.7)
        e.light(glow(drop, dr, 1.0), GOLD)
    return bg, e


SCENES = [
    # Name, scene, and a seed of its own, so changing one scene never
    # changes another.
    ('The triforce', triforce, 7),
    ('A gateway', gateway, 14),
    ('Hell', hell, 21),
    ('The Tern', tern, 28),
    ('The Gor', gor, 63),
    ('The Ál', al, 42),
    ('The Bhrun', bhrun, 49),
    ('The Unfortunates', unfortunates, 56),
    ('The Hellborn', hellborn, 35),
    ('A demon', demon, 70),
    ('The Havi', havi, 77),
]


def to_image(img, mode='RGB'):
    img = 1 - np.exp(-np.clip(img, 0, None) * 1.35)  # soft tonemap
    return Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), mode)


def launcher_mask(size):
    """A rounded square, the way most launchers show an icon."""
    m = Image.new('L', (size * 4, size * 4), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size * 4 - 1, size * 4 - 1], radius=size * 4 * 0.22,
                                        fill=255)
    return m.resize((size, size), Image.LANCZOS)


def contact_sheet(icons):
    tile, gap, label = 240, 40, 34
    cols = 6
    rows = math.ceil(len(icons) / cols)
    sheet = Image.new('RGB', (cols * tile + (cols + 1) * gap, rows * (tile + label) + (rows + 1) * gap),
                      (8, 10, 16))
    try:
        font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 20)
    except OSError:
        font = ImageFont.load_default()
    d = ImageDraw.Draw(sheet)
    mask = launcher_mask(tile)
    for i, (name, icon) in enumerate(icons):
        x = gap + (i % cols) * (tile + gap)
        y = gap + (i // cols) * (tile + label + gap)
        sheet.paste(icon.resize((tile, tile), Image.LANCZOS), (x, y), mask)
        text = f'{i + 1}. {name}'
        w = d.textlength(text, font=font)
        d.text((x + (tile - w) / 2, y + tile + 8), text, fill=(200, 210, 225), font=font)
    sheet.save(os.path.join(CONCEPTS, 'icon_mockups_ai_generated.png'), optimize=True)


def app_icon(bg, emblem):
    """The full icon, and Android's adaptive layers: the background alone,
    and the emblem, shrunk to stay clear of the launcher's mask."""
    os.makedirs(ICON_DIR, exist_ok=True)
    to_image(emblem.over(bg)).save(os.path.join(ICON_DIR, 'app_icon_ai_generated.png'))
    to_image(bg).save(os.path.join(ICON_DIR, 'app_icon_background_ai_generated.png'))
    colour, alpha = emblem.layer()
    rgb = to_image(colour)
    a = Image.fromarray((alpha * 255).astype(np.uint8), 'L')
    fg = rgb.copy()
    fg.putalpha(a)
    small = int(S * 0.85)
    canvas = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    canvas.paste(fg.resize((small, small), Image.LANCZOS), ((S - small) // 2, (S - small) // 2))
    canvas.save(os.path.join(ICON_DIR, 'app_icon_foreground_ai_generated.png'))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--icon', type=int, default=1, help='which mockup becomes the app icon')
    args = parser.parse_args()
    os.makedirs(CONCEPTS, exist_ok=True)
    icons = []
    for n, (name, scene, seed) in enumerate(SCENES, start=1):
        bg, emblem = scene(np.random.default_rng(seed))
        icon = to_image(emblem.over(bg))
        icon.save(os.path.join(CONCEPTS, f'icon_{n}_ai_generated.png'), optimize=True)
        icons.append((name, icon))
        if n == args.icon:
            app_icon(bg, emblem)
        print(f'{n}. {name}')
    contact_sheet(icons)


if __name__ == '__main__':
    main()
