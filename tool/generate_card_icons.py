"""Generates assets/cards/<family>_ai_generated.png, placeholder art for
every card.

One icon per card family (all tiers share it; the tier marks tell them
apart), plus one per commodity, and unique card. Each is a simple
glowing glyph in the card's colour on a transparent background.

Icons are 320 px square: the largest card frame (the market grid) is about
323 px across on the author's emulator, about 300 px inside its border, so
320 px is just enough to show at full resolution without upscaling.

    python3 tool/generate_card_icons.py

Needs Pillow.
"""

import math
import os

from PIL import Image, ImageDraw, ImageFilter

SIZE = 320
SS = 4  # supersampling
S = SIZE * SS
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'cards')

# Card colours, matching cardColour() in lib/presentation/cards/card_widgets.dart.
LASER = (77, 225, 255)
MISSILE = (255, 162, 77)
TELEPORT = (255, 77, 61)
SHIELD = (127, 168, 255)
DRONE = (92, 255, 138)
BOOST = (255, 224, 102)
BERTH = (255, 210, 90)
HOSPITAL = (255, 143, 184)
HELL_SHIELD = (176, 123, 255)
SYSTEM = (159, 178, 200)
SUPPLY = (167, 180, 194)
GOODS = (217, 185, 140)
HELL = (255, 61, 127)
WHITE = (240, 240, 250)


def p(x, y):
    """A point in 0..1 icon space, in supersampled pixels."""
    return (x * S, y * S)


def box(x0, y0, x1, y1):
    return [x0 * S, y0 * S, x1 * S, y1 * S]


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c)


class Icon:
    def __init__(self, colour):
        self.colour = colour
        self.img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def fill(self, c=None, f=0.45):
        return shade(c or self.colour, f) + (255,)

    def line(self, c=None):
        return (c or self.colour) + (255,)

    def w(self, t=0.03):
        return int(t * S)

    def save(self, name):
        glow = self.img.filter(ImageFilter.GaussianBlur(S * 0.03))
        alpha = glow.getchannel('A').point(lambda a: int(a * 0.7))
        glow.putalpha(alpha)
        out = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        out.alpha_composite(glow)
        out.alpha_composite(self.img)
        out = out.resize((SIZE, SIZE), Image.LANCZOS)
        # A 256-colour palette keeps each file around 10 kB.
        out = out.quantize(256, method=Image.Quantize.FASTOCTREE)
        out.save(os.path.join(OUT, f'{name}_ai_generated.png'), optimize=True)


def poly(i, pts, c=None, f=0.45, width=0.03):
    i.d.polygon([p(*q) for q in pts], fill=i.fill(c, f), outline=i.line(c),
                width=i.w(width))


def ellipse(i, b, c=None, f=0.45, width=0.03):
    i.d.ellipse(box(*b), fill=i.fill(c, f) if f else None,
                outline=i.line(c), width=i.w(width))


def rect(i, b, c=None, f=0.45, width=0.03, r=0.04):
    i.d.rounded_rectangle(box(*b), radius=r * S, fill=i.fill(c, f) if f else None,
                          outline=i.line(c), width=i.w(width))


def stroke(i, pts, c=None, width=0.03):
    i.d.line([p(*q) for q in pts], fill=i.line(c), width=i.w(width),
             joint='curve')


def arc(i, b, start, end, c=None, width=0.03):
    i.d.arc(box(*b), start, end, fill=i.line(c), width=i.w(width))


