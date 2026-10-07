"""Four procedural concept mockups of a gateway.

Proof-of-concept placeholders, not final art. Writes
concept_art/gate_<n>_ai_generated.png (see the naming rule in CLAUDE.md).

    python3 tool/generate_gate_concepts.py

From how FTL works.md: gates are ancient circular relics that exist at the
same point in both dimensions. Approaching one fades a ship into the other
dimension. In Hell, each gate's energy barrier stretches as a pipe to the
gate it is paired with. Traffic is split into thirds: one lower third in,
the other out. The top third is split again by a flipped divider: the part
nearest the middle is for emergencies, the top left and right are drone
lanes. Up to four gates share a star, about 1 AU apart.

Needs numpy, scipy and Pillow.
"""

import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

sys.path.insert(0, os.path.dirname(__file__))
from generate_mourner_concepts import (  # noqa: E402
    AMBER, BRANDY, GOLD, HOT, VOID, H, W, XX, YY, add, bezier, finish, glow,
    motes, murk, noise, over, smooth, strokes)

ICE = np.array([0.55, 0.85, 1.0])
CYAN = np.array([0.3, 0.9, 1.0])
STEEL = np.array([0.42, 0.46, 0.52])
SPACE = np.array([0.008, 0.012, 0.025])
NEBULA = np.array([0.18, 0.12, 0.35])


def space(rng, nebula=NEBULA, stars=1800):
    """The vacuum: black, a little nebula, a lot of stars."""
    f = noise(rng, 140) * 0.6 + noise(rng, 40) * 0.4
    img = SPACE + (smooth(0.45, 0.9, f) * 0.6)[..., None] * nebula
    layer = np.zeros((H, W), np.float32)
    xs, ys = rng.integers(0, W, stars), rng.integers(0, H, stars)
    layer[ys, xs] = rng.uniform(0.2, 1.0, stars) ** 3
    img = img + ndimage.gaussian_filter(layer, 0.7)[..., None] * 6 * np.array([0.9, 0.95, 1.0])
    bright = np.zeros((H, W), np.float32)
    for _ in range(25):
        bright[rng.integers(0, H), rng.integers(0, W)] = 1
    return add(img, glow(bright, 2.5, 25), ICE)


def ellipse_pt(cx, cy, r, aspect, rot, angle):
    """A point at [angle] on a circle of radius r, seen tilted."""
    x, y = r * math.cos(angle), r * math.sin(angle) * aspect
    c, s = math.cos(rot), math.sin(rot)
    return (cx + x * c - y * s, cy + x * s + y * c)


def ring(img, cx, cy, r, width, aspect=1.0, rot=0.0, light=(-0.7, -0.5),
         colour=STEEL, glow_colour=CYAN, segments=27):
    """The gate itself: a thick segmented ring, lit from one side, with
    three glowing anchors where the traffic dividers meet it."""
    c, s = math.cos(-rot), math.sin(-rot)
    dx, dy = XX - cx, YY - cy
    u = dx * c - dy * s
    v = (dx * s + dy * c) / aspect
    rr = np.hypot(u, v)
    ang = np.arctan2(v, u)
    band = smooth(r - width, r - width + 3, rr) * (1 - smooth(r - 3, r, rr))
    across = np.clip((rr - (r - width)) / width, 0, 1)
    bevel = 0.55 + 0.45 * np.sin(across * math.pi)
    lx, ly = light
    facing = 0.35 + 0.65 * np.clip(np.cos(ang) * lx + np.sin(ang) * ly + 0.5, 0, 1.2)
    seams = np.abs(np.sin(ang * segments / 2)) > 0.06
    shade = band * bevel * facing * (0.75 + 0.25 * seams)
    img = over(img, band, colour[None, None] * shade[..., None] / np.maximum(band, 1e-3)[..., None])
    # A thin line of light along the inner edge.
    inner = np.exp(-((rr - (r - width)) / 2.2) ** 2)
    img = add(img, inner * 0.8, glow_colour)
    img = add(img, glow(inner, 10, 0.8), glow_colour * 0.5)
    for a in (math.pi / 2, math.pi / 2 + 2 * math.pi / 3, math.pi / 2 + 4 * math.pi / 3):
        x, y = ellipse_pt(cx, cy, r - width / 2, aspect, rot, a)
        dot = np.exp(-(((XX - x) ** 2 + (YY - y) ** 2) / (width * 0.35) ** 2))
        img = add(img, dot * 2.0 + glow(dot > 0.3, width * 0.6, 1.0), glow_colour)
    return img


