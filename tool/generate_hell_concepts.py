"""Procedural concept mockups of Hell in brawl mode, and of Satan, who comes
for the captain at the end. They are the backdrops of those events.

Proof-of-concept placeholders, not final art. Writes
concept_art/hell_<scene>_ai_generated.png (see the naming rule in
CLAUDE.md); tool/generate_event_art.py cuts the event backdrops from them.

    python3 tool/generate_hell_concepts.py          # every scene
    python3 tool/generate_hell_concepts.py satan    # just these

Hell's space is an amber, alcoholic murk (lore/The-Mourner.md). Demons are
Lovecraftian, every native of Hell, in all shapes and sizes (lore/How the
species look.md). The scenes, from lib/game_engine/brawl/events/
hell_events.dart and finale_events.dart:

- flesh (hell_flesh): something enormous, dead, its flesh metal and its
  blood a fine vintage, heavy elements glittering in every wound.
- swarm (hell_swarm): a cloud of loose teeth with no jaws, turning as one.
- still (hell_still): the sea thin and hot, boiling off the hull in
  sheets, and the coolant loops condensing it.
- clocks (hell_clocks): every clock running backwards, and something out
  in the murk, ticking.
- barrier (hell_barrier): far off, a gateway pipe's blue barrier through
  Hell, bitten through in places.
- herald (hell_herald): a demon lord's herald, armoured in the hulls of the
  ships it has eaten, lesser things scattering.
- satan (satan): the dark gone red, and Satan, built from the wrecks of the
  gatecrash: Havi plating, Republic guns, a hull of living metal, his
  tractor beam already on you.

Needs numpy, scipy and Pillow.
"""

import math

import numpy as np
from scipy import ndimage

from concept_kit import (
    AMBER, BRANDY, CRIMSON, CYAN, GOLD, H, HOT, ICE, RED, STEEL, VOID, W, XX, YY, Layer, add,
    along, beam, bezier, card_art, clock, dot, finish, glow, hell, motes, murk, noise, over,
    paste, rim, scene_main, ship, ship_points, silhouette, smooth, solid, tooth)

FLESH = np.array([0.32, 0.12, 0.1])
CHROME = np.array([0.55, 0.5, 0.48])


def tube(L, pts, r0, r1):
    """A body along [pts], from [r0] thick to [r1]."""
    for k, (x, y) in enumerate(pts):
        r = r0 + (r1 - r0) * k / (len(pts) - 1)
        L.ellipse(x, y, r, r)


def emboss(mask, toward, sigma=18, shift=20):
    """Light on a rounded body: brighter on the side facing [toward]."""
    soft = ndimage.gaussian_filter(mask, sigma)
    lx, ly = toward
    moved = np.roll(np.roll(soft, round(ly * shift), axis=0), round(lx * shift), axis=1)
    return np.clip((soft - moved) * 4 + 0.5, 0, 1) * mask


