"""Procedural concept mockups of the colony's workshops in brawl mode: what
the humans strip, make and mend for their captain. They are the backdrops
of those events.

Proof-of-concept placeholders, not final art. Writes
concept_art/colony_<scene>_ai_generated.png (see the naming rule in
CLAUDE.md); tool/generate_event_art.py cuts the event backdrops from them.

    python3 tool/generate_workshop_concepts.py          # every scene
    python3 tool/generate_workshop_concepts.py rifles   # just these

The scenes, from the events in lib/game_engine/brawl/events/:

- wreck (petition_wreck): the scavengers strip the enemy's wreck to the
  frame, cutting torches flaring, crates hauled home along tethers.
- rifles (petition_rifles): the workshops' rifles laid out on the bench,
  small, dense and very good.
- spares (gift_spares): a crate on the bridge, and in it a copy of one of
  the ship's own cards, better made than the factory's.
- ammunition (gift_ammunition): the magazine racked full, a cart of
  missiles on its way to a launcher.
- shipwrights (gift_shipwrights): the hull's ribs from the inside, every
  one scratched with the names of the people who reinforced it.
- double_shift (gift_double_shift): a cut through the hull, the crawlspace
  crews in every duct, torches lit, patching the damage.

Needs numpy, scipy and Pillow.
"""

import math

import numpy as np

from concept_kit import (
    AMBER, CYAN, DARK_STEEL, GOLD, H, HAZARD, HOT, ICE, RED, SILHOUETTE, STEEL, W, XX, YY,
    Layer, add, beam, bezier, card_art, crate, dot, finish, glow, human, interior, missile,
    noise, over, paste, rifle, rim, scene_main, silhouette, smooth, solid, space, spark)