def lane_lines(cx, cy, r, aspect=1.0, rot=0.0):
    """The traffic dividers, in screen space: a Y splits the gate into
    thirds, and a flipped Y splits the top third."""
    centre = (cx, cy)
    lines = []
    dividers = (math.pi / 2, math.pi / 2 + 2 * math.pi / 3, math.pi / 2 + 4 * math.pi / 3)
    for a in dividers:
        lines.append([centre, ellipse_pt(cx, cy, r, aspect, rot, a)])
    top = ellipse_pt(cx, cy, r, aspect, rot, -math.pi / 2)
    for a in dividers[1:]:
        lines.append([ellipse_pt(cx, cy, r * 0.5, aspect, rot, a), top])
    return lines


def membrane(cx, cy, r, aspect=1.0, rot=0.0, rng=None):
    """Where the gate's plane is: a faint rippling disc."""
    c, s = math.cos(-rot), math.sin(-rot)
    dx, dy = XX - cx, YY - cy
    u = dx * c - dy * s
    v = (dx * s + dy * c) / aspect
    rr = np.hypot(u, v) / r
    inside = 1 - smooth(0.97, 1.0, rr)
    ripples = 0.5 + 0.5 * np.sin(rr * 40 + (noise(rng, 30) * 8 if rng is not None else 0))
    return inside, inside * (0.25 + 0.75 * rr ** 3) * (0.6 + 0.4 * ripples)


def traffic(rng, path_fn, n, size, fade_at=None):
    """Ships as points of light along paths, fading out as they reach the
    gate's plane."""
    layer = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(layer)
    for _ in range(n):
        pts = path_fn(rng)
        t = rng.uniform(0.05, 1.0)
        i = int(t * (len(pts) - 1))
        x, y = pts[i]
        fade = 1.0 if fade_at is None else max(0.0, min(1.0, (1 - t) / (1 - fade_at)))
        tail = pts[max(0, i - 6):i + 1]
        if len(tail) > 1:
            d.line(tail, fill=int(90 * fade), width=max(1, int(size * 0.6)))
        d.ellipse([x - size, y - size, x + size, y + size], fill=int(255 * fade))
    return ndimage.gaussian_filter(np.asarray(layer, np.float32) / 255, 1.0)


# 1. Approach ---------------------------------------------------------------------
# Three-quarter view of a gate in orbit near its star, traffic streaming
# into the lower left third and out of the lower right, drones in the top
# corners, and the emergency lane empty.
def approach():
    rng = np.random.default_rng(101)
    img = space(rng)
    star = np.exp(-(((XX - 170) ** 2 + (YY - 260) ** 2) / 70 ** 2))
    img = add(img, star * 3 + glow(star > 0.2, 160, 2.5), np.array([1.0, 0.9, 0.75]))
    img = add(img, glow(star > 0.2, 420, 1.2), np.array([0.6, 0.45, 0.3]))
    cx, cy, r, aspect, rot = 930, 520, 360, 0.82, -0.18
    inside, mem = membrane(cx, cy, r - 40, aspect, rot, rng)
    img = add(img, mem * 0.35, ICE * 0.6)
    lanes = strokes([(line, 1.0, 0.8) for line in lane_lines(cx, cy, r - 40, aspect, rot)], 3, 1.5)
    img = add(img, lanes * 0.9 + glow(lanes, 8, 1.2), CYAN * 0.7)

    def inbound(rng):
        a = math.radians(rng.uniform(100, 200))
        end = ellipse_pt(cx, cy, (r - 60) * rng.uniform(0.3, 0.9), aspect, rot, a)
        start = (end[0] - rng.uniform(500, 900), end[1] + rng.uniform(150, 450))
        return bezier(start, (start[0] + 300, start[1] - 50), (end[0] - 150, end[1] + 40), end, 40)

    def outbound(rng):
        a = math.radians(rng.uniform(-20, 80))
        start = ellipse_pt(cx, cy, (r - 60) * rng.uniform(0.3, 0.9), aspect, rot, a)
        end = (start[0] + rng.uniform(300, 700), start[1] + rng.uniform(200, 500))
        return bezier(start, (start[0] + 150, start[1] + 40), (end[0] - 200, end[1] - 50), end, 40)

    def drones(rng):
        side = rng.choice([-1, 1])
        a = math.radians(-90 + side * rng.uniform(25, 55))
        end = ellipse_pt(cx, cy, (r - 60) * rng.uniform(0.6, 0.95), aspect, rot, a)
        start = (end[0] + side * rng.uniform(300, 600), end[1] - rng.uniform(200, 400))
        return bezier(start, start, end, end, 30)

    ships = traffic(rng, inbound, 26, 4, fade_at=0.55) + traffic(rng, outbound, 20, 4)
    ships += traffic(rng, drones, 40, 1.6) * 0.8
    img = add(img, ships * 2.0 + glow(ships, 5, 2.0), np.array([1.0, 0.95, 0.85]))
    img = ring(img, cx, cy, r, 42, aspect, rot)
    # Another gate of the same star, a speck at about 1 AU.
    far = np.exp(-(((XX - 330) ** 2 + (YY - 780) ** 2) / 4 ** 2))
    img = add(img, far * 2 + glow(far > 0.3, 8, 3), CYAN)
    finish(img, 'gate_1', rng, grain=0.015)


