"""Procedural concept mockups of what happens on the way out of a station in
brawl mode: the lanes, who waits on them, and the elites. They are the
backdrops of those events.

Proof-of-concept placeholders, not final art. Writes
concept_art/lane_<scene>_ai_generated.png (see the naming rule in
CLAUDE.md); tool/generate_event_art.py cuts the event backdrops from them.

    python3 tool/generate_lane_concepts.py          # every scene
    python3 tool/generate_lane_concepts.py toll     # just these

The scenes, from lib/game_engine/brawl/events/departure_events.dart and
elite_events.dart:

- toll (toll): three gunships idling across the pipe exit, guns warm.
- wreck (wreck): a freighter tumbling through the lane, lights out, cargo
  doors open.
- exclusion (neo_terra): the Neo Terran exclusion zone's warning buoys,
  and past them the war-torn world and a defence platform.
- smuggler (smuggler): a Bhrun hauler alongside, two unlabelled crates in
  its open hold.
- leak (leak): inside the pipe, Hell's brandy beading on the barrier
  through a crack.
- quiet (quiet_lane): an old freight lane, its buoys dead, nothing out
  there at all.
- convoy (convoy): a Tern convoy behind you, and something waiting in the
  rocks ahead.
- shakedown (shakedown): human pirates boxing you in, the Last Vote behind
  them, known by its paint: a ballot mark.
- duel (gor_duel): a Gor warship across the pipe exit, broadcasting its
  challenge, its champion on your screen.
- foundry (unmerged_foundry): an unmerged Tern foundry, out of touch and
  still building itself bigger from wrecks, its drones turning as one.
- nobody (nobody): a small human ship with no markings alongside, a shield
  and drones far too big for it, a pleasant voice on the comm.
- ascension (uploaded_flagship): Shining-head's flagship at the end, holed
  bow to stern, the Republic's wrecks burning behind it.

Needs numpy, scipy and Pillow.
"""

import math

import numpy as np

from concept_kit import (
    AMBER, BRANDY, CYAN, DARK_STEEL, GOLD, H, HAZARD, HOT, ICE, RED, STEEL, W, XX, YY, Layer,
    add, along, bezier, concept, crate, dot, finish, glow, hell, noise, over, planet, rim, ring,
    scene_main, screen, ship, ship_points, silhouette, smooth, solid, space)


def sun(img, x, y, r, colour=HOT, gain=4):
    s = np.exp(-(((XX - x) ** 2 + (YY - y) ** 2) / r ** 2))
    return add(img, s * 3 + glow(s > 0.2, r * 2, gain), colour)


def engines(img, pts, colour=ICE, r=5):
    for x, y in pts:
        img = dot(img, x, y, r, colour, gain=2.5, halo=r * 4)
    return img


def lit_ship(img, kind, cx, cy, length, angle, base=STEEL * 0.45, toward=(0.7, -0.7),
             rim_colour=ICE, squash=1.0):
    """A ship of [kind], lit from [toward], its plating a little uneven."""
    L = Layer()
    ship(L, kind, cx, cy, length, angle, squash)
    hull = L.array()
    img = solid(img, hull, base, toward, rim_colour, 1.0, k=3, shade=0.45)
    seams = Layer()
    for u in np.arange(-0.42, 0.45, 0.07):
        seams.line([along(cx, cy, length, angle, u, -0.3), along(cx, cy, length, angle, u, 0.3)], 1.5)
    seams.line([along(cx, cy, length, angle, -0.5), along(cx, cy, length, angle, 0.5)], 2)
    img = over(img, seams.array() * hull * 0.5, base * 0.2)
    plating = noise(np.random.default_rng(int(cx * 7 + cy)), 3) - 0.5
    return add(img, hull * plating * 0.25, base), hull


