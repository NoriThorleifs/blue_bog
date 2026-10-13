"""Shared drawing kit for the event concept generators (generate_colony_,
generate_workshop_, generate_lane_ and generate_hell_concepts.py): shapes
drawn smooth, rim light, humans, ships, screens and a few props.

Every picture is W x H (1536 x 1024), lit and composited as floating-point
RGB arrays, then tone-mapped and saved by finish(). Needs numpy, scipy and
Pillow.
"""

import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

sys.path.insert(0, os.path.dirname(__file__))
from generate_gate_concepts import ICE, STEEL, membrane, ring, space  # noqa: E402,F401
from generate_mourner_concepts import (  # noqa: E402,F401
    AMBER, BRANDY, CRIMSON, GOLD, HOT, VOID, H, W, XX, YY, add, bezier,
    black_hole, finish, glow, motes, murk, noise, over, planet, smooth)

ROOT = os.path.join(os.path.dirname(__file__), '..')
CONCEPTS = os.path.join(ROOT, 'concept_art')

CYAN = np.array([0.35, 0.95, 1.0])
HAZARD = np.array([1.0, 0.72, 0.15])
RED = np.array([1.0, 0.2, 0.15])
SILHOUETTE = np.array([0.012, 0.014, 0.02])
DARK_STEEL = np.array([0.045, 0.048, 0.055])
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'

SS = 2  # supersampling for shapes