# 2. Fading between --------------------------------------------------------------
# Face on, as the bridge would see it. Through the ring is Hell; around it
# is the vacuum. A ship crossing the plane is half in each, dissolving
# into amber where it has gone through.
def fading():
    rng = np.random.default_rng(202)
    img = space(rng, stars=1400)
    cx, cy, r = 768, 512, 400
    hell = murk(rng, VOID + 0.02, BRANDY * 0.9, 1.3)
    hell = motes(hell, rng, 700, AMBER * 0.8)
    inside, mem = membrane(cx, cy, r - 44, 1.0, 0.0, rng)
    img = over(img, inside, hell)
    img = add(img, mem * 0.25, AMBER * 0.5)
    lanes = strokes([(line, 1.0, 0.5) for line in lane_lines(cx, cy, r - 44)], 2.5, 1.5)
    img = add(img, lanes * 0.7 + glow(lanes, 8, 1.0), GOLD * 0.6)
    img = ring(img, cx, cy, r, 44, light=(-0.6, -0.6))
    # A ship, nose first through the lower left third.
    ship = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(ship)
    sx, sy = 600, 640
    hull = [(sx + 150, sy - 70), (sx - 130, sy - 40), (sx - 180, sy + 20),
            (sx - 120, sy + 60), (sx + 150, sy - 50)]
    d.polygon(hull, fill=255)
    d.polygon([(sx - 60, sy - 40), (sx - 150, sy - 120), (sx - 100, sy - 45)], fill=255)
    d.polygon([(sx - 60, sy + 40), (sx - 160, sy + 120), (sx - 110, sy + 50)], fill=255)
    mask = ndimage.gaussian_filter(np.asarray(ship, np.float32) / 255, 1)
    dissolve = smooth(sx - 40, sx + 160, XX) * (0.55 + 0.45 * noise(rng, 6))
    body = mask * (1 - smooth(0.55, 0.9, dissolve))
    img = over(img, body, STEEL * 0.35)
    edge = np.clip(mask - ndimage.gaussian_filter(mask, 4), 0, 1)
    img = add(img, edge * (1 - dissolve) * 1.4, ICE * 0.8)
    sparks = mask * smooth(0.45, 0.7, dissolve) * (1 - smooth(0.85, 1.0, dissolve))
    img = add(img, sparks * 2 + glow(sparks, 10, 2), GOLD)
    engine = np.exp(-(((XX - (sx - 175)) ** 2 + (YY - (sy + 20)) ** 2) / 12 ** 2))
    img = add(img, engine * 3 + glow(engine > 0.3, 20, 2), ICE)
    finish(img, 'gate_2', rng, grain=0.018)