# 1. Toll collectors ----------------------------------------------------------------------
# Out of the pipe and straight into three gunships, side by side, guns
# warm. The gate's ring is still at your back.
def toll():
    rng = np.random.default_rng(3030)
    img = space(rng, nebula=np.array([0.14, 0.08, 0.2]))
    img = ring(img, -180, 520, 620, 60, aspect=1.0, light=(0.8, -0.4), glow_colour=CYAN)
    img = sun(img, 1380, 140, 30)
    for cx, cy, length in ((760, 450, 330), (1060, 600, 380), (1180, 330, 260)):
        img, _ = lit_ship(img, 'gunship', cx, cy, length, math.pi)
        nose = along(cx, cy, length, math.pi, 0.5)
        img = dot(img, nose[0] - 4, nose[1], 5, RED, gain=3, halo=20)
        for v in (-0.22, 0.22):
            wing = along(cx, cy, length, math.pi, -0.2, v)
            img = dot(img, *wing, 3.5, RED, gain=2.5, halo=12)
        img = engines(img, [along(cx, cy, length, math.pi, -0.48, v) for v in (-0.06, 0.06)], AMBER, 4)
    finish(img, 'lane_toll', rng, grain=0.02)


# 2. A drifting wreck ---------------------------------------------------------------------
# A freighter turning slowly end over end, lights out, its cargo doors
# hanging open on dark holds.
def wreck():
    rng = np.random.default_rng(3131)
    img = space(rng, stars=1700)
    img = sun(img, 1400, 120, 34)
    cx, cy, length, angle = 760, 520, 1150, math.radians(-16)
    L = Layer()
    ship(L, 'freighter', cx, cy, length, angle)
    for u in np.arange(-0.42, 0.34, 0.095):  # containers along its spine
        L.poly([along(cx, cy, length, angle, u, v) for u, v in
                ((u, -0.07), (u + 0.08, -0.07), (u + 0.08, -0.15), (u, -0.15))])
    hull = L.array()
    img = solid(img, hull, STEEL * 0.42, (0.6, -0.8), ICE, 1.0, k=3, shade=0.5)
    D = Layer()
    for u in (-0.33, -0.14, 0.05, 0.24):
        D.poly([along(cx, cy, length, angle, u, v) for u, v in
                ((u, -0.13), (u + 0.06, -0.13), (u + 0.06, -0.08), (u, -0.08))])
    doors = D.array()
    img = over(img, doors, np.array([0.01, 0.01, 0.012]))
    img = add(img, doors * smooth(0, 1, noise(rng, 6)) * 0.08, AMBER)
    C = Layer()
    for _ in range(9):
        u = rng.choice([-0.3, -0.11, 0.08, 0.27])
        x, y = along(cx, cy, length, angle, u, -0.2 - rng.uniform(0, 0.12))
        crate(C, x, y, rng.uniform(16, 30), rng.uniform(12, 22), rng.uniform(0, math.pi))
    img = solid(img, C.array(), np.array([0.22, 0.17, 0.1]), (0.6, -0.8), HOT, 0.8, k=2)
    for u in (0.48, -0.48):
        img = dot(img, *along(cx, cy, length, angle, u), 2.2, np.array([0.3, 0.05, 0.04]), gain=1,
                  halo=4)
    finish(img, 'lane_wreck', rng, grain=0.02)