class Layer:
    """Shapes drawn at twice the size and shrunk, for smooth edges, as an
    intensity from 0 to 1."""

    def __init__(self):
        self.im = Image.new('L', (W * SS, H * SS), 0)
        self.d = ImageDraw.Draw(self.im)

    @staticmethod
    def _p(pts):
        return [(x * SS, y * SS) for x, y in pts]

    def poly(self, pts, a=1.0):
        self.d.polygon(self._p(pts), fill=int(255 * a))

    def ellipse(self, cx, cy, rx, ry, a=1.0):
        self.d.ellipse([(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS],
                       fill=int(255 * a))

    def ring(self, cx, cy, rx, ry, width, a=1.0):
        self.d.ellipse([(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS],
                       outline=int(255 * a), width=max(1, int(width * SS)))

    def line(self, pts, w, a=1.0):
        self.d.line(self._p(pts), fill=int(255 * a), width=max(1, int(w * SS)), joint='curve')
        # Round the ends, which PIL leaves square.
        for x, y in (pts[0], pts[-1]):
            self.ellipse(x, y, w / 2, w / 2, a)

    def rect(self, x0, y0, x1, y1, a=1.0):
        self.d.rectangle([x0 * SS, y0 * SS, x1 * SS, y1 * SS], fill=int(255 * a))

    def text(self, x, y, s, size, a=1.0, anchor='mm'):
        font = ImageFont.truetype(FONT, max(1, int(size * SS)))
        self.d.text((x * SS, y * SS), s, fill=int(255 * a), font=font, anchor=anchor)

    def array(self):
        return np.asarray(self.im.resize((W, H), Image.LANCZOS), np.float32) / 255


def rim(mask, toward, k=3):
    """The edge of [mask] that faces a light [toward] (x, y): the pixels whose
    neighbour toward the light is outside the shape."""
    lx, ly = toward
    shifted = np.roll(mask, -round(ly * k), axis=0)
    shifted = np.roll(shifted, -round(lx * k), axis=1)
    return np.clip(mask - shifted, 0, 1)


def dot(img, x, y, r, colour, gain=2.0, halo=None):
    """A point of light: a running light, a lamp, an eye."""
    d = np.exp(-(((XX - x) ** 2 + (YY - y) ** 2) / r ** 2))
    return add(img, d * gain + glow(d > 0.3, halo or r * 3, gain * 0.8), colour)


def silhouette(img, mask, toward, colour=SILHOUETTE, rim_colour=ICE, rim_gain=0.8, k=3):
    """[mask] as a dark shape with a lit edge facing [toward]."""
    img = over(img, mask, colour)
    return add(img, rim(mask, toward, k) * rim_gain, rim_colour)


def solid(img, mask, base, toward, rim_colour=ICE, rim_gain=0.9, k=3, shade=0.5):
    """[mask] as a lit solid: [base] colour, brighter on the side toward the
    light, with a lit edge. The shading runs across the whole picture, which
    is plenty for one object near the middle."""
    lx, ly = toward
    n = math.hypot(lx, ly) or 1
    across = ((XX - W / 2) * lx + (YY - H / 2) * ly) / (n * W * 0.5)
    lit = (1 - shade) + shade * smooth(-1, 1, across)
    img = over(img, mask, base * 0.35)
    img = add(img, mask * lit * 0.65, base)
    return add(img, rim(mask, toward, k) * rim_gain, rim_colour)


def beam(apex, spread, length, angle, blur=20):
    """A soft cone of light from [apex]."""
    L = Layer()
    ax, ay = apex
    a0, a1 = angle - spread, angle + spread
    L.poly([(ax, ay), (ax + math.cos(a0) * length, ay + math.sin(a0) * length),
            (ax + math.cos(a1) * length, ay + math.sin(a1) * length)])
    falloff = 1 - smooth(0, length, np.hypot(XX - ax, YY - ay))
    return ndimage.gaussian_filter(L.array(), blur) * falloff


def spark(img, rng, x, y, size=1.0, colour=HOT):
    """A cutting torch: a white-hot point, its glow, and sparks flying off."""
    point = np.exp(-(((XX - x) ** 2 + (YY - y) ** 2) / (2.2 * size) ** 2))
    L = Layer()
    for _ in range(int(10 * size) + 4):
        a = rng.uniform(0, 2 * math.pi)
        r0, r1 = rng.uniform(2, 6) * size, rng.uniform(10, 34) * size
        L.line([(x + math.cos(a) * r0, y + math.sin(a) * r0),
                (x + math.cos(a) * r1, y + math.sin(a) * r1)], 0.9, rng.uniform(0.3, 0.9))
    img = add(img, point * 3 + glow(point > 0.2, 9 * size, 5), colour)
    return add(img, L.array() * 1.4, AMBER)


# People -------------------------------------------------------------------------------

def human(L, x, y, h, *, suit=False, rifle=False, bag=False, helmet=False,
          walk=0.0, wave=0, child=False, facing=1, sign=None, hands_up=False):
    """A human from behind, the front or the side, feet at (x, y), [h] tall.

    [suit] is a vacuum suit, bulky with a bubble helmet and a life-support
    pack; [helmet] is a Neo Terran soldier's, flared at the back where it
    locks. [walk] is the stride, from 0 (standing) to 1; [wave] raises one
    arm (1) or both (2); [facing] is which way a walker goes. [sign] holds up
    a placard of that height on a pole."""
    head = h * (0.115 if child else 0.092 if suit else 0.08)
    hy = y - h + head
    sw = h * (0.155 if suit else 0.135)  # half the shoulders
    ww = h * (0.11 if suit else 0.09)  # half the waist
    sy, wy = y - h * 0.8, y - h * 0.47
    if child:
        sy, wy = y - h * 0.76, y - h * 0.45
    L.ellipse(x, hy, head, head * 1.04)
    L.rect(x - head * 0.45, hy, x + head * 0.45, sy + h * 0.02)
    L.poly([(x - sw, sy + h * 0.02), (x - sw * 0.85, sy - h * 0.015), (x + sw * 0.85, sy - h * 0.015),
            (x + sw, sy + h * 0.02), (x + ww, wy), (x - ww, wy)])
    L.poly([(x - ww, wy - 1), (x + ww, wy - 1), (x + ww * 1.08, wy + h * 0.09), (x - ww * 1.08, wy + h * 0.09)])
    stride = h * 0.15 * walk
    leg = h * (0.1 if suit else 0.08)
    hip = wy + h * 0.06
    L.line([(x - ww * 0.45, hip), (x - ww * 0.3 - stride * facing, y - leg / 2)], leg)
    L.line([(x + ww * 0.45, hip), (x + ww * 0.3 + stride * 0.9 * facing, y - leg / 2)], leg)
    arm = h * (0.075 if suit else 0.058)
    for side in (-1, 1):
        sx = x + side * (sw - arm * 0.4)
        if wave == 2 or (wave == 1 and side == 1) or sign is not None:
            L.line([(sx, sy + arm * 0.3), (sx + side * h * 0.12, sy - h * 0.2),
                    (sx + side * h * 0.16, sy - h * 0.34)], arm)
        elif hands_up:
            L.line([(sx, sy + arm * 0.3), (sx + side * h * 0.05, hy - head * 0.2)], arm)
        else:
            swing = -side * stride * 0.6 * facing
            L.line([(sx, sy + arm * 0.3), (sx + side * h * 0.055 + swing, wy + h * 0.07)], arm)
    if suit:
        L.ellipse(x, hy + head * 0.05, head * 1.08, head * 1.08)  # the bubble
        L.rect(x - sw * 0.62, sy - h * 0.02, x + sw * 0.62, wy - h * 0.06)  # the pack
        L.ellipse(x, sy - h * 0.02, sw * 0.62, h * 0.035)
    if helmet:
        L.ellipse(x, hy - head * 0.15, head * 1.25, head * 1.05)
        # The neck guard flares out at the back, where it locks.
        L.poly([(x - facing * head * 0.2, hy), (x - facing * head * 1.55, hy + head * 1.15),
                (x - facing * head * 0.4, hy + head * 1.3)])
    if rifle:
        # Slung across the back, sticking out past the shoulders.
        L.line([(x - sw * 1.35, sy - h * 0.1), (x + sw * 1.45, wy + h * 0.03)], h * 0.032)
        L.line([(x - sw * 1.35, sy - h * 0.1), (x - sw * 1.6, sy - h * 0.16)], h * 0.02)
    if bag:
        bx = x - facing * (sw + h * 0.03)
        L.line([(x + facing * sw * 0.5, sy), (bx, wy - h * 0.05)], h * 0.018)
        L.ellipse(bx, wy, h * 0.09, h * 0.13)
    if sign is not None:
        top = sy - h * 0.34
        L.line([(x, top), (x, sy - h * 0.1)], h * 0.025)
        L.rect(x - sign * 0.8, top - sign, x + sign * 0.8, top)
    return (x, hy)


def crouched(L, x, y, h):
    """A human sitting on the floor side on, facing right, back hunched,
    knees drawn up, hands over the ears: the brace position. [h] is how tall
    they sit; returns where the head is."""
    def at(u, v):
        return (x + u * h, y - v * h)
    L.ellipse(*at(0.02, 0.1), h * 0.16, h * 0.11)  # seat
    L.line([at(0.0, 0.12), at(0.06, 0.45), at(0.16, 0.66)], h * 0.2)  # hunched back
    L.line([at(0.05, 0.1), at(0.42, 0.42)], h * 0.15)  # thigh
    L.line([at(0.42, 0.42), at(0.5, 0.04)], h * 0.11)  # shin
    L.ellipse(*at(0.56, 0.03), h * 0.09, h * 0.04)  # foot
    head = at(0.26, 0.76)
    L.ellipse(*head, h * 0.11, h * 0.115)  # bowed head
    L.line([at(0.16, 0.62), at(0.3, 0.55), at(0.32, 0.74)], h * 0.075)  # arm up, hand to the ear
    return head


def crowd(L, rng, rows, **kw):
    """Rows of people: (feet y, height, step, left, right), back row first.
    Returns where each head is."""
    heads = []
    for y, h, step, left, right in rows:
        for x in np.arange(left, right, step):
            x = x + rng.uniform(-0.25, 0.25) * step
            heads.append(human(L, x, y + rng.uniform(-5, 5), h * rng.uniform(0.92, 1.06), **kw))
    return heads


# Places --------------------------------------------------------------------------------

def interior(rng, base=np.array([0.03, 0.038, 0.05]), light=np.array([0.06, 0.08, 0.1]),
             vx=W / 2, vy=H * 0.42, ribs=0.08):
    """A bay or corridor inside a ship, its ribs running off to (vx, vy)."""
    near = 1 - smooth(0, 900, np.hypot(XX - vx, (YY - vy) * 1.3))
    img = base + near[..., None] * light
    L = Layer()
    for k in range(-9, 10):
        L.line([(vx + k * 18, vy - 6), (vx + k * 260, -40)], 2.5, 0.5)
        L.line([(vx + k * 18, vy + 6), (vx + k * 300, H + 40)], 2, 0.35)
    return add(img, L.array() * ribs, STEEL)


def hell(rng, strength=1.0, motes_n=1200):
    """Hell's amber sea."""
    img = murk(rng, VOID + 0.012, BRANDY * 0.8, strength)
    return motes(img, rng, motes_n, AMBER * 0.6)


def window(img, x0, y0, x1, y1, beyond, frame=DARK_STEEL, mullions=0):
    """A window onto [beyond] (a whole picture), in a frame."""
    m = np.zeros((H, W), np.float32)
    m[y0:y1, x0:x1] = 1
    m = ndimage.gaussian_filter(m, 0.8)
    img = img * (1 - m[..., None]) + beyond * m[..., None]
    F = Layer()
    F.rect(x0 - 14, y0 - 14, x1 + 14, y0)
    F.rect(x0 - 14, y1, x1 + 14, y1 + 14)
    F.rect(x0 - 14, y0, x0, y1)
    F.rect(x1, y0, x1 + 14, y1)
    for k in range(1, mullions + 1):
        x = x0 + (x1 - x0) * k / (mullions + 1)
        F.rect(x - 5, y0, x + 5, y1)
    return over(img, F.array(), frame)


def screen(img, x0, y0, x1, y1, picture, tint=CYAN, caption=None, bar=np.array([0.5, 0.06, 0.05])):
    """A comm screen showing [picture] (a PIL image), fitted and cropped,
    with scanlines, a frame and a glow."""
    w, h = x1 - x0, y1 - y0
    pic = picture.convert('RGB')
    scale = max(w / pic.width, h / pic.height)
    pic = pic.resize((math.ceil(pic.width * scale), math.ceil(pic.height * scale)), Image.LANCZOS)
    left, top = (pic.width - w) // 2, (pic.height - h) // 2
    arr = np.asarray(pic.crop((left, top, left + w, top + h)), np.float32) / 255
    arr = arr ** 2.0  # back to linear light, roughly
    lines = 0.82 + 0.18 * (np.arange(h) % 4 < 2)[:, None, None]
    arr = arr * lines * 0.9 + tint * 0.03
    img = img.copy()
    img[y0:y1, x0:x1] = arr
    m = np.zeros((H, W), np.float32)
    m[y0:y1, x0:x1] = 1
    img = add(img, glow(m, 40, 0.35), tint * 0.5)
    F = Layer()
    F.rect(x0 - 10, y0 - 10, x1 + 10, y0)
    F.rect(x0 - 10, y1, x1 + 10, y1 + 10)
    F.rect(x0 - 10, y0, x0, y1)
    F.rect(x1, y0, x1 + 10, y1)
    img = over(img, F.array(), DARK_STEEL)
    if caption:
        strip = np.zeros((H, W), np.float32)
        strip[y0 + 14:y0 + 48, x0 + 16:x0 + 16 + 14 * len(caption) + 30] = 1
        img = over(img, strip * 0.75, bar)
        T = Layer()
        T.text(x0 + 30, y0 + 31, caption, 20, anchor='lm')
        img = add(img, T.array() * 0.9, HOT)
    return img


def concept(name):
    """A finished concept picture, from concept_art/."""
    return Image.open(os.path.join(CONCEPTS, f'{name}_ai_generated.png'))


def card_art(family):
    """A card's icon from assets/cards/, as (rgb, alpha) arrays."""
    im = Image.open(os.path.join(ROOT, 'assets', 'cards', f'{family}_ai_generated.png')).convert('RGBA')
    a = np.asarray(im, np.float32) / 255
    return a[..., :3], a[..., 3]


def paste(img, rgb, alpha, x, y, size, gain=1.0):
    """Puts an icon (rgb, alpha) [size] across with its centre at (x, y)."""
    h0, w0 = alpha.shape
    s = size / max(w0, h0)
    w1, h1 = max(1, int(w0 * s)), max(1, int(h0 * s))
    r = np.asarray(Image.fromarray((rgb * 255).astype(np.uint8)).resize((w1, h1), Image.LANCZOS),
                   np.float32) / 255
    a = np.asarray(Image.fromarray((alpha * 255).astype(np.uint8)).resize((w1, h1), Image.LANCZOS),
                   np.float32) / 255
    x0, y0 = int(x - w1 / 2), int(y - h1 / 2)
    img = img.copy()
    region = img[y0:y0 + h1, x0:x0 + w1]
    region[:] = region * (1 - a[..., None]) + (r ** 2.0) * gain * a[..., None]
    return img


# Ships ---------------------------------------------------------------------------------

SHIPS = {
    # Nose along +x, one unit long.
    'gunship': [(0.5, 0), (0.1, -0.12), (-0.3, -0.16), (-0.5, -0.3), (-0.42, -0.08), (-0.5, 0),
                (-0.42, 0.08), (-0.5, 0.3), (-0.3, 0.16), (0.1, 0.12)],
    'warship': [(0.5, 0), (0.3, -0.05), (0.2, -0.15), (0.1, -0.06), (-0.1, -0.08), (-0.2, -0.22),
                (-0.28, -0.08), (-0.5, -0.1), (-0.5, 0.1), (-0.28, 0.08), (-0.2, 0.22), (-0.1, 0.08),
                (0.1, 0.06), (0.2, 0.15), (0.3, 0.05)],
    'sleek': [(0.5, 0), (0.05, -0.09), (-0.4, -0.11), (-0.5, -0.05), (-0.5, 0.05), (-0.4, 0.11),
              (0.05, 0.09)],
    'heavy': [(0.5, -0.05), (0.35, -0.18), (-0.4, -0.2), (-0.5, -0.1), (-0.5, 0.1), (-0.4, 0.2),
              (0.35, 0.18), (0.5, 0.05)],
    'freighter': [(0.5, -0.04), (0.42, -0.07), (-0.5, -0.07), (-0.5, 0.07), (0.42, 0.07), (0.5, 0.04)],
}


def ship_points(kind, cx, cy, length, angle=0.0, squash=1.0):
    c, s = math.cos(angle), math.sin(angle)
    return [(cx + (x * c - y * squash * s) * length, cy + (x * s + y * squash * c) * length)
            for x, y in SHIPS[kind]]


def ship(L, kind, cx, cy, length, angle=0.0, squash=1.0):
    """A ship's outline of [kind] (see [SHIPS]) into [L]."""
    L.poly(ship_points(kind, cx, cy, length, angle, squash))


def along(cx, cy, length, angle, u, v=0.0):
    """A point on a ship: [u] along it and [v] across, in its lengths."""
    c, s = math.cos(angle), math.sin(angle)
    return (cx + (u * c - v * s) * length, cy + (u * s + v * c) * length)


def crate(L, x, y, w, h, tilt=0.0):
    c, s = math.cos(tilt), math.sin(tilt)
    pts = [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]
    L.poly([(x + px * c - py * s, y + px * s + py * c) for px, py in pts])


def rifle(L, x, y, length, angle=0.0):
    """A rifle lying at [angle], muzzle along it."""
    def p(u, v):
        return along(x, y, length, angle, u, v)
    L.poly([p(-0.5, -0.03), p(0.2, -0.03), p(0.2, 0.02), p(-0.5, 0.05)])  # stock and body
    L.poly([p(0.2, -0.015), p(0.5, -0.015), p(0.5, 0.01), p(0.2, 0.01)])  # barrel
    L.poly([p(-0.05, 0.02), p(0.02, 0.02), p(0.0, 0.14), p(-0.07, 0.14)])  # magazine
    L.poly([p(-0.25, 0.04), p(-0.18, 0.04), p(-0.21, 0.12), p(-0.27, 0.12)])  # grip


def missile(L, x, y, length, angle=0.0):
    """A missile pointing along [angle]: rounded nose, body, swept fins."""
    def p(u, v):
        return along(x, y, length, angle, u, v)
    arc = np.linspace(0, math.pi / 2, 8)
    top = [p(0.5 - 0.16 * (1 - math.cos(a)), -0.07 * math.sin(a)) for a in arc]
    bottom = [p(0.5 - 0.16 * (1 - math.cos(a)), 0.07 * math.sin(a)) for a in arc[::-1]]
    L.poly(top + [p(-0.46, -0.07), p(-0.46, 0.07)] + bottom)
    for side in (-1, 1):  # swept fins
        L.poly([p(-0.28, side * 0.06), p(-0.5, side * 0.17), p(-0.5, side * 0.06)])


def tooth(L, x, y, length, point):
    tip = (x + math.cos(point) * length, y + math.sin(point) * length)
    side = (math.cos(point + math.pi / 2) * length * 0.25, math.sin(point + math.pi / 2) * length * 0.25)
    L.poly([(x + side[0], y + side[1]), tip, (x - side[0], y - side[1])])


def clock(img, cx, cy, r, hour, minute, brass=GOLD, face=np.array([0.5, 0.42, 0.28])):
    """A brass clock face showing [hour]:[minute]."""
    d = np.hypot(XX - cx, YY - cy)
    img = over(img, smooth(r, r - 2, d), face * 0.5)
    img = add(img, np.exp(-((d - r) / max(1.5, r * 0.05)) ** 2) * 1.2, brass)
    T = Layer()
    for k in range(12):
        a = k / 12 * 2 * math.pi
        T.line([(cx + math.sin(a) * r * 0.78, cy - math.cos(a) * r * 0.78),
                (cx + math.sin(a) * r * 0.9, cy - math.cos(a) * r * 0.9)], max(1, r * 0.04))
    ha = (hour % 12 + minute / 60) / 12 * 2 * math.pi
    ma = minute / 60 * 2 * math.pi
    T.line([(cx, cy), (cx + math.sin(ha) * r * 0.5, cy - math.cos(ha) * r * 0.5)], max(1.5, r * 0.07))
    T.line([(cx, cy), (cx + math.sin(ma) * r * 0.75, cy - math.cos(ma) * r * 0.75)], max(1, r * 0.045))
    return over(img, T.array(), np.array([0.05, 0.035, 0.02]))


def elephant(L, x, y, s):
    """The House of the Elephant's mark: an elephant, side on, [s] tall."""
    L.ellipse(x, y, s * 0.55, s * 0.36)  # body
    L.ellipse(x + s * 0.48, y - s * 0.18, s * 0.26, s * 0.24)  # head
    L.ellipse(x + s * 0.38, y - s * 0.12, s * 0.16, s * 0.22, 0)  # ear, cut out
    L.line(bezier((x + s * 0.68, y - s * 0.12), (x + s * 0.8, y + s * 0.05), (x + s * 0.7, y + s * 0.3),
                  (x + s * 0.82, y + s * 0.42), 20), s * 0.09)  # trunk
    for dx in (-0.38, -0.15, 0.12, 0.32):
        L.rect(x + dx * s - s * 0.07, y + s * 0.1, x + dx * s + s * 0.07, y + s * 0.55)


def scene_main(scenes, what):
    """Runs the scenes named on the command line, or all of them."""
    os.makedirs(CONCEPTS, exist_ok=True)
    names = sys.argv[1:] or list(scenes)
    for name in names:
        scenes[name]()
        print(name)
    print(f'{len(names)} {what} in concept_art')