# 1. The wreck ------------------------------------------------------------------------
# The enemy, stripped half to its frame. Torches flare all over it, and
# crates come home along tethers to an open hatch in the ship's hull.
def wreck():
    rng = np.random.default_rng(707)
    img = space(rng, nebula=np.array([0.16, 0.1, 0.2]), stars=1500)
    sun = np.exp(-(((XX - 120) ** 2 + (YY - 90) ** 2) / 40 ** 2))
    img = add(img, sun * 3 + glow(sun > 0.2, 80, 5), HOT)
    cx, cy, rot = 860, 430, math.radians(-10)
    c, s = math.cos(rot), math.sin(rot)

    def at(u, v):
        return (cx + u * c - v * s, cy + u * s + v * c)

    def half(u):  # the hull's half height at u along it
        return 125 * math.sqrt(max(0.0, 1 - (u / 540) ** 2)) + 18

    # The plated end, broken off jagged where the stripping has reached.
    top = [at(u, -half(u)) for u in range(-520, -40, 20)]
    jag = [at(-40 + rng.uniform(-25, 25), v) for v in np.linspace(-half(-40), half(-40), 9)]
    bottom = [at(u, half(u)) for u in range(-60, -521, -20)]
    P = Layer()
    P.poly(top + jag + bottom)
    plated = P.array()
    lit = smooth(cy + 140, cy - 140, YY) * 0.8 + 0.2
    img = over(img, plated, np.array([0.05, 0.05, 0.055]))
    img = add(img, plated * lit * 0.12 * (0.7 + 0.3 * noise(rng, 6)), STEEL * 3)
    seams = Layer()
    for u in range(-500, -40, 46):
        seams.line([at(u, -half(u)), at(u, half(u))], 1.2, 0.7)
    seams.line([at(-520, 0), at(-40, 0)], 1.2, 0.5)
    img = add(img, seams.array() * plated * -0.06, np.ones(3))
    img = add(img, rim(plated, (-0.7, -1), 3) * 1.1, ICE * 0.8)
    # The frame: the keel, two longerons and the ribs, bare.
    F = Layer()
    F.line([at(-60, 0), at(520, 0)], 9)
    F.line([at(-60, -half(-60) + 10), at(480, -half(480) + 10)], 6)
    F.line([at(-60, half(-60) - 10), at(470, half(470) - 10)], 6)
    for u in range(-20, 500, 40):
        hh = half(u)
        F.line(bezier(at(u, -hh), at(u + 18, -hh * 0.4), at(u + 18, hh * 0.4), at(u, hh), 16),
               5 if u < 420 else 4)
    frame = F.array()
    img = over(img, frame, np.array([0.06, 0.06, 0.065]))
    img = add(img, frame * lit * 0.25, STEEL * 1.5)
    img = add(img, rim(frame, (-0.7, -1), 2) * 1.2, ICE * 0.9)
    # Loose plates and parts drifting off.
    D = Layer()
    for _ in range(28):
        u, v = rng.uniform(-200, 640), rng.uniform(-260, 260)
        if abs(v) < half(u) + 15:
            v += math.copysign(half(u) + 30, v)
        x, y = at(u, v)
        r = rng.uniform(4, 14)
        a = rng.uniform(0, math.pi)
        D.poly([(x + math.cos(a + k * 2.1) * r * rng.uniform(0.6, 1.3),
                 y + math.sin(a + k * 2.1) * r * rng.uniform(0.6, 1.3)) for k in range(3)])
    debris = D.array()
    img = over(img, debris, np.array([0.08, 0.08, 0.09]))
    img = add(img, rim(debris, (-0.7, -1), 2) * 0.8, ICE * 0.6)
    # The ship's own hull in the foreground, with the hatch open and lit.
    O = Layer()
    O.ellipse(-120, 1420, 760, 640)
    own = O.array()
    img = over(img, own, np.array([0.035, 0.035, 0.04]))
    img = add(img, rim(own, (0.2, -1), 4) * 0.9, ICE * 0.6)
    hx, hy = 330, 840
    hatch = Layer()
    hatch.poly([(hx - 46, hy - 26), (hx + 40, hy - 40), (hx + 46, hy + 22), (hx - 40, hy + 34)])
    door = hatch.array()
    img = over(img, door, HOT * 0.85)
    img = add(img, glow(door, 30, 1.5), GOLD)
    img = add(img, beam((hx, hy - 10), 0.13, 900, math.atan2(cy - hy, cx - 160 - hx), 30) * 0.25, GOLD)
    # Tethers home, with crates on them.
    T = Layer()
    C = Layer()
    for u, v in ((-300, 120), (-120, 140), (120, 135), (300, 110)):
        ex, ey = at(u, v)
        pts = bezier((hx, hy), (hx + 120, hy - 60), (ex - 160, ey + 120), (ex, ey), 50)
        T.line(pts, 1.4, 0.8)
        for t in rng.uniform(0.2, 0.85, 2):
            x, y = pts[int(t * (len(pts) - 1))]
            C.poly([(x - 9, y - 6), (x + 9, y - 8), (x + 10, y + 6), (x - 8, y + 8)])
    tethers = T.array()
    img = add(img, tethers * 0.5, ICE * 0.7)
    crates = C.array()
    img = over(img, crates, np.array([0.12, 0.1, 0.07]))
    img = add(img, rim(crates, (-0.7, -1), 2) * 1.0, HAZARD * 0.8)
    # The scavengers, all over it, torches lit.
    spots = [(-30, -150), (40, -132), (130, -128), (210, -118), (310, -100), (380, -60),
             (60, 20), (180, 40), (260, -20), (-10, 120), (100, 135), (240, 110), (350, 80),
             (-200, -138), (-330, -120), (-130, 70), (430, -20), (150, -40)]
    W_ = Layer()
    torches = []
    for u, v in spots:
        x, y = at(u, v)
        h = rng.uniform(18, 26)
        human(W_, x, y, h, suit=True, wave=rng.choice([0, 1]))
        torches.append((x + h * 0.25, y - h * 0.62, rng.uniform(0.6, 1.2)))
    workers = W_.array()
    img = over(img, workers, SILHOUETTE * 3)
    img = add(img, rim(workers, (-0.7, -1), 2) * 0.7, ICE)
    for x, y, size in torches:
        img = spark(img, rng, x, y, size)
        lamp = np.exp(-(((XX - x + 6) ** 2 + (YY - y + 10) ** 2) / 1.4 ** 2))
        img = add(img, lamp * 2, CYAN)
    finish(img, 'colony_wreck', rng, grain=0.02)