# 3. The exclusion zone --------------------------------------------------------------------
# Warning buoys strung along the lane, red in every language the Republic
# uses; past them, Neo Terra under bombardment and one of its platforms.
def exclusion():
    rng = np.random.default_rng(3232)
    img = space(rng, nebula=np.array([0.2, 0.06, 0.06]), stars=1300)
    img = planet(img, rng, 1190, 300, 230, ocean=np.array([0.12, 0.16, 0.12]),
                 land=np.array([0.2, 0.18, 0.15]), light=(-0.7, -0.3), rim=np.array([0.7, 0.75, 0.6]))
    for _ in range(14):  # the bombardment
        a, d = rng.uniform(0, 2 * math.pi), rng.uniform(0, 200)
        img = dot(img, 1190 + math.cos(a) * d, 300 + math.sin(a) * d * 0.9, 2.5, HOT, gain=1.8, halo=10)
    P = Layer()
    P.rect(980, 470, 1260, 520)
    P.rect(1100, 420, 1140, 570)
    for x in (1010, 1230):
        P.ellipse(x, 455, 26, 14)
        P.rect(x - 3, 455, x + 3, 472)
    platform = P.array()
    img = solid(img, platform, STEEL * 0.4, (-0.7, -0.4), ICE, 0.9, k=2)
    img = dot(img, 1010, 450, 4, RED, gain=2.5)
    img = dot(img, 1230, 450, 4, RED, gain=2.5)
    # The buoys, from the foreground away along the line.
    B = Layer()
    lights = []
    for k in range(8):
        t = k / 7
        x = 240 + 700 * t ** 0.8
        y = 820 - 360 * t ** 0.8
        s = 120 * (1 - t) ** 1.2 + 12
        B.rect(x - s * 0.22, y - s, x + s * 0.22, y)
        B.ellipse(x, y - s, s * 0.22, s * 0.08)
        B.line([(x, y - s), (x, y - s * 1.45)], max(1.5, s * 0.03))
        lights.append((x, y - s * 0.55, s))
    img = solid(img, B.array(), np.array([0.2, 0.2, 0.22]), (-0.6, -0.6), RED, 0.5, k=2)
    for x, y, s in lights:
        img = dot(img, x, y, max(1.5, s * 0.08), RED, gain=2.5, halo=s * 0.5)
        img = dot(img, x, y - s * 0.95, max(1, s * 0.04), RED, gain=2, halo=s * 0.2)
    # A hologram over the nearest buoy.
    x, y, s = lights[0]
    T = Layer()
    T.poly([(x, y - s * 2.6), (x - s * 0.75, y - s * 1.35), (x + s * 0.75, y - s * 1.35)])
    T.poly([(x, y - s * 2.3), (x - s * 0.55, y - s * 1.47), (x + s * 0.55, y - s * 1.47)], 0)
    sign = T.array()
    words = Layer()
    words.text(x, y - s * 1.75, '!', s * 0.6)
    words.text(x + s * 1.2, y - s * 2.0, 'EXCLUSION ZONE', s * 0.24, anchor='lm')
    words.text(x + s * 1.2, y - s * 1.7, 'NO EXCEPTIONS  ·  NO APPEALS', s * 0.14, anchor='lm')
    holo = sign + words.array()
    img = add(img, holo * 1.1 + glow(holo, 6, 1.2), RED)
    finish(img, 'lane_exclusion', rng, grain=0.02)


# 4. Unlabelled crates ---------------------------------------------------------------------
# A Bhrun hauler drifts alongside, all grey rock plates, its hold open on
# two crates with no labels.
def smuggler():
    rng = np.random.default_rng(3333)
    img = space(rng, stars=1200)
    img = sun(img, 160, 160, 34)
    cx, cy, rx, ry = 980, 560, 640, 380
    d = np.hypot((XX - cx) / rx, (YY - cy) / ry)
    body = smooth(1.0, 0.99, d)
    plates, cracks = rock_plates(rng, cx, cy, rx, ry, 70)
    lit = smooth(0.4, -1.0, ((XX - cx) * 0.7 + (YY - cy) * 0.7) / rx)
    z = np.sqrt(np.clip(1 - d * d, 0, 1))
    img = over(img, body, np.array([0.03, 0.03, 0.03]))
    img = add(img, body * (0.2 + 0.8 * lit) * (0.35 + 0.65 * z) * (0.7 + 0.3 * plates) * 0.28,
              np.array([0.62, 0.62, 0.6]))
    img = over(img, body * cracks, np.array([0.015, 0.015, 0.015]))
    img = add(img, rim(body, (-0.7, -0.7), 4) * 0.6, HOT * 0.6)
    # Its hold, open, lit, and the two crates.
    hx0, hy0, hx1, hy1 = 470, 520, 760, 720
    hold = np.zeros((H, W), np.float32)
    hold[hy0:hy1, hx0:hx1] = 1
    hold *= body
    img = over(img, hold, np.array([0.18, 0.13, 0.07]))
    img = add(img, glow(hold, 40, 0.8), AMBER * 0.6)
    C = Layer()
    crate(C, 560, 670, 110, 80)
    crate(C, 680, 680, 90, 66, 0.08)
    img = solid(img, C.array(), np.array([0.22, 0.18, 0.12]), (0, -1), HOT, 0.8, k=2, shade=0.2)
    for k in range(5):
        img = dot(img, 520 + k * 180, 905 - 40 * math.sin(k), 3, AMBER, gain=2, halo=10)
    finish(img, 'lane_smuggler', rng, grain=0.02)