# 1. Metallic flesh ---------------------------------------------------------------------------
# Something enormous died here: a carcass as long as a station, ribbed and
# spined, its flesh metal and its blood brandy, every wound glittering.
# Your ship is very small beside it.
def flesh():
    rng = np.random.default_rng(5050)
    img = hell(rng)
    spine = bezier((80, 640), (420, 300), (980, 980), (1680, 520), 120)
    radius = [330 * (1 - k / 119) ** 0.8 + 40 for k in range(120)]
    B = Layer()
    for (x, y), r in zip(spine, radius):
        B.ellipse(x, y, r, r * 0.8)
    for k in range(4, 110, 7):  # spines along its back
        (x0, y0), (x1, y1) = spine[k], spine[k + 1]
        nx, ny = y0 - y1, x1 - x0
        n = math.hypot(nx, ny) or 1
        nx, ny = nx / n, ny / n
        if ny > 0:
            nx, ny = -nx, -ny
        r = radius[k] * 0.8
        B.poly([(x0 + nx * r - ny * 18, y0 + ny * r + nx * 18), (x0 + nx * (r + 90 * radius[k] / 370),
                y0 + ny * (r + 90 * radius[k] / 370)), (x0 + nx * r + ny * 18, y0 + ny * r - nx * 18)])
    body = B.array()
    light = emboss(body, (-0.3, -1), 40, 40)
    img = over(img, body, np.array([0.06, 0.035, 0.035]))
    img = add(img, body * light ** 1.5 * 0.55, CHROME)
    img = add(img, body * (1 - light) * 0.15, FLESH)
    sheen = 0.5 + 0.5 * np.sin((XX * 0.4 + YY) / 18 + noise(rng, 30) * 10)
    img = add(img, body * light ** 4 * sheen * 0.4, np.array([1.0, 0.9, 0.85]))
    # Ribs: grooves around the body.
    G = Layer()
    for k in range(6, 116, 6):
        (x0, y0), (x1, y1) = spine[k], spine[k + 1]
        nx, ny = y0 - y1, x1 - x0
        n = math.hypot(nx, ny) or 1
        r = radius[k] * 0.95
        G.line([(x0 - nx / n * r, y0 - ny / n * r * 0.8), (x0 + nx / n * r, y0 + ny / n * r * 0.8)], 5)
    grooves = ndimage.gaussian_filter(G.array(), 2) * body
    img = over(img, grooves * 0.7, np.array([0.04, 0.02, 0.02]))
    # Its eye, long dark.
    hx, hy = spine[6]
    img = over(img, (np.hypot((XX - hx - 60) / 60, (YY - hy + 40) / 22) < 1) * 1.0, np.array([0.02, 0.0, 0.0]))
    # The wounds, wet, glittering, weeping brandy.
    for t in (0.25, 0.45, 0.66, 0.82):
        k = int(t * 119)
        x, y = spine[k]
        y -= radius[k] * 0.3
        gash = np.hypot((XX - x) / (radius[k] * 0.45), (YY - y) / 22) + (noise(rng, 6) - 0.5) * 0.5 < 1
        img = over(img, gash * body, BRANDY * 0.7)
        img = add(img, glow(gash * body, 14, 0.8), AMBER * 0.8)
        for _ in range(16):
            img = dot(img, x + rng.normal(0, radius[k] * 0.2), y + rng.normal(0, 12), 1.4, HOT, gain=2.5,
                      halo=4)
        for _ in range(7):  # brandy drifting off in drops
            img = dot(img, x + rng.uniform(-80, 80), y - rng.uniform(40, 200), rng.uniform(2, 5), AMBER,
                      gain=1.2, halo=8)
    S = Layer()
    ship(S, 'sleek', 900, 150, 110, math.radians(160))
    img = solid(img, S.array(), STEEL * 0.4, (-0.3, -1), HOT, 0.9, k=2)
    finish(img, 'hell_flesh', rng, grain=0.02)


# 2. Teeth in the dark ---------------------------------------------------------------------------
# A cloud of loose teeth, no jaws to hold them, wheeling around and coming
# at you as one.
def swarm():
    rng = np.random.default_rng(5151)
    img = hell(rng, strength=0.9)
    T = Layer()
    cx, cy = 820, 470
    for k in range(420):
        t = rng.uniform(0, 1)
        a = t * 5 * math.pi + rng.normal(0, 0.25)
        r = 30 + 620 * t ** 1.3 + rng.normal(0, 25)
        x, y = cx + math.cos(a) * r * 1.25, cy + math.sin(a) * r * 0.75
        size = 6 + 60 * t ** 1.6 * rng.uniform(0.7, 1.2)
        tooth(T, x, y, size, a + math.pi / 2 + rng.normal(0, 0.3))
    teeth = T.array()
    img = over(img, teeth, np.array([0.75, 0.7, 0.62]))
    img = add(img, rim(teeth, (-0.3, -1), 2) * 0.6, HOT)
    img = over(img, np.clip(teeth - ndimage.gaussian_filter(teeth, 2), 0, 1) * 0.4,
               np.array([0.2, 0.12, 0.08]))
    img = add(img, glow(np.hypot(XX - cx, YY - cy) < 50, 80, 0.8), BRANDY)
    finish(img, 'hell_swarm', rng, grain=0.02)