# 3. The pipe ---------------------------------------------------------------------
# From the Hell side: the gate in the amber murk, and its barrier running
# away as a glowing pipe to the gate it is paired with. Partway along,
# something made only of teeth is chewing on it.
def pipe():
    rng = np.random.default_rng(303)
    img = murk(rng, VOID + 0.015, BRANDY * 0.75, 1.2)
    img = motes(img, rng, 1400, AMBER * 0.7)
    cx, cy, r, aspect, rot = 330, 560, 250, 0.9, 0.0
    vx, vy = 1350, 420
    # The pipe: a tube from the gate's rim to a vanishing point.
    top0 = ellipse_pt(cx, cy, r - 30, aspect, rot, -math.pi / 2)
    bot0 = ellipse_pt(cx, cy, r - 30, aspect, rot, math.pi / 2)
    tube = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(tube)
    d.polygon([top0, (vx, vy - 8), (vx, vy + 8), bot0], fill=255)
    body = ndimage.gaussian_filter(np.asarray(tube, np.float32) / 255, 3)
    opening, _ = membrane(cx, cy, r - 30, aspect, rot)
    body *= 1 - opening
    img = add(img, body * 0.18, ICE * 0.6)
    walls = strokes([(bezier(top0, top0, (vx, vy - 8), (vx, vy - 8), 2), 1.0, 0.9),
                     (bezier(bot0, bot0, (vx, vy + 8), (vx, vy + 8), 2), 1.0, 0.9)], 4, 2)
    for k in range(1, 14):
        t = 1 - 0.82 ** k
        a = (top0[0] + (vx - top0[0]) * t, top0[1] + (vy - 8 - top0[1]) * t)
        b = (bot0[0] + (vx - bot0[0]) * t, bot0[1] + (vy + 8 - bot0[1]) * t)
        h = (b[1] - a[1]) / 2
        bands = Image.new('L', (W, H), 0)
        ImageDraw.Draw(bands).ellipse([a[0] - h * 0.25, a[1], a[0] + h * 0.25, b[1]],
                                      outline=int(120 * (1 - t)), width=2)
        walls = walls + np.asarray(bands, np.float32) / 255
    img = add(img, walls * 0.9 + glow(walls, 12, 1.4), ICE * 0.8)
    paired = np.exp(-(((XX - vx) ** 2 + (YY - vy) ** 2) / 10 ** 2))
    img = add(img, paired * 2 + glow(paired > 0.3, 25, 3), ICE)
    # The chewer: teeth with no mouth, biting the barrier's top wall.
    t = 0.38
    bx = top0[0] + (vx - top0[0]) * t
    by = top0[1] + (vy - 8 - top0[1]) * t
    teeth = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(teeth)
    for k in range(34):
        a = rng.uniform(0, math.pi)
        dist = rng.uniform(30, 150)
        x, y = bx + math.cos(a) * dist * 1.4, by - math.sin(a) * dist
        point = math.atan2(by - y, bx - x)
        length = rng.uniform(28, 60)
        tip = (x + math.cos(point) * length, y + math.sin(point) * length)
        side = (math.cos(point + math.pi / 2) * length * 0.25,
                math.sin(point + math.pi / 2) * length * 0.25)
        d.polygon([(x + side[0], y + side[1]), tip, (x - side[0], y - side[1])], fill=255)
    tm = ndimage.gaussian_filter(np.asarray(teeth, np.float32) / 255, 1)
    img = over(img, tm, np.array([0.85, 0.82, 0.75]))
    img = add(img, np.clip(tm - ndimage.gaussian_filter(tm, 3), 0, 1), HOT * 0.5)
    crack = np.exp(-(((XX - bx) ** 2) / 40 ** 2 + ((YY - by - 10) ** 2) / 14 ** 2))
    img = add(img, crack * 1.6 + glow(crack > 0.3, 25, 2.0), ICE)
    img = ring(img, cx, cy, r, 34, aspect, rot, light=(0.7, -0.4),
               colour=np.array([0.35, 0.3, 0.28]), glow_colour=ICE)
    finish(img, 'gate_3', rng, grain=0.02)