# 5. Brandy in the pipe ------------------------------------------------------------------------
# Inside the gateway pipe: the barrier is weeping. Through a crack in its
# upper wall, Hell's sea beads into heavy amber drops.
def leak():
    rng = np.random.default_rng(3434)
    vx, vy = 768, 520
    img = np.zeros((H, W, 3)) + np.array([0.008, 0.015, 0.03])
    R = Layer()
    for k in range(16):
        t = 0.8 ** k
        R.ring(vx, vy, 980 * t + 8, 760 * t + 6, max(1, 5 * t), 0.9 * (1 - k / 18))
    walls = R.array()
    img = add(img, walls * 0.7 + glow(walls, 10, 1.4), ICE * 0.7)
    img = add(img, glow(np.hypot(XX - vx, YY - vy) < 20, 30, 4), ICE)
    # The crack, and the murk on the far side of it.
    crack = bezier((420, 140), (600, 70), (900, 120), (1160, 60), 30)
    Cr = Layer()
    for (x0, y0), (x1, y1) in zip(crack, crack[1:]):
        jag = rng.uniform(-10, 10)
        Cr.line([(x0, y0 + jag), (x1, y1 - jag)], 5)
    line = Cr.array()
    img = add(img, glow(line, 30, 2.0), BRANDY * 2)
    img = add(img, line * 1.5, AMBER)
    # The beads, heavy, on the wall under the crack, and a few let go.
    for _ in range(46):
        t = rng.uniform(0, 1)
        x, y = crack[int(t * (len(crack) - 1))]
        y += rng.uniform(10, 120) ** 1.1
        r = rng.uniform(5, 15)
        bead = np.hypot(XX - x, (YY - y) / 1.25) < r
        img = over(img, bead * 0.85, BRANDY * 1.4)
        img = dot(img, x - r * 0.3, y - r * 0.4, r * 0.25, HOT, gain=1.5, halo=r * 0.6)
        img = add(img, glow(bead, r, 0.3), AMBER)
    finish(img, 'lane_leak', rng, grain=0.02)


# 6. A quiet lane -----------------------------------------------------------------------------
# An old freight lane. The buoys are dead, one after another into the
# distance, and there is nothing out there at all.
def quiet():
    rng = np.random.default_rng(3535)
    img = space(rng, nebula=np.array([0.04, 0.05, 0.08]), stars=700) * 0.8
    B = Layer()
    tops = []
    for k in range(11):
        t = k / 10
        x = 1200 - 900 * t ** 0.6
        y = 880 - 470 * t ** 0.6
        s = 140 * (1 - t) ** 1.4 + 6
        B.rect(x - s * 0.18, y - s, x + s * 0.18, y)
        B.ellipse(x, y - s, s * 0.18, s * 0.06)
        tops.append((x, y - s * 0.85, s))
    img = solid(img, B.array(), np.array([0.12, 0.11, 0.1]), (-0.6, -0.6), ICE, 0.3, k=2)
    x, y, s = tops[3]
    img = dot(img, x, y, max(1.5, s * 0.06), AMBER * 0.6, gain=1.2, halo=s * 0.3)  # the last one lit
    S = Layer()
    ship(S, 'sleek', 300, 900, 160, math.radians(-30))
    img = solid(img, S.array(), STEEL * 0.4, (0.6, -0.8), ICE, 0.9, k=2)
    img = engines(img, [along(300, 900, 160, math.radians(-30), -0.5)], CYAN, 4)
    finish(img, 'lane_quiet', rng, grain=0.02)