# 3. The still -------------------------------------------------------------------------------------
# The sea is thin and hot here and boils off the hull in sheets. The
# coolant loops along the hull condense it into something very strong.
def still():
    rng = np.random.default_rng(5252)
    img = murk(rng, BRANDY * 0.4, AMBER * 0.9, 1.3)
    img = motes(img, rng, 900, HOT * 0.5)
    hull = smooth(0, 3, np.hypot((XX - 768) / 1.05, YY - 1900) - 1250)
    hull = 1 - hull
    img = over(img, hull, np.array([0.05, 0.045, 0.045]))
    img = add(img, rim(hull, (0, -1), 4) * 1.4, HOT)
    # Sheets of vapour boiling off it, streaming back.
    V = Layer()
    for _ in range(70):
        x = rng.uniform(-100, 1600)
        y0 = 1900 - math.sqrt(max(0, 1250 ** 2 - ((x - 768) / 1.05) ** 2)) - 4
        pts = bezier((x, y0), (x - 60, y0 - 120), (x - 260, y0 - 200), (x - 520, y0 - rng.uniform(200, 380)), 20)
        V.line(pts, rng.uniform(3, 14), rng.uniform(0.2, 0.6))
    vapour = ndimage.gaussian_filter(V.array(), 8)
    img = add(img, vapour * 1.2, HOT * 0.8)
    # The coolant loops, and the tank they fill.
    P = Layer()
    for k in range(3):
        pts = [(x, 1900 - math.sqrt(max(0, 1150 ** 2 - ((x - 768) / 1.05) ** 2)) + k * 30 - 30)
               for x in range(-20, 1560, 20)]
        P.line(pts, 14)
    pipes = P.array()
    img = solid(img, pipes, STEEL * 0.5, (0, -1), CYAN, 0.8, shade=0.2)
    tx, ty = 1150, 760
    tank = np.hypot((XX - tx) / 110, (YY - ty) / 60) < 1
    img = over(img, tank * 1.0, BRANDY)
    img = add(img, glow(tank, 30, 1.5), AMBER)
    for k in range(6):
        img = dot(img, tx - 60 + k * 24, ty - 80 - (k % 2) * 30, 4, AMBER, gain=1.5, halo=8)
    finish(img, 'hell_still', rng, grain=0.02)


# 4. Running backwards --------------------------------------------------------------------------
# Every clock on the bridge runs backwards. Out in the murk, among clocks
# drifting like flotsam, something is ticking.
def clocks():
    rng = np.random.default_rng(5353)
    img = hell(rng)
    for _ in range(26):
        r = rng.uniform(10, 90) ** 1.0
        x, y = rng.uniform(80, 1460), rng.uniform(60, 980)
        if math.hypot(x - 768, y - 500) < 300:
            continue
        img = clock(img, x, y, r, rng.uniform(0, 12), rng.uniform(0, 60))
        img = add(img, glow(np.hypot(XX - x, YY - y) < r, r * 0.5, 0.3), GOLD * 0.5)
    rgb, alpha = card_art('hell_clock')
    img = add(img, glow(np.hypot(XX - 768, YY - 500) < 160, 90, 1.2), BRANDY * 1.5)
    img = paste(img, rgb, alpha, 768, 500, 520, gain=1.4)
    T = Layer()
    for k in range(3):
        T.ring(768, 500, 300 + k * 70, 300 + k * 70, 2, 0.5 - k * 0.15)
    img = add(img, T.array() * 0.6, GOLD)
    finish(img, 'hell_clocks', rng, grain=0.02)