# 2. The rifles --------------------------------------------------------------------------
# Under one lamp, the workshops' rifles in rows on the bench, and the
# representatives who came to ask if they can keep them.
def rifles():
    rng = np.random.default_rng(2020)
    img = interior(rng, base=np.array([0.03, 0.026, 0.022]), light=np.array([0.05, 0.04, 0.03]),
                   vx=768, vy=300, ribs=0.05)
    img = add(img, beam((768, 0), 0.5, 1100, math.pi / 2, 40) * 0.28, GOLD)
    img = dot(img, 768, 16, 14, HOT, gain=3)
    P = Layer()
    for x, h in ((360, 420), (1180, 440)):
        human(P, x, 600, h)
    img = silhouette(img, P.array(), (0, -1), rim_colour=GOLD, rim_gain=0.8)
    B = Layer()
    B.poly([(150, 470), (1386, 470), (1536, 1024), (0, 1024)])
    bench = B.array()
    img = solid(img, bench, np.array([0.13, 0.09, 0.06]), (0, -1), GOLD, 0.7, shade=0.3)
    R = Layer()
    for row, (y, length) in enumerate(((540, 210), (640, 250), (765, 300), (915, 360))):
        n = 5 - row // 2
        for k in range(n):
            x = 768 + (k - (n - 1) / 2) * length * 1.15
            rifle(R, x, y, length, math.radians(-4 + rng.uniform(-2, 2)))
    guns = R.array()
    img = solid(img, guns, STEEL * 0.35, (0, -1), HOT, 1.0, k=2, shade=0.2)
    shadow = np.roll(guns, 6, axis=0) * (1 - guns)
    img = over(img, shadow * 0.5, np.array([0.04, 0.025, 0.015]))
    finish(img, 'colony_rifles', rng, grain=0.02)


# 3. Spare parts ---------------------------------------------------------------------
# A crate on the bridge floor, the lid back, and in it something the ship
# already uses, made better than the factory made it.
def spares():
    rng = np.random.default_rng(2121)
    img = interior(rng, base=np.array([0.02, 0.025, 0.035]), light=np.array([0.04, 0.05, 0.07]),
                   vx=768, vy=360, ribs=0.06)
    P = Layer()
    for x, h in ((330, 520), (1210, 540), (1400, 470)):
        human(P, x, 860, h)
    img = silhouette(img, P.array(), (0, -1), rim_colour=CYAN, rim_gain=0.7)
    C = Layer()
    C.poly([(470, 600), (1066, 600), (1120, 960), (416, 960)])  # front
    front = C.array()
    lid = Layer()
    lid.poly([(470, 600), (1066, 600), (1010, 380), (526, 380)])
    inside = Layer()
    inside.poly([(470, 600), (1066, 600), (1020, 540), (516, 540)])
    img = solid(img, lid.array(), np.array([0.2, 0.15, 0.09]), (0, 1), GOLD, 0.6, shade=0.3)
    glow_in = inside.array()
    img = over(img, glow_in, HOT * 0.5)
    img = add(img, glow(glow_in, 50, 2.0), CYAN * 0.6)
    img = add(img, beam((768, 560), 0.35, 700, -math.pi / 2, 35) * 0.35, CYAN)
    rgb, alpha = card_art('laser')
    img = paste(img, rgb, alpha, 768, 470, 300, gain=1.6)
    img = solid(img, front, np.array([0.26, 0.19, 0.11]), (0, -1), GOLD, 0.8, shade=0.4)
    stencil = Layer()
    stencil.text(768, 790, 'COLONY WORKSHOPS', 40)
    stencil.text(768, 850, 'HANDLE WITH PRIDE', 26)
    img = add(img, stencil.array() * front * 0.25, np.array([0.9, 0.85, 0.75]))
    finish(img, 'colony_spares', rng, grain=0.02)