def rock_plates(rng, cx, cy, rx, ry, n):
    """Cracked rock plates over an ellipse, like a Bhrun's hide: each
    plate's own shade, and the cracks between them."""
    from scipy.spatial import cKDTree
    seeds = np.stack([cx + rng.uniform(-1, 1, n) * rx, cy + rng.uniform(-1, 1, n) * ry], 1)
    tree = cKDTree(seeds)
    d, i = tree.query(np.stack([XX.ravel(), YY.ravel()], 1), k=2)
    edge = (d[:, 1] - d[:, 0]).reshape(H, W)
    shade = rng.uniform(0, 1, n)[i[:, 0]].reshape(H, W)
    return shade, smooth(5, 1.5, edge)


def tern_ship(L, cx, cy, size, angle):
    """A Tern hull: a triangle, point first, its lattice glowing."""
    pts = [along(cx, cy, size, angle, u, v) for u, v in ((0.5, 0), (-0.4, -0.42), (-0.4, 0.42))]
    L.poly(pts)
    return pts


# 7. Escort wanted -----------------------------------------------------------------------------
# You at the point, a Tern convoy strung out behind, and ahead, in the
# rocks, something waiting with its lights off. Not all of them.
def convoy():
    rng = np.random.default_rng(3636)
    img = space(rng, stars=1300)
    img = sun(img, 1400, 880, 26, gain=3)
    T = Layer()
    lattice = Layer()
    for k in range(5):
        cx, cy = 260 + k * 150, 330 + k * 95
        size = 150 - k * 18
        a, b, c = tern_ship(T, cx, cy, size, math.radians(-28))
        for f in (0.33, 0.66):
            lattice.line([(a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f),
                          (a[0] + (c[0] - a[0]) * f, a[1] + (c[1] - a[1]) * f)], 1.4)
            lattice.line([(b[0] + (c[0] - b[0]) * f, b[1] + (c[1] - b[1]) * f), a], 1.2)
        img = dot(img, (a[0] + b[0] + c[0]) / 3, (a[1] + b[1] + c[1]) / 3, 4, CYAN, gain=2, halo=14)
    img = solid(img, T.array(), np.array([0.08, 0.14, 0.16]), (0.7, 0.6), CYAN, 0.8, k=2)
    img = add(img, lattice.array() * T.array() * 0.6, CYAN)
    img, _ = lit_ship(img, 'sleek', 330 + 640, 180 + 250, 120, math.radians(-28), toward=(0.7, 0.6))
    # The rocks ahead, and the eyes in them.
    R = Layer()
    for _ in range(22):
        x, y = rng.uniform(1050, 1560), rng.uniform(400, 1000)
        r = rng.uniform(14, 70)
        R.poly([(x + math.cos(a) * r * rng.uniform(0.7, 1.2), y + math.sin(a) * r * rng.uniform(0.7, 1.2))
                for a in np.linspace(0, 2 * math.pi, 9)[:-1]])
    img = solid(img, R.array(), np.array([0.12, 0.1, 0.09]), (0.7, 0.6), HOT * 0.6, 0.6, k=2)
    for x, y in ((1260, 600), (1390, 760), (1180, 880)):
        img = dot(img, x, y, 2.5, RED, gain=2.5, halo=8)
        img = dot(img, x + 12, y, 2.5, RED, gain=2.5, halo=8)
    finish(img, 'lane_convoy', rng, grain=0.02)