# 5. A glow in the murk -------------------------------------------------------------------------
# Far off, the faint blue line of a gateway pipe cuts through Hell.
# Something has been chewing on it, and there are holes.
def barrier():
    rng = np.random.default_rng(5454)
    img = hell(rng, strength=1.1)
    start, end = (-100, 760), (1640, 330)
    P = Layer()
    for k in range(40):
        t = k / 39
        x = start[0] + (end[0] - start[0]) * t
        y = start[1] + (end[1] - start[1]) * t
        r = 70 * (1 - t) + 10
        P.ellipse(x, y, r, r)
    pipe = P.array()
    bites = Layer()
    marks = []
    for t in (0.2, 0.38, 0.55, 0.7):
        x = start[0] + (end[0] - start[0]) * t
        y = start[1] + (end[1] - start[1]) * t
        r = 70 * (1 - t) + 10
        bites.ellipse(x, y - r * 0.8, r * 0.55, r * 0.5)
        marks.append((x, y - r * 0.8, r))
    holes = bites.array()
    pipe = np.clip(pipe - holes, 0, 1)
    img = add(img, pipe * 0.14, ICE * 0.6)
    edge = np.clip(pipe - ndimage.gaussian_filter(pipe, 3), 0, 1)
    img = add(img, edge * 2 + glow(edge, 12, 2.0), ICE)
    T = Layer()
    for x, y, r in marks:
        for k in range(10):
            a = math.pi + k / 9 * math.pi
            px, py = x + math.cos(a) * r * 0.6, y + math.sin(a) * r * 0.55 + r * 0.5
            tooth(T, px, py, r * 0.18, a + math.pi)
    img = add(img, T.array() * 0.6, ICE * 0.8)
    img = add(img, glow(holes * 1.0, 14, 0.6), ICE * 0.5)
    finish(img, 'hell_barrier', rng, grain=0.02)


# 6. A herald ----------------------------------------------------------------------------------------
# A demon lord's herald, armoured in the hulls of the ships it has eaten.
# Lesser things scatter from it.
def herald():
    rng = np.random.default_rng(5555)
    img = hell(rng)
    cx, cy = 820, 500
    d = np.hypot((XX - cx) / 480, (YY - cy) / 330) + (noise(rng, 40) - 0.5) * 0.4
    body = smooth(1.0, 0.96, d)
    T = Layer()
    for k in range(9):  # tentacles trailing off
        a = rng.uniform(0, 2 * math.pi)
        x0, y0 = cx + math.cos(a) * 380, cy + math.sin(a) * 250
        pts = bezier((x0, y0), (x0 + math.cos(a) * 200, y0 + math.sin(a) * 160),
                     (x0 + math.cos(a + 0.8) * 400, y0 + math.sin(a + 0.8) * 300),
                     (x0 + math.cos(a + 0.3) * 650, y0 + math.sin(a + 0.3) * 450), 30)
        for j, (x, y) in enumerate(pts):
            T.ellipse(x, y, 40 * (1 - j / 30) + 3, 40 * (1 - j / 30) + 3)
    body = np.clip(body + T.array(), 0, 1)
    img = over(img, body, np.array([0.1, 0.03, 0.03]))
    img = add(img, body * emboss(body, (-0.4, -1)) * 0.25, FLESH)
    veins = np.exp(-((noise(rng, 9) - 0.5) / 0.02) ** 2) * body
    img = add(img, veins * 0.25, CRIMSON)
    # The armour: hulls of eaten ships, stuck all over it.
    A = Layer()
    for _ in range(26):
        a, r = rng.uniform(0, 2 * math.pi), rng.uniform(0, 1) ** 0.6
        x, y = cx + math.cos(a) * r * 420, cy + math.sin(a) * r * 280
        ship(A, str(rng.choice(['freighter', 'gunship', 'heavy', 'sleek', 'warship'])), x, y,
             rng.uniform(110, 230), rng.uniform(0, 2 * math.pi))
    armour = A.array() * smooth(1.05, 0.9, d)
    img = solid(img, armour, STEEL * 0.5, (-0.4, -1), HOT, 0.9, k=2, shade=0.4)
    for k in range(5):
        a = -0.6 + k * 0.3
        img = dot(img, cx + math.sin(a) * 230, cy - 60 + abs(a) * 50, 7, HOT, gain=3, halo=20)
    # Lesser things fleeing, trailing.
    for _ in range(14):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(600, 760)
        x, y = cx + math.cos(a) * r, cy + math.sin(a) * r * 0.65
        L = Layer()
        L.line([(x, y), (x - math.cos(a) * 60, y - math.sin(a) * 40)], 3, 0.5)
        L.ellipse(x, y, 9, 6)
        img = silhouette(img, L.array(), (-0.4, -1), colour=np.array([0.03, 0.01, 0.01]),
                         rim_colour=AMBER, rim_gain=0.6, k=2)
    finish(img, 'hell_herald', rng, grain=0.02)