# 4. Ammunition ----------------------------------------------------------------------------
# The magazine, racked full for once, and a cart of missiles on its way to
# a launcher, pushed by two of the people who made them.
def ammunition():
    rng = np.random.default_rng(2222)
    img = interior(rng, base=np.array([0.03, 0.03, 0.035]), light=np.array([0.05, 0.05, 0.055]),
                   vx=900, vy=420, ribs=0.08)
    M = Layer()
    tips = []
    for shelf, (y, length, n, x0, gap) in enumerate(((210, 130, 7, 330, 150), (330, 150, 7, 300, 170),
                                                      (470, 175, 6, 250, 200))):
        M.rect(x0 - 60, y + 22, x0 + gap * n, y + 32)
        for k in range(n):
            x = x0 + k * gap
            missile(M, x + 10, y, length * 0.85, 0.0)
            tips.append((x + 10 + length * 0.425, y))
    racks = M.array()
    img = solid(img, racks, STEEL * 0.5, (0, -1), ICE, 0.7, k=2, shade=0.3)
    for x, y in tips:
        img = dot(img, x - 8, y, 4, AMBER, gain=0.8, halo=6)
    # The cart, and the two pushing it.
    C = Layer()
    C.rect(780, 760, 1240, 840)
    for x in (830, 1190):
        C.ellipse(x, 870, 34, 34)
    for j in range(2):
        missile(C, 1010, 728 - j * 80, 300, 0.0)
    cart = C.array()
    img = solid(img, cart, STEEL * 0.5, (0, -1), HAZARD, 0.8, shade=0.3)
    for j in range(2):
        img = dot(img, 1150, 728 - j * 80, 5, AMBER, gain=1.0)
    P = Layer()
    for x in (640, 720):
        human(P, x, 905, 330, walk=0.6, facing=1)
    img = silhouette(img, P.array(), (1, -0.5), rim_colour=HAZARD, rim_gain=0.7)
    floor = smooth(880, 1024, YY)
    stripes = (((XX - YY) // 40) % 2 == 0) * floor * (YY > 940)
    img = add(img, stripes * 0.12, HAZARD)
    for k in (-1, 1):
        L = Layer()
        L.line([(900 + k * 80, 120), (900 + k * 560, -10)], 10)
        strip = L.array()
        img = add(img, strip * 1.2 + glow(strip, 14, 1.2), ICE * 0.5)
    finish(img, 'colony_ammunition', rng, grain=0.02)


NAMES = ['ADA', 'BEN', 'CHIDI', 'DANA', 'EMIL', 'FREYA', 'GUS', 'HANA', 'IVO', 'JUN', 'KARI',
         'LEO', 'MIRA', 'NOOR', 'OLAF', 'PIA', 'RUI', 'SANNA', 'TOMAS', 'UNA', 'VERA', 'WIL',
         'YUSUF', 'ZOE', 'ARNA', 'BJORN', 'CORA', 'DIEGO', 'ELIN', 'FINN', 'GRETA', 'HUGO']


# 5. Shipwrights ---------------------------------------------------------------------------
# Inside the hull, rib after rib running away into the dark, every one
# scratched with the names of the people who reinforced it. Yours is at the
# top.
def shipwrights():
    rng = np.random.default_rng(2323)
    img = np.zeros((H, W, 3)) + np.array([0.02, 0.018, 0.016])
    vx, vy = 768, 520
    ribs = Layer()
    names = Layer()
    for k in range(9):
        t = 0.62 ** k
        half_w, half_h = 760 * t + 40, 450 * t + 30
        width = max(3, 60 * t)
        arch = [(vx + math.cos(a) * half_w, vy + 120 * t - math.sin(a) * half_h)
                for a in np.linspace(0, math.pi, 50)]
        ribs.line(arch, width)
        if k < 4:
            for j in range(int(30 * t) + 6):
                a = rng.uniform(0.15, math.pi - 0.15)
                x, y = vx + math.cos(a) * half_w, vy + 120 * t - math.sin(a) * half_h
                names.text(x, y + rng.uniform(-width * 0.3, width * 0.3), str(rng.choice(NAMES)),
                           max(4, width * 0.28), rng.uniform(0.5, 1))
    frames = ribs.array()
    img = solid(img, frames, np.array([0.2, 0.17, 0.13]), (0, -1), GOLD, 0.5, k=4, shade=0.3)
    img = over(img, names.array() * frames, np.array([0.55, 0.48, 0.36]))
    top = Layer()
    top.text(vx, vy + 120 - 480, 'CAPTAIN', 26)
    img = add(img, top.array() * frames * 1.2, HOT)
    # Work lamps, and two of the shipwrights showing it off.
    for x in (420, 1150):
        img = dot(img, x, 820, 10, HOT, gain=2.5, halo=50)
        img = add(img, beam((x, 820), 0.45, 700, -math.pi / 2 + (0.3 if x < 768 else -0.3), 30) * 0.18,
                  GOLD)
    P = Layer()
    human(P, 560, 1010, 330, wave=1)
    human(P, 980, 1020, 350)
    img = silhouette(img, P.array(), (0, -1), rim_colour=GOLD, rim_gain=0.9)
    finish(img, 'colony_shipwrights', rng, grain=0.02)


# 6. A double shift -------------------------------------------------------------------------
# A cut through the hull: the damage from the last fight on the outside,
# and in every duct and crawlspace behind it, crews at work with torches.
def double_shift():
    rng = np.random.default_rng(2424)
    img = space(rng, stars=800) * 0.6
    # The wall, cut away: a block of ducts and crawlspaces.
    wall = np.zeros((H, W), np.float32)
    wall[:, 300:] = 1
    img = over(img, wall, np.array([0.06, 0.06, 0.068]))
    D = Layer()
    ducts = []
    for row in range(5):
        y = 80 + row * 190
        x = 360
        while x < 1500:
            w = rng.uniform(170, 330)
            D.rect(x, y, min(1500, x + w), y + 130)
            ducts.append((x, y, min(1500, x + w)))
            x += w + rng.uniform(30, 60)
    for k in range(10):
        x = rng.uniform(420, 1450)
        y = 80 + int(rng.uniform(0, 4)) * 190 + 130
        D.rect(x, y, x + 40, y + 60)
    space_in = D.array()
    img = over(img, space_in, np.array([0.02, 0.018, 0.016]))
    img = add(img, space_in * smooth(0, 130, (YY - 80) % 190) * 0.08, GOLD)
    img = add(img, rim(space_in, (0, 1), 3) * 0.5, STEEL)
    # The outer hull, holed.
    O = Layer()
    O.poly([(240, 0), (320, 0), (330, 1024), (250, 1024)])
    hull = O.array()
    for _ in range(3):
        y = rng.uniform(150, 850)
        hole = np.hypot((XX - 285) / 70, (YY - y) / 90) + (noise(rng, 8) - 0.5) * 0.6 < 1
        hull = hull * (1 - hole)
    img = solid(img, hull, STEEL * 0.6, (-1, -0.3), ICE, 0.8)
    # The crews, small and dense, in every duct, torches lit.
    P = Layer()
    torches = []
    for x0, y, x1 in ducts:
        for _ in range(int((x1 - x0) / 120) + 1):
            x = rng.uniform(x0 + 30, x1 - 30)
            h = rng.uniform(70, 100)
            human(P, x, y + 128, h, wave=int(rng.choice([0, 1])))
            torches.append((x + h * 0.22, y + 128 - h * 0.95))
    img = silhouette(img, P.array(), (0, -1), rim_colour=GOLD, rim_gain=0.6)
    for x, y in torches[::2]:
        img = spark(img, rng, x, y, rng.uniform(0.6, 1.0))
    finish(img, 'colony_double_shift', rng, grain=0.02)


SCENES = {f.__name__: f for f in (wreck, rifles, spares, ammunition, shipwrights, double_shift)}

if __name__ == '__main__':
    scene_main(SCENES, 'workshop mockups')