# 8. Human pirates ------------------------------------------------------------------------------
# Three ships with no transponders box you in, and a fourth, much bigger,
# settles in behind them: the Last Vote, by its paint.
def shakedown():
    rng = np.random.default_rng(3737)
    img = space(rng, nebula=np.array([0.16, 0.06, 0.1]), stars=1300)
    img = sun(img, 140, 860, 30, gain=3)
    cx, cy, length, angle = 900, 380, 820, math.radians(172)
    img, hull = lit_ship(img, 'heavy', cx, cy, length, angle, base=np.array([0.11, 0.105, 0.1]),
                         toward=(-0.7, 0.6), rim_colour=HOT)
    # The paint: a ballot mark down its flank.
    Mk = Layer()
    Mk.line([(760, 330), (830, 410), (1060, 240)], 30)
    mark = Mk.array() * hull
    img = over(img, mark * 0.85, np.array([0.7, 0.06, 0.05]))
    words = Layer()
    words.text(930, 480, 'THE LAST VOTE', 30)
    img = add(img, words.array() * hull * 0.4, np.array([0.9, 0.85, 0.8]))
    img = engines(img, [along(cx, cy, length, angle, -0.5, v) for v in (-0.12, 0, 0.12)], AMBER, 7)
    for gx, gy, gl, ga in ((330, 300, 240, -0.2), (520, 760, 280, 0.3), (1280, 720, 260, math.pi + 0.4)):
        img, _ = lit_ship(img, 'gunship', gx, gy, gl, ga, toward=(-0.7, 0.6), rim_colour=HOT)
        img = dot(img, *along(gx, gy, gl, ga, 0.48), 4, RED, gain=2.5, halo=14)
    finish(img, 'lane_shakedown', rng, grain=0.02)


# 9. A challenge ----------------------------------------------------------------------------------
# A Gor warship hangs across the pipe exit, broadcasting on every channel,
# and its champion is on your screen.
def duel():
    rng = np.random.default_rng(3838)
    img = space(rng, nebula=np.array([0.22, 0.1, 0.05]), stars=1200)
    img = sun(img, 1420, 120, 34, colour=np.array([1.0, 0.75, 0.5]))
    cx, cy, length, angle = 820, 420, 1250, math.radians(178)
    B = Layer()
    for k in range(1, 7):
        B.ring(cx, cy, 200 + k * 110, 120 + k * 70, 3, 0.9 - k * 0.12)
    rings = B.array()
    img = add(img, rings * 0.25 + glow(rings, 6, 0.4), AMBER)
    img, _ = lit_ship(img, 'warship', cx, cy, length, angle, base=np.array([0.24, 0.13, 0.07]),
                      toward=(0.7, -0.7), rim_colour=np.array([1.0, 0.7, 0.4]))
    for u in (-0.2, 0.1, 0.3):
        img = dot(img, *along(cx, cy, length, angle, u, 0.14), 4, RED, gain=2.5, halo=12)
    img = screen(img, 70, 640, 560, 960, concept('icon_5'), tint=AMBER,
                 caption='CHAMPION  ·  ON EVERY CHANNEL')
    finish(img, 'lane_duel', rng, grain=0.02)