# 7. Satan ---------------------------------------------------------------------------------------------
# The dark goes red from end to end. Something enormous has come up out of
# Hell for you, built from the wrecks of the gatecrash: Havi plating,
# Republic guns, a hull of living metal. His tractor beam has you.
def satan():
    rng = np.random.default_rng(6666)
    img = murk(rng, VOID + 0.01, np.array([0.6, 0.05, 0.04]), 1.4)
    img = add(img, smooth(700, 0, YY) * 0.12, CRIMSON)  # the red, end to end
    img = motes(img, rng, 900, RED * 0.5)
    cx, cy = 768, 470
    S = Layer()
    # A great wedge, point down, shoulders out, crowned with horns.
    S.poly([(cx - 560, cy - 90), (cx - 330, cy - 200), (cx + 330, cy - 200), (cx + 560, cy - 90),
            (cx + 250, cy + 230), (cx, cy + 360), (cx - 250, cy + 230)])
    for side in (-1, 1):
        horn = bezier((cx + side * 280, cy - 170), (cx + side * 470, cy - 260),
                      (cx + side * 560, cy - 360), (cx + side * 470, cy - 455), 40)
        tube(S, horn, 80, 5)
        S.poly([(cx + side * 520, cy - 90), (cx + side * 760, cy - 10), (cx + side * 470, cy + 10)])
    hulk = S.array()
    living = emboss(hulk, (0, -1), 50, 50)
    img = over(img, hulk, np.array([0.035, 0.018, 0.018]))
    img = add(img, hulk * living ** 1.4 * 0.4, CHROME * 0.8)
    keel = np.exp(-((XX - cx) / 30) ** 2) * hulk * smooth(cy - 200, cy + 360, YY)
    img = add(img, keel * 0.15, CHROME)
    veins = np.exp(-((noise(rng, 10) - 0.5) / 0.012) ** 2) * hulk
    img = add(img, veins * 0.22, CRIMSON)  # the living metal's veins
    # Havi plating, gold, bolted across his shoulders in rows.
    G = Layer()
    for row in range(3):
        y = cy - 165 + row * 70
        half = 520 - row * 110
        for x in np.arange(cx - half, cx + half, 96):
            if abs(x - cx) < 50:
                continue
            w, h = rng.uniform(70, 86), rng.uniform(44, 56)
            G.poly([(x, y), (x + w, y + rng.uniform(-6, 6)), (x + w - 8, y + h), (x + 8, y + h)])
    plates = G.array() * hulk
    img = solid(img, plates, GOLD * 0.55, (0, -1), HOT, 0.9, k=2, shade=0.35)
    # Republic guns, run out under the plating and down the flanks.
    Gn = Layer()
    muzzles = []
    for side in (-1, 1):
        for k in range(5):
            x = cx + side * (120 + k * 70)
            y = cy + 40 + k * 18
            a = math.pi / 2 + side * (0.25 + k * 0.12)
            length = 120 + (4 - k) * 20
            Gn.line([(x, y), (x + math.cos(a) * length, y + math.sin(a) * length)], 14 - k)
            muzzles.append((x + math.cos(a) * length, y + math.sin(a) * length))
    guns = Gn.array()
    img = solid(img, guns, STEEL * 0.4, (0, -1), RED, 0.8, k=2, shade=0.2)
    for x, y in muzzles:
        img = dot(img, x, y, 4, RED, gain=2, halo=12)
    # His eyes, and the tractor beam from the maw at his point.
    for side in (-1, 1):
        eye = np.hypot((XX - cx - side * 140) / 70, (YY - cy + 80 + abs(XX - cx - side * 140) * 0.25) / 9) < 1
        img = over(img, eye * 1.0, HOT)
        img = add(img, glow(eye, 18, 2.5), RED)
    img = add(img, beam((cx, cy + 320), 0.26, 900, math.pi / 2, 26) * 0.75, RED)
    img = dot(img, cx, cy + 310, 20, HOT, gain=3, halo=50)
    img = dot(img, cx, cy + 310, 44, RED, gain=1.2, halo=100)
    finish(img, 'hell_satan', rng, grain=0.02)


SCENES = {f.__name__: f for f in (flesh, swarm, still, clocks, barrier, herald, satan)}

if __name__ == '__main__':
    scene_main(SCENES, 'Hell mockups')