# 4. Schematic ----------------------------------------------------------------------
# A Tern-style technical plate: the standard traffic division, face on,
# and four gates sharing a star at 1 AU.
def schematic():
    rng = np.random.default_rng(404)
    paper = np.array([0.03, 0.08, 0.16])
    img = np.zeros((H, W, 3), np.float32) + paper
    img = add(img, noise(rng, 2) * 0.03, CYAN)
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    grid = (60, 140, 190, 90)
    for x in range(0, W, 32):
        d.line([(x, 0), (x, H)], fill=grid, width=1)
    for y in range(0, H, 32):
        d.line([(0, y), (W, y)], fill=grid, width=1)
    ink = (200, 240, 255, 255)
    soft = (120, 200, 230, 255)
    try:
        font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf', 22)
        small = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf', 16)
        title = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf', 30)
    except OSError:
        font = small = title = ImageFont.load_default()
    cx, cy, r = 520, 530, 360
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=ink, width=4)
    d.ellipse([cx - r + 34, cy - r + 34, cx + r - 34, cy + r - 34], outline=soft, width=2)
    for k in range(27):
        a = k * 2 * math.pi / 27
        d.line([(cx + (r - 34) * math.cos(a), cy + (r - 34) * math.sin(a)),
                (cx + r * math.cos(a), cy + r * math.sin(a))], fill=soft, width=1)
    for line in lane_lines(cx, cy, r - 34):
        d.line(line, fill=ink, width=3)
    labels = [
        ((cx - 170, cy + 120), 'IN'),
        ((cx + 170, cy + 120), 'OUT'),
        ((cx, cy - 150), 'EMERGENCY'),
        ((cx - 205, cy - 150), 'DRONES\nIN'),
        ((cx + 205, cy - 150), 'DRONES\nOUT'),
    ]
    for (x, y), text in labels:
        d.multiline_text((x, y), text, fill=ink, font=font, anchor='mm', align='center')
    for (x, y), direction in (((cx - 170, cy + 175), 1), ((cx + 170, cy + 175), -1)):
        d.text((x, y), 'into the page' if direction > 0 else 'out of the page',
               fill=soft, font=small, anchor='mm')
    d.text((cx, cy + r + 40), 'STANDARD TRAFFIC DIVISION, FACE ON', fill=ink, font=font,
           anchor='mm')
    # Inset: four gates around one star, about 1 AU out.
    ix, iy, ir = 1210, 360, 170
    d.rectangle([ix - 230, iy - 230, ix + 230, iy + 260], outline=soft, width=2)
    d.ellipse([ix - ir, iy - ir, ix + ir, iy + ir], outline=soft, width=1)
    d.ellipse([ix - 16, iy - 16, ix + 16, iy + 16], fill=(255, 230, 170, 255))
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        gx, gy = ix + ir * math.cos(a), iy + ir * math.sin(a)
        d.ellipse([gx - 12, gy - 12, gx + 12, gy + 12], outline=ink, width=3)
    d.line([(ix, iy), (ix + ir, iy)], fill=soft, width=1)
    d.text((ix + ir / 2, iy - 14), '~1 AU', fill=soft, font=small, anchor='mm')
    d.text((ix, iy + 220), 'FOUR GATES, ONE STAR', fill=ink, font=small, anchor='mm')
    d.text((ix, iy + 242), 'closer and they overlap in Hell', fill=soft, font=small,
           anchor='mm')
    notes = [
        'Gates exist at one point in both dimensions.',
        'Approach fades a ship into the other.',
        'All traffic at cruising speed. Drones may',
        'exceed it in their own lanes.',
    ]
    for i, line in enumerate(notes):
        d.text((990, 700 + i * 24), line, fill=soft, font=small)
    d.text((40, 36), 'GATEWAY  ·  GENERAL ARRANGEMENT', fill=ink, font=title)
    d.text((40, 76), 'Havi pattern. Maintained by the Tern. Do not ask the Unfortunates.',
           fill=soft, font=small)
    art = np.asarray(layer, np.float32) / 255
    img = over(img, art[..., 3], art[..., :3])
    lines = art[..., 3] * (art[..., :3].mean(axis=2) > 0.6)
    img = add(img, glow(lines, 3, 0.35), CYAN * 0.6)
    finish(img, 'gate_4', rng, grain=0.012)


if __name__ == '__main__':
    os.makedirs(os.path.join(os.path.dirname(__file__), '..', 'concept_art'), exist_ok=True)
    for draw in (approach, fading, pipe, schematic):
        draw()
    print('4 gate mockups in concept_art')