# 10. Unmerged ---------------------------------------------------------------------------------------
# A Tern foundry, out of touch with every other Tern: a lattice building
# itself bigger out of the wrecks it hauls in, and its drones, as one.
def foundry():
    rng = np.random.default_rng(3939)
    img = space(rng, nebula=np.array([0.04, 0.12, 0.1]), stars=1200)
    top, left, right = (820, 110), (380, 860), (1260, 860)
    L = Layer()
    n = 9
    for i in range(n + 1):
        f = i / n
        a = (top[0] + (left[0] - top[0]) * f, top[1] + (left[1] - top[1]) * f)
        b = (top[0] + (right[0] - top[0]) * f, top[1] + (right[1] - top[1]) * f)
        c = (left[0] + (right[0] - left[0]) * f, left[1])
        if rng.random() < 0.85:
            L.line([a, b], 3)
        if rng.random() < 0.85:
            L.line([a, c], 3)
        if rng.random() < 0.85:
            L.line([b, (right[0] - (right[0] - left[0]) * f, left[1])], 3)
    frame = L.array()
    flicker = 0.4 + 0.6 * (noise(rng, 30) > 0.45)
    img = add(img, frame * flicker * 0.8 + glow(frame, 6, 0.6) * flicker, np.array([0.3, 0.8, 0.7]))
    # Wrecks it is hauling in, on lines.
    Wk = Layer()
    lines = Layer()
    for x, y, length, a in ((180, 300, 260, 0.6), (1380, 330, 220, 2.6), (1300, 980, 280, -2.4)):
        ship(Wk, rng.choice(['freighter', 'gunship', 'heavy']), x, y, length, a)
        lines.line([(x, y), (820, 560)], 1.5)
    img = add(img, lines.array() * 0.4, np.array([0.3, 0.8, 0.7]))
    img = solid(img, Wk.array(), STEEL * 0.35, (0.6, -0.8), ICE, 0.7, k=2)
    # The drones, turning as one.
    for k in range(260):
        a = rng.uniform(0, 2 * math.pi)
        r = 330 + rng.normal(0, 60)
        x = 820 + math.cos(a) * r * 1.4
        y = 520 + math.sin(a) * r * 0.55 + rng.normal(0, 20)
        img = dot(img, x, y, 1.6, CYAN, gain=1.4, halo=3)
    for k in range(6):
        img = dot(img, 600 + k * 90, 700 + 20 * math.sin(k), 3, RED, gain=2, halo=10)
    finish(img, 'lane_foundry', rng, grain=0.02)


# 11. Nobody ------------------------------------------------------------------------------------------
# From the bridge: a small human ship alongside, no markings, a shield and
# a drone swarm far too big for it. The comm has a pleasant voice on it.
def nobody():
    rng = np.random.default_rng(4040)
    beyond = space(rng, stars=1300)
    beyond = sun(beyond, 1350, 150, 28)
    cx, cy, length, angle = 760, 420, 520, math.radians(184)
    beyond, _ = lit_ship(beyond, 'sleek', cx, cy, length, angle, base=np.array([0.1, 0.1, 0.11]),
                         toward=(0.6, -0.8))
    cockpit = along(cx, cy, length, angle, 0.3, 0)
    pit = np.hypot((XX - cockpit[0]) / 26, (YY - cockpit[1]) / 11) < 1
    beyond = over(beyond, pit * 1.0, HOT * 0.6)
    beyond = add(beyond, glow(pit, 8, 0.8), GOLD)
    beyond = over(beyond, (np.hypot(XX - cockpit[0] - 4, YY - cockpit[1] + 1) < 7) * 1.0,
                  np.array([0.02, 0.02, 0.02]))  # one man, alone
    shield = np.hypot((XX - cx) / 420, (YY - cy) / 170)
    beyond = add(beyond, np.exp(-((shield - 1) / 0.03) ** 2) * 0.5 + smooth(1.0, 0.6, shield) * 0.05, CYAN)
    for _ in range(90):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(1.2, 1.9)
        beyond = dot(beyond, cx + math.cos(a) * 420 * r, cy + math.sin(a) * 170 * r, 1.8, CYAN * 0.8,
                     gain=1.4, halo=3)
    img = np.zeros((H, W, 3)) + np.array([0.012, 0.014, 0.02])
    m = np.zeros((H, W), np.float32)
    m[60:700, 120:1416] = 1
    img = img * (1 - m[..., None]) + beyond * m[..., None]
    F = Layer()
    F.rect(100, 40, 1436, 60)
    F.rect(100, 700, 1436, 720)
    for x in (100, 280, 1236, 1416):
        F.rect(x, 40, x + 20, 720)
    img = solid(img, F.array(), DARK_STEEL * 2, (0, -1), ICE, 0.4, shade=0.2)
    # The console and its comm screen: voice only, no transponder.
    K = Layer()
    K.poly([(0, 760), (1536, 760), (1536, 1024), (0, 1024)])
    img = solid(img, K.array(), np.array([0.04, 0.045, 0.055]), (0, -1), ICE, 0.4, shade=0.1)
    sx0, sy0, sx1, sy1 = 560, 800, 976, 990
    scr = np.zeros((H, W), np.float32)
    scr[sy0:sy1, sx0:sx1] = 1
    img = over(img, scr, np.array([0.01, 0.03, 0.035]))
    wave = Layer()
    pts = [(x, 905 + 40 * math.sin(x / 9) * math.exp(-((x - 768) / 120) ** 2) * rng.uniform(0.6, 1))
           for x in range(sx0 + 20, sx1 - 20, 3)]
    wave.line(pts, 2)
    wave.text(768, 830, 'VOICE ONLY  ·  NO TRANSPONDER', 16)
    trace = wave.array()
    img = add(img, trace * 1.2 + glow(trace, 5, 0.8), CYAN)
    img = add(img, glow(scr, 30, 0.3), CYAN * 0.4)
    finish(img, 'lane_nobody', rng, grain=0.02)