def star(cx, cy, r_out, r_in, n, rot=-90):
    pts = []
    for k in range(n * 2):
        r = r_out if k % 2 == 0 else r_in
        a = math.radians(rot + k * 180 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def ngon(cx, cy, r, n, rot=-90):
    return [(cx + r * math.cos(math.radians(rot + k * 360 / n)),
             cy + r * math.sin(math.radians(rot + k * 360 / n)))
            for k in range(n)]


# Weapons and defences ---------------------------------------------------------

def laser():
    i = Icon(LASER)
    poly(i, [(0.12, 0.62), (0.40, 0.48), (0.48, 0.64), (0.20, 0.78)])
    stroke(i, [(0.46, 0.55), (0.90, 0.32)], WHITE, 0.035)
    stroke(i, [(0.46, 0.55), (0.90, 0.32)], width=0.012)
    ellipse(i, (0.84, 0.26, 0.96, 0.38), WHITE, 0.9, 0.01)
    i.save('laser')


def missiles():
    i = Icon(MISSILE)
    for dx in (-0.16, 0.0, 0.16):
        cx = 0.5 + dx
        poly(i, [(cx, 0.14), (cx + 0.06, 0.28), (cx + 0.06, 0.68),
                 (cx - 0.06, 0.68), (cx - 0.06, 0.28)])
        poly(i, [(cx - 0.06, 0.58), (cx - 0.11, 0.74), (cx - 0.06, 0.68)], f=0.8)
        poly(i, [(cx + 0.06, 0.58), (cx + 0.11, 0.74), (cx + 0.06, 0.68)], f=0.8)
        poly(i, [(cx - 0.035, 0.70), (cx, 0.86), (cx + 0.035, 0.70)],
             (255, 230, 120), 0.9, 0.01)
    i.save('missiles')


def teleporter():
    i = Icon(TELEPORT)
    for r, w in ((0.38, 0.02), (0.28, 0.025), (0.18, 0.03)):
        arc(i, (0.5 - r, 0.5 - r, 0.5 + r, 0.5 + r), 200, 520, width=w)
    ellipse(i, (0.40, 0.40, 0.60, 0.60), f=0.9)
    stroke(i, [(0.58, 0.42), (0.68, 0.30)], WHITE, 0.025)
    i.save('teleporter')


def shield():
    i = Icon(SHIELD)
    poly(i, [(0.5, 0.12), (0.82, 0.24), (0.78, 0.56), (0.5, 0.88),
             (0.22, 0.56), (0.18, 0.24)])
    poly(i, [(0.5, 0.24), (0.70, 0.32), (0.67, 0.54), (0.5, 0.74),
             (0.33, 0.54), (0.30, 0.32)], f=0.25, width=0.015)
    i.save('shield')


def fabricator():
    i = Icon(DRONE)
    for cx, cy in ((0.25, 0.30), (0.75, 0.30), (0.25, 0.70), (0.75, 0.70)):
        stroke(i, [(0.5, 0.5), (cx, cy)], width=0.035)
        ellipse(i, (cx - 0.13, cy - 0.05, cx + 0.13, cy + 0.05), f=0.3,
                width=0.018)
    ellipse(i, (0.38, 0.38, 0.62, 0.62), f=0.6)
    ellipse(i, (0.46, 0.46, 0.54, 0.54), WHITE, 0.9, 0.01)
    i.save('fabricator')


def plating():
    i = Icon(SYSTEM)
    for k, y in enumerate((0.20, 0.42, 0.64)):
        off = 0.06 if k % 2 else 0
        rect(i, (0.14 + off, y, 0.86 + off - 0.06, y + 0.18), f=0.35 + k * 0.1)
        for x in (0.24 + off, 0.70 + off):
            ellipse(i, (x - 0.02, y + 0.07, x + 0.02, y + 0.11), WHITE, 0.8, 0.005)
    i.save('plating')


def shield_capacitor():
    i = Icon(SYSTEM)
    rect(i, (0.30, 0.20, 0.70, 0.84), f=0.3)
    rect(i, (0.42, 0.13, 0.58, 0.20), f=0.6, width=0.02, r=0.01)
    poly(i, [(0.5, 0.32), (0.62, 0.37), (0.60, 0.55), (0.5, 0.70),
             (0.40, 0.55), (0.38, 0.37)], SHIELD, 0.6, 0.02)
    i.save('shield_capacitor')


# Synergy -----------------------------------------------------------------------

def fire_control():
    i = Icon(BOOST)
    ellipse(i, (0.18, 0.18, 0.82, 0.82), f=0.15)
    ellipse(i, (0.34, 0.34, 0.66, 0.66), f=0)
    for a, b in (((0.5, 0.08), (0.5, 0.36)), ((0.5, 0.64), (0.5, 0.92)),
                 ((0.08, 0.5), (0.36, 0.5)), ((0.64, 0.5), (0.92, 0.5))):
        stroke(i, [a, b], width=0.03)
    ellipse(i, (0.46, 0.46, 0.54, 0.54), TELEPORT, 1, 0.01)
    i.save('fire_control')


def capacitors():
    i = Icon(BOOST)
    for x in (0.22, 0.42, 0.62):
        rect(i, (x, 0.30, x + 0.16, 0.80), SYSTEM, 0.35, 0.02)
    poly(i, [(0.56, 0.10), (0.34, 0.50), (0.50, 0.50), (0.42, 0.90),
             (0.70, 0.42), (0.54, 0.42), (0.64, 0.10)], f=0.9, width=0.015)
    i.save('capacitors')


def quick_fuzes():
    i = Icon(BOOST)
    stroke(i, [(0.20, 0.82), (0.36, 0.62), (0.30, 0.48), (0.50, 0.36),
               (0.58, 0.40)], SYSTEM, 0.03)
    poly(i, star(0.66, 0.32, 0.22, 0.08, 8), f=0.9, width=0.012)
    ellipse(i, (0.61, 0.27, 0.71, 0.37), WHITE, 1, 0.005)
    i.save('quick_fuzes')


# Ship systems ------------------------------------------------------------------

def bunks():
    i = Icon(BERTH)
    for y in (0.28, 0.56):
        rect(i, (0.16, y, 0.84, y + 0.12), f=0.4, width=0.02)
        rect(i, (0.18, y - 0.05, 0.36, y + 0.02), WHITE, 0.7, 0.012, 0.02)
    for x in (0.16, 0.84):
        stroke(i, [(x, 0.18), (x, 0.86)], width=0.035)
    i.save('bunks')


def cargo_pod():
    i = Icon(SYSTEM)
    poly(i, [(0.5, 0.14), (0.86, 0.32), (0.5, 0.50), (0.14, 0.32)], f=0.6)
    poly(i, [(0.14, 0.32), (0.5, 0.50), (0.5, 0.88), (0.14, 0.70)], f=0.4)
    poly(i, [(0.86, 0.32), (0.5, 0.50), (0.5, 0.88), (0.86, 0.70)], f=0.3)
    i.save('cargo_pod')


def hospital():
    i = Icon(HOSPITAL)
    poly(i, [(0.38, 0.14), (0.62, 0.14), (0.62, 0.38), (0.86, 0.38),
             (0.86, 0.62), (0.62, 0.62), (0.62, 0.86), (0.38, 0.86),
             (0.38, 0.62), (0.14, 0.62), (0.14, 0.38), (0.38, 0.38)], f=0.6)
    i.save('hospital')


def barrier():
    i = Icon(HELL_SHIELD)
    for y in (0.30, 0.50, 0.70):
        pts = [(x / 20, y + 0.06 * math.sin(x / 20 * math.pi * 4))
               for x in range(2, 19)]
        stroke(i, pts, width=0.035)
    rect(i, (0.10, 0.16, 0.90, 0.84), f=0, width=0.02)
    i.save('barrier')


def tanks():
    i = Icon(SYSTEM)
    poly(i, [(0.5, 0.10)] + [
        (0.5 + 0.28 * math.cos(math.radians(a)),
         0.60 + 0.28 * math.sin(math.radians(a)))
        for a in range(-30, 211, 10)], (90, 200, 160), 0.5)
    ellipse(i, (0.36, 0.52, 0.46, 0.66), WHITE, 0.8, 0.005)
    i.save('tanks')


# Supplies ----------------------------------------------------------------------

def crate(i, c=SUPPLY):
    rect(i, (0.12, 0.44, 0.88, 0.86), c, 0.4)
    stroke(i, [(0.12, 0.58), (0.88, 0.58)], c, 0.02)


def missile_crate():
    i = Icon(SUPPLY)
    for x in (0.28, 0.44, 0.60, 0.76):
        poly(i, [(x - 0.04, 0.50), (x - 0.04, 0.24), (x, 0.12), (x + 0.04, 0.24),
                 (x + 0.04, 0.50)], MISSILE, 0.6, 0.015)
    crate(i)
    i.save('missile_crate')


def teleport_charges():
    i = Icon(SUPPLY)
    for x in (0.30, 0.50, 0.70):
        ellipse(i, (x - 0.08, 0.24, x + 0.08, 0.40), TELEPORT, 0.8, 0.015)
    crate(i)
    i.save('teleport_charges')


def feedstock():
    i = Icon(SUPPLY)
    rect(i, (0.24, 0.20, 0.76, 0.84), DRONE, 0.35, r=0.08)
    for y in (0.36, 0.68):
        stroke(i, [(0.24, y), (0.76, y)], DRONE, 0.025)
    ellipse(i, (0.24, 0.14, 0.76, 0.26), DRONE, 0.55, 0.02)
    i.save('feedstock')


# Hell ------------------------------------------------------------------------------

def flame(i, cx, cy, h, c, f=0.6):
    pts = []
    for k in range(0, 361, 10):
        a = math.radians(k)
        r = h * 0.32 * (1 - 0.55 * max(0, -math.sin(a)) ** 0.6)
        x = cx + r * math.cos(a) * (1 - 0.3 * max(0, -math.sin(a)))
        y = cy + h * 0.25 * math.sin(a)
        if math.sin(a) < 0:
            y = cy - h * 0.65 * (-math.sin(a)) ** 0.8
        pts.append((x, y))
    poly(i, pts, c, f, 0.02)


def brimstone():
    i = Icon(HELL)
    flame(i, 0.5, 0.66, 0.7, HELL, 0.5)
    flame(i, 0.5, 0.70, 0.38, (255, 170, 90), 0.85)
    i.save('brimstone')


def teeth():
    i = Icon(HELL)
    for k in range(9):
        a = math.radians(200 + k * 17.5)
        cx, cy = 0.5 + 0.34 * math.cos(a), 0.62 + 0.34 * math.sin(a)
        ta = a + math.pi
        tip = (cx + 0.16 * math.cos(ta), cy + 0.16 * math.sin(ta))
        side = (math.cos(ta + math.pi / 2) * 0.05, math.sin(ta + math.pi / 2) * 0.05)
        poly(i, [(cx + side[0], cy + side[1]), tip, (cx - side[0], cy - side[1])],
             WHITE, 0.85, 0.012)
    for k in range(7):
        a = math.radians(-160 + k * 23)
        cx, cy = 0.5 + 0.30 * math.cos(a) * 0.9, 0.42 + 0.30 * math.sin(a) * -0.2 + 0.2
        poly(i, [(cx - 0.035, cy), (cx, cy - 0.13), (cx + 0.035, cy)],
             WHITE, 0.7, 0.01)
    i.save('teeth')


def brandy_mist():
    i = Icon(HELL)
    for k, r in enumerate((0.36, 0.26, 0.16)):
        arc(i, (0.5 - r, 0.5 - r, 0.5 + r, 0.5 + r), 30 + k * 70, 300 + k * 70,
            (230, 160, 90), 0.03)
    poly(i, [(0.5, 0.34)] + [
        (0.5 + 0.10 * math.cos(math.radians(a)),
         0.56 + 0.10 * math.sin(math.radians(a))) for a in range(-30, 211, 15)],
         (230, 140, 60), 0.7, 0.015)
    i.save('brandy_mist')


def metal_flesh():
    i = Icon(HELL)
    pts = [(0.5 + 0.36 * math.cos(math.radians(a)) * (1 + 0.08 * math.sin(a / 13)),
            0.5 + 0.30 * math.sin(math.radians(a)))
           for a in range(0, 360, 12)]
    poly(i, pts, (190, 140, 160), 0.4)
    for x in (0.30, 0.42, 0.54, 0.66):
        arc(i, (x - 0.06, 0.28, x + 0.06, 0.72), 280, 440, SYSTEM, 0.025)
    ellipse(i, (0.66, 0.36, 0.74, 0.44), HELL, 0.9, 0.01)
    i.save('metal_flesh')


# Commodities -------------------------------------------------------------------

def goods_grain():
    i = Icon(GOODS)
    for dx in (-0.16, 0, 0.16):
        stroke(i, [(0.5 + dx * 0.4, 0.88), (0.5 + dx, 0.30)], width=0.02)
        for k in range(4):
            y = 0.20 + k * 0.10
            for s in (-1, 1):
                ellipse(i, (0.5 + dx + s * 0.035 - 0.03, y, 0.5 + dx + s * 0.035 + 0.03,
                            y + 0.08), f=0.7, width=0.01)
    i.save('goods_grain')


def goods_ice():
    i = Icon((170, 220, 255))
    poly(i, ngon(0.5, 0.5, 0.36, 6), f=0.35)
    for k in range(3):
        a = math.radians(k * 60)
        stroke(i, [(0.5 + 0.36 * math.cos(a), 0.5 + 0.36 * math.sin(a)),
                   (0.5 - 0.36 * math.cos(a), 0.5 - 0.36 * math.sin(a))], WHITE, 0.015)
    i.save('goods_ice')


def goods_ore():
    i = Icon(GOODS)
    poly(i, [(0.14, 0.70), (0.24, 0.42), (0.46, 0.34), (0.58, 0.52), (0.50, 0.80),
             (0.26, 0.84)], SYSTEM, 0.4)
    poly(i, [(0.50, 0.66), (0.60, 0.30), (0.80, 0.24), (0.88, 0.50), (0.78, 0.76)],
         (200, 150, 110), 0.5)
    ellipse(i, (0.66, 0.40, 0.74, 0.48), (255, 220, 120), 1, 0.005)
    i.save('goods_ore')


def goods_chitin():
    i = Icon(GOODS)
    for k in range(4):
        y = 0.22 + k * 0.15
        w = 0.34 - abs(k - 1.5) * 0.06
        poly(i, [(0.5 - w, y + 0.12), (0.5 - w + 0.04, y), (0.5 + w - 0.04, y),
                 (0.5 + w, y + 0.12)], (160, 190, 120), 0.45 + k * 0.08, 0.02)
    i.save('goods_chitin')


def goods_medicine():
    i = Icon(HOSPITAL)
    i.d.rounded_rectangle(box(0.18, 0.38, 0.82, 0.62), radius=0.12 * S,
                          fill=i.fill(WHITE, 0.8), outline=i.line(), width=i.w())
    i.d.rounded_rectangle(box(0.50, 0.38, 0.82, 0.62), radius=0.12 * S,
                          fill=i.fill(HOSPITAL, 0.7), outline=i.line(), width=i.w())
    i.save('goods_medicine')


def goods_nanopaste():
    i = Icon(SYSTEM)
    poly(i, [(0.24, 0.22), (0.76, 0.22), (0.66, 0.74), (0.34, 0.74)], f=0.4)
    rect(i, (0.42, 0.74, 0.58, 0.86), f=0.6, width=0.02, r=0.01)
    for x, y in ((0.40, 0.38), (0.56, 0.46), (0.46, 0.58), (0.60, 0.32)):
        ellipse(i, (x - 0.025, y - 0.025, x + 0.025, y + 0.025), LASER, 1, 0.005)
    i.save('goods_nanopaste')


def goods_brandy():
    i = Icon((230, 150, 70))
    poly(i, [(0.44, 0.10), (0.56, 0.10), (0.56, 0.34), (0.72, 0.46), (0.72, 0.86),
             (0.28, 0.86), (0.28, 0.46), (0.44, 0.34)], f=0.35)
    rect(i, (0.30, 0.56, 0.70, 0.84), HELL, 0.6, 0.015, 0.0)
    i.save('goods_brandy')


def goods_relics():
    i = Icon(BOOST)
    poly(i, [(0.5, 0.12), (0.88, 0.80), (0.12, 0.80)], f=0.35)
    poly(i, [(0.5, 0.80), (0.31, 0.46), (0.69, 0.46)], f=0.0, width=0.02)
    ellipse(i, (0.45, 0.56, 0.55, 0.66), WHITE, 0.9, 0.005)
    i.save('goods_relics')


def parcel_sealed():
    i = Icon(WHITE)
    rect(i, (0.16, 0.26, 0.84, 0.80), GOODS, 0.4)
    stroke(i, [(0.16, 0.48), (0.84, 0.48)], TELEPORT, 0.04)
    stroke(i, [(0.5, 0.26), (0.5, 0.80)], TELEPORT, 0.04)
    i.save('parcel_sealed')


# Uniques and consumables -----------------------------------------------------------

def mourner_event_horizon():
    i = Icon(LASER)
    ellipse(i, (0.08, 0.36, 0.92, 0.64), (255, 200, 120), 0.0, 0.03)
    ellipse(i, (0.30, 0.30, 0.70, 0.70), (20, 20, 30), 0.1, 0.02)
    i.save('mourner_event_horizon')


def mourner_unfallen_world():
    i = Icon(SYSTEM)
    ellipse(i, (0.28, 0.24, 0.72, 0.68), (90, 170, 120), 0.55)
    arc(i, (0.12, 0.10, 0.88, 0.86), 30, 150, WHITE, 0.035)
    arc(i, (0.18, 0.16, 0.82, 0.80), 40, 140, WHITE, 0.02)
    i.save('mourner_unfallen_world')


def mourner_polite_request():
    i = Icon(SHIELD)
    rect(i, (0.14, 0.18, 0.86, 0.64), f=0.35, r=0.12)
    poly(i, [(0.32, 0.62), (0.26, 0.84), (0.48, 0.63)], f=0.35, width=0.02)
    for x in (0.34, 0.5, 0.66):
        ellipse(i, (x - 0.035, 0.38, x + 0.035, 0.45), WHITE, 0.9, 0.005)
    i.save('mourner_polite_request')


def mourner_grief_engine():
    i = Icon(TELEPORT)
    poly(i, star(0.5, 0.5, 0.36, 0.28, 10), SYSTEM, 0.35, 0.02)
    poly(i, [(0.5, 0.30)] + [
        (0.5 + 0.12 * math.cos(math.radians(a)), 0.55 + 0.12 * math.sin(math.radians(a)))
        for a in range(-30, 211, 15)], SHIELD, 0.8, 0.015)
    i.save('mourner_grief_engine')


def hell_clock():
    """A brass clock ticking backwards, set in a greasy black stone ball
    with a tiny black hole at its heart."""
    i = Icon(HELL)
    ellipse(i, (0.10, 0.10, 0.90, 0.90), (60, 55, 60), 1.0, 0.02)
    ellipse(i, (0.18, 0.15, 0.42, 0.30), (200, 200, 210), 0.45, 0.0)
    brass = (220, 180, 110)
    ellipse(i, (0.24, 0.24, 0.76, 0.76), brass, 0.25, 0.03)
    for k in range(12):
        a = math.radians(k * 30)
        stroke(i, [(0.5 + 0.20 * math.cos(a), 0.5 + 0.20 * math.sin(a)),
                   (0.5 + 0.24 * math.cos(a), 0.5 + 0.24 * math.sin(a))], brass, 0.012)
    stroke(i, [(0.5, 0.5), (0.5, 0.32)], brass, 0.022)
    stroke(i, [(0.5, 0.5), (0.38, 0.57)], brass, 0.022)
    arc(i, (0.04, 0.04, 0.96, 0.96), 200, 300, HELL, 0.03)
    poly(i, [(0.10, 0.40), (0.06, 0.26), (0.18, 0.30)], HELL, 1, 0.01)
    ellipse(i, (0.45, 0.45, 0.55, 0.55), (0, 0, 0), 1.0, 0.012)
    i.save('hell_clock')


ALL = [laser, missiles, teleporter, shield, fabricator, plating,
       shield_capacitor, fire_control, capacitors, quick_fuzes, bunks,
       cargo_pod, hospital, barrier, tanks, missile_crate, teleport_charges,
       feedstock, brimstone, teeth, brandy_mist, metal_flesh, goods_grain,
       goods_ice, goods_ore, goods_chitin, goods_medicine, goods_nanopaste,
       goods_brandy, goods_relics, parcel_sealed, mourner_event_horizon,
       mourner_unfallen_world, mourner_polite_request,
       mourner_grief_engine, hell_clock]

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for draw in ALL:
        draw()
    print(f'{len(ALL)} icons in {os.path.normpath(OUT)}')