# 12. The Ascension ------------------------------------------------------------------------------
# Shining-head's flagship, white and gold under a halo, holed from bow to
# stern, the Republic's fleets burning behind it, and its voice on every
# channel, including yours.
def ascension():
    rng = np.random.default_rng(4141)
    img = space(rng, nebula=np.array([0.2, 0.15, 0.05]), stars=1300)
    # The Republic's wrecks, burning.
    for _ in range(9):
        x, y = rng.uniform(100, 1500), rng.uniform(80, 420)
        img, _ = lit_ship(img, str(rng.choice(['gunship', 'freighter', 'heavy'])), x, y,
                          rng.uniform(60, 130), rng.uniform(0, 2 * math.pi),
                          base=STEEL * 0.25, toward=(0, 1), rim_colour=AMBER)
        img = dot(img, x, y, 5, AMBER, gain=2, halo=24)
    cx, cy, length, angle = 820, 560, 1050, math.radians(176)
    # The broadcast, rolling out from the halo.
    R = Layer()
    for k in range(1, 7):
        R.ring(cx, cy - 170, 140 + k * 120, 50 + k * 45, 3, 0.9 - k * 0.12)
    img = add(img, R.array() * 0.3 + glow(R.array(), 6, 0.4), GOLD)
    img, hull = lit_ship(img, 'sleek', cx, cy, length, angle, base=np.array([0.42, 0.4, 0.36]),
                         toward=(0, -1), rim_colour=GOLD)
    # Holed from bow to stern, and burning where it's holed.
    for u in (-0.32, -0.12, 0.05, 0.22, 0.36):
        x, y = along(cx, cy, length, angle, u, rng.uniform(-0.04, 0.04))
        hole = np.hypot((XX - x) / rng.uniform(30, 55), (YY - y) / rng.uniform(14, 24)) + \
            (noise(rng, 5) - 0.5) * 0.6 < 1
        img = over(img, hole * hull, np.array([0.02, 0.01, 0.01]))
        img = add(img, glow(hole * hull, 10, 1.2), AMBER)
    halo = Layer()
    halo.ring(cx, cy - 170, 150, 46, 10)
    ring_ = halo.array()
    img = add(img, ring_ * 1.4 + glow(ring_, 16, 2), GOLD)
    img = screen(img, 70, 690, 540, 970, concept('icon_11'), tint=GOLD,
                 caption='SHINING-HEAD  ·  ALL CHANNELS', bar=np.array([0.35, 0.25, 0.04]))
    finish(img, 'lane_ascension', rng, grain=0.02)


SCENES = {f.__name__: f for f in (
    toll, wreck, exclusion, smuggler, leak, quiet, convoy, shakedown, duel, foundry, nobody,
    ascension)}

if __name__ == '__main__':
    scene_main(SCENES, 'lane mockups')
