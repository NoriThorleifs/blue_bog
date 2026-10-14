"""Procedural concept mockups of the human colony's events in brawl mode:
the war for Neo Terra, the colony's people, and news of the other colony
ships. They are the backdrops of those events.

Proof-of-concept placeholders, not final art. Writes
concept_art/colony_<scene>_ai_generated.png (see the naming rule in
CLAUDE.md); tool/generate_event_art.py cuts the event backdrops from them.
The workshops' events are in generate_workshop_concepts.py.

    python3 tool/generate_colony_concepts.py          # every scene
    python3 tool/generate_colony_concepts.py draft    # just these

The scenes, from the events in lib/game_engine/brawl/events/:

- volunteers (gift_boarders): a hundred humans in vacuum suits at the
  airlock, rifles slung, about to board the enemy. The first few are
  already jetting across.
- draft (neo_terra_war): a Neo Terran transport at the dock, the colony
  walking up its ramp with kit bags, the families waving. Two of Neo Terra's
  soldiers stand at the ramp in the helmets that lock at the back
  (lore/the-helmet.md).
- veterans (veterans_home): the transport back, the veterans walking off it
  into a crowd that came to meet them.
- helmet (the_helmet): an old soldier curled up in a corridor, hands over
  his ears, his helmet still locked on, the explosions only in his head.
- strike (colony_strike): placards in the corridor, and the hull patch
  left half done.
- headcount (hell_headcount): the colony lined up to be counted, the board
  saying there are more of them than went into Hell, and a few red eyes.
- engineer (wrong_warp_offer): the quiet engineer at the holo-table,
  drawing a line into a gateway at an angle no sane captain would take.
- gor_news, tern_news (gor_colony_mutiny, tern_colony_stays): the relay on
  the bridge screen.
- kepler (kepler_refused): the blue bog, the heavy world under a blue sun,
  and the old observation platform watching it.
- elephant (elephant_crate): a crate stamped with the House of the
  Elephant's mark, dropped toward an asteroid where someone is building.
- gravity (petition_gravity): the colony's centrifuge habitat, spinning.
- collection (gift_collection): the colony's collection for its captain.
- secession (secession): the colony voting to leave at the end, drifting
  away from the ship to Lady Idun's flagship.

Humans are just humans (lore/How the species look.md): suits, helmets and
kit, nothing alien. Needs numpy, scipy and Pillow.
"""

import math

import numpy as np
from scipy import ndimage

from concept_kit import (
    AMBER, CYAN, DARK_STEEL, GOLD, H, HAZARD, HOT, ICE, RED, SILHOUETTE, STEEL, W, XX, YY,
    Layer, add, beam, bezier, concept, crate, crouched, dot, elephant, finish, glow, human,
    interior, noise, over, planet, rim, ring, scene_main, screen, ship, silhouette, smooth,
    solid, space)


# 1. Volunteers ---------------------------------------------------------------------
# From behind the crowd at the airlock. The door is open on the dark, the
# enemy's lights are in it, and the first volunteers are already crossing.
def volunteers():
    rng = np.random.default_rng(505)
    x0, y0, x1, y1 = 560, 150, 976, 610  # the open door
    vx, vy = 768, 420  # where the bay's lines meet
    # The bay: dark steel, lighter toward the door.
    base = np.array([0.03, 0.038, 0.05])
    near = 1 - smooth(0, 900, np.hypot(XX - vx, (YY - vy) * 1.3))
    img = base + near[..., None] * np.array([0.06, 0.08, 0.1])
    # Ribs along the walls and ceiling, running into the distance.
    L = Layer()
    for k in range(-9, 10):
        L.line([(vx + k * 18, vy - 6), (vx + k * 260, -40)], 2.5, 0.5)
        L.line([(vx + k * 18, vy + 6), (vx + k * 300, H + 40)], 2, 0.35)
    lines = L.array() * (1 - smooth(0, 20, np.minimum(
        np.maximum(x0 - 40 - XX, XX - x1 - 40), np.maximum(y0 - 40 - YY, YY - y1 - 40)) * -1))
    img = add(img, lines * 0.08, STEEL)
    for k in (-1, 1):  # ceiling light strips
        L = Layer()
        L.line([(vx + k * 60, y0 - 70), (vx + k * 420, -10)], 10)
        strip = L.array()
        img = add(img, strip * 1.2 + glow(strip, 14, 1.4), ICE * 0.6)
    # The door: space beyond, a hazard-striped frame around it.
    door = np.zeros((H, W), np.float32)
    door[y0:y1, x0:x1] = 1
    door = ndimage.gaussian_filter(door, 0.8)
    beyond = space(rng, nebula=np.array([0.12, 0.1, 0.25]), stars=900)
    sun = np.exp(-(((XX - 900) ** 2 + (YY - 205) ** 2) / 26 ** 2))
    beyond = add(beyond, sun * 3 + glow(sun > 0.2, 60, 6), HOT)
    # The enemy, side on, lit from the sun behind it.
    S = Layer()
    S.poly([(690, 352), (760, 330), (860, 322), (905, 330), (918, 352), (905, 372), (860, 380), (760, 374)])
    S.poly([(800, 326), (850, 290), (870, 292), (850, 328)])
    S.poly([(800, 376), (850, 410), (870, 408), (850, 372)])
    enemy = S.array()
    beyond = over(beyond, enemy, np.array([0.03, 0.03, 0.035]))
    beyond = add(beyond, rim(enemy, (0.6, -1)) * 1.2, ICE * 0.8)
    for lx, ly, c in ((700, 352, RED), (858, 293, RED), (858, 407, RED), (918, 352, AMBER)):
        beyond = dot(beyond, lx, ly, 2.5, c, gain=3, halo=8)
    # The first volunteers, already crossing on their thrusters.
    F = Layer()
    plumes = Layer()
    for k in range(7):
        fx = 610 + k * 38 + rng.uniform(-10, 10)
        fy = 470 - k * 14 + rng.uniform(-30, 30)
        fh = 30 - k * 2.2
        human(F, fx, fy, fh, suit=True, rifle=True)
        plumes.line([(fx - fh * 0.15, fy - fh * 0.4), (fx - fh * 1.1, fy + fh * 0.05)], fh * 0.16,
                    0.8)
    crossing = F.array()
    trail = plumes.array()
    beyond = add(beyond, glow(trail, 3, 1.5) + trail * 0.6, ICE)
    beyond = over(beyond, crossing, SILHOUETTE)
    beyond = add(beyond, rim(crossing, (0.6, -1), 2) * 0.9, ICE * 0.7)
    img = img * (1 - door[..., None]) + beyond * door[..., None]
    frame = np.zeros((H, W), np.float32)
    frame[y0 - 36:y1 + 36, x0 - 36:x1 + 36] = 1
    frame = ndimage.gaussian_filter(frame, 0.8) * (1 - door)
    stripes = (((XX + YY) // 26) % 2 == 0).astype(np.float32)
    img = over(img, frame, np.array([0.05, 0.05, 0.055]))
    img = add(img, frame * stripes * 0.35, HAZARD)
    img = add(img, np.clip(door - ndimage.gaussian_filter(door, 2), 0, 1) * 2, ICE)
    # Light spilling out of the door, across the floor and the crowd.
    img = add(img, glow(door, 90, 0.7), ICE * 0.35)
    spill = np.exp(-(((XX - vx) / 520) ** 2 + ((YY - y1) / 260) ** 2)) * (YY > y1)
    img = add(img, spill * 0.35, ICE * 0.5)
    # The crowd, back rows first. Everyone in a suit, every rifle slung.
    rows = [(695, 118, 52, 500, 1040), (742, 160, 66, 420, 1120), (815, 225, 92, 330, 1220),
            (925, 330, 150, 290, 1290), (1100, 480, 0, 0, 0)]
    for y, h, step, left, right in rows:
        L = Layer()
        xs = [140, 1400] if step == 0 else np.arange(left, right, step)
        lamps = []
        for x in xs:
            x = x + rng.uniform(-0.25, 0.25) * max(step, 40)
            hh = h * rng.uniform(0.93, 1.06)
            human(L, x, y + rng.uniform(-6, 6), hh, suit=True, rifle=True)
            lamps.append((x + hh * 0.06, y - hh * 0.98))
        crowd = L.array()
        img = over(img, crowd, SILHOUETTE)
        side = np.where(XX < vx, 1.0, -1.0)
        edge = np.where(XX < vx, rim(crowd, (1, -0.6)), rim(crowd, (-1, -0.6)))
        reach = 0.4 + 0.9 * (1 - smooth(0, 700, np.abs(XX - vx))) * (side != 0)
        img = add(img, edge * reach * 0.8, ICE * 0.75)
        for lx, ly in lamps:
            img = dot(img, lx, ly, h * 0.012, CYAN, halo=h * 0.03)
    finish(img, 'colony_volunteers', rng, grain=0.02)


# 2. The draft ---------------------------------------------------------------------
# A hangar at the dock. The transport's ramp glows; the queue walks up it
# with kit bags; the families wave from behind the railing.
def draft():
    rng = np.random.default_rng(606)
    base = np.array([0.045, 0.035, 0.03])
    img = base + (1 - smooth(200, 1100, YY))[..., None] * np.array([0.03, 0.025, 0.02])
    # The back wall's long window on the dark, with its mullions.
    win = np.zeros((H, W), np.float32)
    win[110:330, 70:840] = 1
    beyond = space(rng, nebula=np.array([0.1, 0.12, 0.2]), stars=700)
    img = img * (1 - win[..., None]) + beyond * win[..., None]
    M = Layer()
    for x in range(70, 841, 110):
        M.rect(x - 5, 105, x + 5, 335)
    M.rect(64, 100, 846, 112)
    M.rect(64, 326, 846, 338)
    mullions = M.array()
    img = over(img, mullions, np.array([0.06, 0.05, 0.045]))
    # Floodlights from the ceiling.
    for lx in (230, 560, 1290):
        cone = beam((lx, 20), 0.2, 900, math.pi / 2, 28)
        img = add(img, cone * 0.18, GOLD)
        lamp = np.exp(-(((XX - lx) ** 2) / 22 ** 2 + ((YY - 22) ** 2) / 7 ** 2))
        img = add(img, lamp * 3 + glow(lamp > 0.3, 18, 2), HOT)
    # The transport: a heavy hull filling the right, its ramp down and lit.
    T = Layer()
    T.poly([(905, 200)] + bezier((905, 200), (960, 120), (1200, 100), (1560, 100), 20)
           + [(1560, 700), (1200, 700), (905, 660)])
    hull = T.array()
    shade = 0.5 + 0.5 * smooth(110, 700, YY)
    img = over(img, hull, np.array([0.09, 0.085, 0.08]) * 0.0 + 0.05)
    img = add(img, hull * shade * 0.04 * (0.6 + 0.4 * noise(rng, 20)), np.array([1, 0.95, 0.9]))
    P = Layer()
    for y in range(190, 700, 72):
        P.line([(910, y), (1560, y - 30)], 1.5, 0.6)
    for x in range(1000, 1560, 120):
        P.line([(x, 130), (x, 700)], 1.5, 0.5)
    img = add(img, P.array() * hull * 0.05, STEEL)
    img = add(img, rim(hull, (-1, -0.5), 3) * 0.7, GOLD * 0.7)
    stencil = Layer()
    stencil.text(1365, 440, 'NEO TERRA', 46)
    stencil.text(1365, 482, 'UNIVERSAL DRAFT  ·  TRANSPORT 9', 14)
    img = add(img, stencil.array() * hull * 0.4, np.array([0.95, 0.9, 0.8]))
    # Its engines, cold, above the ramp.
    for nx, ny, nr in ((1000, 265, 62), (1150, 245, 72), (1310, 230, 80)):
        bell = np.hypot(XX - nx, (YY - ny) / 0.92)
        img = over(img, smooth(nr, nr - 2, bell), np.array([0.025, 0.022, 0.02]))
        img = add(img, np.exp(-((bell - nr) / 3) ** 2) * 0.5, GOLD * 0.7)
        img = add(img, np.exp(-((bell - nr * 0.55) / 4) ** 2) * 0.12, STEEL)
    door = Layer()
    door.poly([(950, 380), (1150, 372), (1150, 650), (950, 655)])
    opening = door.array()
    img = over(img, opening, HOT * 0.9)
    img = add(img, glow(opening, 40, 1.2), GOLD)
    R = Layer()
    R.poly([(950, 655), (1150, 650), (1120, 770), (885, 778)])
    ramp = R.array()
    img = over(img, ramp, np.array([0.3, 0.24, 0.17]))
    img = add(img, ramp * smooth(780, 650, YY) * 0.6, GOLD)
    # The floor shines with it.
    pool = np.exp(-(((XX - 1000) / 420) ** 2 + ((YY - 800) / 120) ** 2)) * (YY > 700)
    img = add(img, pool * 0.45, GOLD * 0.8)
    # The railing, and the families behind it.
    fam = Layer()
    for k in range(17):
        x = 110 + k * 38 + rng.uniform(-12, 12)
        child = rng.random() < 0.3
        h = rng.uniform(62, 74) if child else rng.uniform(112, 128)
        human(fam, x, 700 + rng.uniform(-4, 4), h, child=child,
              wave=rng.choice([0, 1, 1, 2]))
    families = fam.array()
    img = over(img, families, SILHOUETTE * 2)
    img = add(img, rim(families, (1, -0.4), 2) * 0.45, GOLD * 0.8)
    rail = Layer()
    rail.line([(80, 640), (800, 640)], 6)
    rail.line([(80, 672), (800, 672)], 3)
    for x in range(80, 801, 90):
        rail.line([(x, 640), (x, 712)], 5)
    railing = rail.array()
    img = over(img, railing, np.array([0.08, 0.07, 0.06]))
    img = add(img, rim(railing, (0, -1), 2) * 0.7, GOLD)
    # The queue, from the foreground up the ramp and into the light.
    path = bezier((150, 1060), (480, 930), (760, 800), (1010, 700), 40)
    Q = Layer()
    for k, t in enumerate(np.linspace(0.0, 1.0, 19)):
        x, y = path[int(t * (len(path) - 1))]
        h = 250 * (1 - t) ** 1.3 + 72
        human(Q, x + rng.uniform(-8, 8), y, h, bag=True, walk=(k % 3) / 2, facing=1)
    queue = Q.array()
    img = over(img, queue, SILHOUETTE)
    img = add(img, rim(queue, (1, -0.35), 3) * 0.9, GOLD * 0.9)
    # Neo Terra's soldiers at the foot of the ramp, helmets locked on.
    G = Layer()
    for gx, facing in ((860, 1), (1180, -1)):
        human(G, gx, 790, 175, helmet=True, facing=facing)
        G.line([(gx + facing * 30, 655), (gx + facing * 34, 760)], 7)  # rifle, held upright
    guards = G.array()
    img = over(img, guards, SILHOUETTE)
    img = add(img, rim(guards, (0.3, -1), 3) * 0.8, GOLD)
    # Banner overhead.
    B = Layer()
    B.poly([(330, 30), (650, 30), (650, 230), (490, 260), (330, 230)])
    banner = B.array()
    img = over(img, banner, np.array([0.32, 0.05, 0.05]))
    words = Layer()
    words.text(490, 95, 'ALL HUMANS', 30)
    words.text(490, 140, 'OF FIGHTING AGE', 30)
    words.text(490, 195, 'REPORT', 36)
    img = add(img, words.array() * banner * 0.7, GOLD)
    finish(img, 'colony_draft', rng, grain=0.02)




# 3. Coming home ---------------------------------------------------------------------
# The transport is back, its ramp down in cold light. The veterans walk off
# it slowly, some still in their helmets, toward the crowd that came.
def veterans():
    rng = np.random.default_rng(808)
    img = interior(rng, base=np.array([0.03, 0.033, 0.042]), light=np.array([0.04, 0.05, 0.065]),
                   vx=560, vy=430)
    T = Layer()
    T.poly([(-10, 90), (560, 130), (700, 240), (700, 650), (-10, 700)])
    hull = T.array()
    img = solid(img, hull, np.array([0.08, 0.085, 0.095]), (1, -0.6), ICE, 0.6)
    S = Layer()
    S.text(140, 230, 'NEO TERRA', 46, anchor='lm')
    img = add(img, S.array() * hull * 0.25, np.array([0.9, 0.9, 0.95]))
    D = Layer()
    D.poly([(250, 330), (470, 325), (470, 620), (250, 625)])
    door = D.array()
    img = over(img, door, ICE * 0.9)
    img = add(img, glow(door, 50, 1.4), ICE * 0.7)
    R = Layer()
    R.poly([(250, 625), (470, 620), (590, 770), (150, 778)])
    img = over(img, R.array(), np.array([0.14, 0.16, 0.2]))
    pool = np.exp(-(((XX - 380) / 380) ** 2 + ((YY - 800) / 110) ** 2)) * (YY > 700)
    img = add(img, pool * 0.4, ICE * 0.6)
    # The veterans, coming off one by one.
    V = Layer()
    for x, y, h, helmet in ((330, 650, 85, True), (380, 700, 115, False), (460, 760, 160, True),
                            (560, 840, 225, False), (700, 930, 300, True)):
        human(V, x, y, h, helmet=helmet, bag=not helmet, walk=0.3, facing=1)
    img = silhouette(img, V.array(), (-1, -0.5), rim_colour=ICE, rim_gain=1.0)
    # The crowd that came, lit warm, some of them waving.
    for lx in (1050, 1350):
        img = add(img, beam((lx, 10), 0.22, 950, math.pi / 2, 28) * 0.16, GOLD)
        img = dot(img, lx, 14, 8, HOT, gain=3)
    C = Layer()
    for y, h, step, left, right in ((760, 170, 62, 880, 1520), (850, 230, 88, 850, 1540),
                                    (980, 320, 140, 900, 1560)):
        for x in np.arange(left, right, step):
            human(C, x + rng.uniform(-14, 14), y + rng.uniform(-6, 6), h * rng.uniform(0.9, 1.05),
                  wave=int(rng.choice([0, 0, 1, 2])), child=rng.random() < 0.15)
    img = silhouette(img, C.array(), (0.3, -1), rim_colour=GOLD, rim_gain=0.8)
    B = Layer()
    B.rect(880, 60, 1440, 150)
    banner = B.array()
    img = over(img, banner, np.array([0.05, 0.12, 0.3]))
    words = Layer()
    words.text(1160, 106, 'WELCOME HOME', 52)
    img = add(img, words.array() * 0.8, GOLD)
    finish(img, 'colony_veterans', rng, grain=0.02)


# 4. The old soldier ------------------------------------------------------------------
# A long dim corridor. He is curled up against the wall, hands over his
# ears, the helmet still locked on. The flashes on the walls aren't there.
def helmet():
    rng = np.random.default_rng(909)
    img = interior(rng, base=np.array([0.018, 0.02, 0.026]), light=np.array([0.035, 0.04, 0.05]),
                   vx=700, vy=430, ribs=0.12)
    img = dot(img, 700, 430, 18, ICE * 0.6, gain=1.5, halo=80)  # the far end
    for k, (x, y) in enumerate(((420, 300), (980, 360), (560, 620), (1180, 240))):
        flash = np.exp(-(((XX - x) ** 2 + (YY - y) ** 2) / (90 + 30 * k) ** 2))
        img = add(img, flash * 0.12, AMBER * (0.6 + 0.2 * k))
    # A strip light overhead, the only real light.
    L = Layer()
    L.line([(780, 120), (1150, -10)], 12)
    strip = L.array()
    img = add(img, strip * 1.1 + glow(strip, 16, 1.2), ICE * 0.5)
    img = add(img, beam((960, 60), 0.35, 1000, math.radians(100), 30) * 0.12, ICE)
    # The wall he has his back to.
    wall = Layer()
    wall.poly([(0, 0), (560, 250), (560, 610), (0, 1024)])
    img = solid(img, wall.array(), np.array([0.05, 0.055, 0.065]), (1, -0.3), ICE, 0.3, shade=0.4)
    M = Layer()
    sit = 470
    hx, hy = crouched(M, 600, 960, sit)
    head = sit * 0.11
    M.ellipse(hx + head * 0.1, hy - head * 0.2, head * 1.32, head * 1.15)  # the helmet
    # Its neck guard flares out at the back, where it locks.
    M.poly([(hx - head * 0.2, hy - head * 0.3), (hx - head * 1.55, hy + head * 0.9),
            (hx - head * 0.4, hy + head * 1.0)])
    man = M.array()
    img = solid(img, man, np.array([0.06, 0.065, 0.07]), (0.6, -1), ICE, 1.0)
    img = dot(img, hx - head * 1.2, hy + head * 0.65, 3.2, RED, gain=3, halo=10)  # the lock
    floor = smooth(860, 1024, YY) * np.exp(-((XX - 960) / 400) ** 2)
    img = add(img, floor * 0.06, ICE)
    finish(img, 'colony_helmet', rng, grain=0.03)


# 5. Strike -------------------------------------------------------------------------------
# The corridor is full of placards. Behind them, the patch they stopped
# welding, half the plates still stacked by the wall.
def strike():
    rng = np.random.default_rng(1010)
    img = interior(rng, base=np.array([0.035, 0.03, 0.03]), light=np.array([0.07, 0.055, 0.045]),
                   vx=768, vy=380)
    # The breach on the far wall, half patched, stars through the rest.
    hole = Layer()
    pts = []
    for k in range(18):
        a = k / 18 * 2 * math.pi
        r = 150 * rng.uniform(0.75, 1.15)
        pts.append((768 + math.cos(a) * r * 1.3, 330 + math.sin(a) * r))
    hole.poly(pts)
    breach = hole.array()
    stars = space(rng, stars=600)
    img = img * (1 - breach[..., None]) + stars * breach[..., None]
    P = Layer()
    for k in range(3):
        P.poly([(600 + k * 52, 190 + k * 8), (680 + k * 52, 186 + k * 8), (690 + k * 52, 470 - k * 10),
                (608 + k * 52, 474 - k * 10)])
    plates = P.array() * breach
    img = solid(img, plates, STEEL * 0.4, (0, -1), HAZARD, 0.5)
    img = add(img, rim(breach, (0, 1), 4) * 0.8, AMBER)
    # Tools down on the floor.
    T = Layer()
    for x in (300, 1200, 1320):
        T.line([(x, 1000), (x + 70, 975)], 10)
        T.ellipse(x + 85, 970, 18, 12)
    img = silhouette(img, T.array(), (0, -1), rim_colour=HAZARD, rim_gain=0.5)
    # The strikers.
    C = Layer()
    signs = Layer()
    words = Layer()
    for y, h, step, left, right, size in ((700, 170, 240, 260, 1300, 44), (900, 300, 240, 140, 1450, 74)):
        for x in np.arange(left, right, step):
            x += rng.uniform(-20, 20)
            human(C, x, y, h, sign=size)
            top = y - h * 0.8 - h * 0.34
            signs.rect(x - size * 0.8, top - size, x + size * 0.8, top)
            words.text(x, top - size * 0.62, 'ON', size * 0.32)
            words.text(x, top - size * 0.28, 'STRIKE', size * 0.3)
    img = silhouette(img, C.array(), (0, -1), rim_colour=GOLD, rim_gain=0.6)
    img = over(img, signs.array(), np.array([0.55, 0.5, 0.42]))
    img = over(img, words.array(), np.array([0.45, 0.04, 0.03]))
    img = add(img, beam((768, 0), 0.5, 1100, math.pi / 2, 40) * 0.1, GOLD)
    finish(img, 'colony_strike', rng, grain=0.02)


# 6. The headcount --------------------------------------------------------------------
# Out of Hell, the colony lines up to be counted. The board disagrees with
# the ship's books, and a few faces in the rows have red eyes.
def headcount():
    rng = np.random.default_rng(1111)
    img = interior(rng, base=np.array([0.05, 0.055, 0.065]), light=np.array([0.08, 0.09, 0.1]),
                   vx=768, vy=420)
    B = Layer()
    B.rect(470, 110, 1066, 330)
    board = B.array()
    img = over(img, board, np.array([0.01, 0.015, 0.02]))
    img = add(img, glow(board, 30, 0.3), CYAN * 0.4)
    text = Layer()
    text.text(768, 155, 'HEADCOUNT', 34)
    text.text(600, 225, 'WENT IN', 22)
    text.text(600, 275, '212', 44)
    text.text(936, 225, 'CAME OUT', 22)
    img = add(img, text.array() * 0.9, CYAN)
    over_ = Layer()
    over_.text(936, 275, '227', 44)
    img = add(img, over_.array() * 1.2, RED)
    C = Layer()
    eyes = []
    for y, h, step, left, right in ((720, 120, 58, 300, 1250), (780, 165, 78, 220, 1330),
                                    (870, 235, 110, 150, 1420), (1010, 340, 165, 80, 1500)):
        for x in np.arange(left, right, step):
            x += rng.uniform(-10, 10)
            hh = h * rng.uniform(0.94, 1.05)
            hx, hy = human(C, x, y + rng.uniform(-4, 4), hh)
            if rng.random() < 0.09:
                eyes.append((hx, hy, hh * 0.08))
    people = C.array()
    img = solid(img, people, np.array([0.035, 0.04, 0.05]), (0, -1), ICE, 0.7, shade=0.2)
    for hx, hy, head in eyes:
        for side in (-1, 1):
            img = dot(img, hx + side * head * 0.38, hy, max(1.2, head * 0.12), RED, gain=3,
                      halo=head * 0.4)
    finish(img, 'colony_headcount', rng, grain=0.02)


# 7. An idea about the next jump ------------------------------------------------------
# The quiet engineer at the holo-table, a gateway turning above it, and her
# line into it: steep, at full burn.
def engineer():
    rng = np.random.default_rng(1212)
    img = np.zeros((H, W, 3)) + np.array([0.012, 0.015, 0.022])
    gx, gy = 768, 250
    G = Layer()
    G.ring(gx, gy, 300, 104, 6)
    G.ring(gx, gy, 266, 88, 2, 0.6)
    for a in (math.pi / 2, math.pi / 2 + 2.09, math.pi / 2 + 4.19):
        G.line([(gx, gy), (gx + math.cos(a) * 266, gy + math.sin(a) * 88)], 2, 0.6)
    gate = G.array()
    img = add(img, gate * 0.9 + glow(gate, 10, 1.2), CYAN * 0.8)
    path = bezier((120, 30), (380, 40), (600, 140), (gx + 10, gy + 4), 40)
    Pth = Layer()
    for k in range(0, len(path) - 1, 2):
        Pth.line([path[k], path[k + 1]], 4)
    line = Pth.array()
    img = add(img, line * 1.2 + glow(line, 8, 1.5), HAZARD)
    img = dot(img, 120, 30, 6, HAZARD, gain=2)
    table = Layer()
    table.ellipse(768, 760, 420, 90)
    top = table.array()
    img = add(img, top * 0.35 + glow(top, 20, 0.4), CYAN * 0.5)
    img = add(img, beam((768, 760), 0.32, 520, -math.pi / 2, 30) * 0.25, CYAN)
    S = Layer()
    S.poly([(360, 770), (1176, 770), (1110, 1024), (426, 1024)])
    img = over(img, S.array(), np.array([0.02, 0.025, 0.03]))
    E = Layer()
    hx, hy = human(E, 768, 1010, 600)
    her = E.array() * (YY < 762)
    img = solid(img, her, np.array([0.02, 0.03, 0.035]), (0, 1), CYAN, 1.1, k=4, shade=0.1)
    head = 600 * 0.08
    for side in (-1, 1):
        img = dot(img, hx + side * head * 0.38, hy, 2.2, RED, gain=1.2, halo=6)
    finish(img, 'colony_engineer', rng, grain=0.02)


# 8. News over the relay ----------------------------------------------------------------
def news(name, picture, caption, seed, bar, glitch):
    rng = np.random.default_rng(seed)
    img = interior(rng, base=np.array([0.015, 0.018, 0.025]), light=np.array([0.03, 0.035, 0.045]),
                   vx=768, vy=380, ribs=0.05)
    img = screen(img, 300, 90, 1236, 650, concept(picture), caption=caption, bar=bar)
    if glitch:
        bands = np.zeros((H, W), np.float32)
        for _ in range(9):
            y = int(rng.uniform(100, 640))
            bands[y:y + int(rng.uniform(3, 14)), 300:1236] = rng.uniform(0.3, 0.8)
        img = add(img, bands * noise(rng, 2), np.array([0.6, 0.7, 0.8]))
    K = Layer()
    K.poly([(80, 800), (1456, 800), (1536, 1024), (0, 1024)])
    desk = K.array()
    img = solid(img, desk, np.array([0.05, 0.055, 0.065]), (0, -1), CYAN, 0.5, shade=0.2)
    for k in range(26):
        img = dot(img, 160 + k * 47 + rng.uniform(-8, 8), 840 + rng.uniform(0, 60), 2.2,
                  rng.choice([CYAN, HAZARD, RED]) * 0.8, gain=1.5, halo=5)
    P = Layer()
    human(P, 250, 1200, 520)
    human(P, 1290, 1220, 560)
    img = silhouette(img, P.array(), (0, -1), rim_colour=CYAN, rim_gain=0.6)
    finish(img, name, rng, grain=0.02)


def gor_news():
    news('colony_gor_news', 'icon_5', 'RELAY  ·  GOR COLONY SHIP  ·  MUTINY', 1313,
         np.array([0.5, 0.06, 0.05]), True)


def tern_news():
    news('colony_tern_news', 'icon_4', 'RELAY  ·  TERN COLONY SHIP', 1414,
         np.array([0.04, 0.25, 0.32]), False)


# 9. Blue bog ---------------------------------------------------------------------------------
# A heavy world under a blue sun, all swamp and cloud, and the platform
# that has watched it for a thousand years.
def kepler():
    rng = np.random.default_rng(1515)
    img = space(rng, nebula=np.array([0.05, 0.1, 0.2]), stars=1400)
    sun = np.exp(-(((XX - 1330) ** 2 + (YY - 150) ** 2) / 50 ** 2))
    img = add(img, sun * 3 + glow(sun > 0.2, 120, 5), np.array([0.5, 0.75, 1.0]))
    # The bog: murky water and swamp, under a lid of haze.
    cx, cy, r = 560, 1010, 650
    dx, dy = (XX - cx) / r, (YY - cy) / r
    d = np.hypot(dx, dy)
    z = np.sqrt(np.clip(1 - d * d, 0, 1))
    lam = np.clip(dx * 0.62 - dy * 0.5 + z * 0.6, 0, 1)
    swamp = noise(rng, 26) * 0.5 + noise(rng, 7) * 0.3 + noise(rng, 2.5) * 0.2
    water, mire = np.array([0.04, 0.12, 0.2]), np.array([0.07, 0.15, 0.11])
    t = smooth(0.42, 0.6, swamp)[..., None]
    surface = water * (1 - t) + mire * t
    haze = smooth(0.45, 0.8, noise(rng, 14))[..., None] * 0.25
    surface = surface * (1 - haze) + np.array([0.3, 0.45, 0.55]) * haze
    img = over(img, smooth(1.0, 0.995, d), surface * (0.04 + 0.96 * lam[..., None]))
    atmo = np.exp(-((d - 1.0) / 0.03) ** 2) * (0.3 + 0.7 * np.clip(dx * 0.62 - dy * 0.5 + 0.3, 0, 1))
    img = add(img, atmo * 0.9, np.array([0.45, 0.75, 1.0]))
    # The observation platform: an old ring on spokes, lit by the blue sun.
    px, py = 1080, 360
    P = Layer()
    P.ring(px, py, 120, 44, 14)
    for a in np.linspace(0, 2 * math.pi, 7)[:-1]:
        P.line([(px, py), (px + math.cos(a) * 112, py + math.sin(a) * 40)], 4)
    P.ellipse(px, py, 22, 22)
    P.rect(px - 6, py - 90, px + 6, py)
    P.ellipse(px, py - 92, 14, 10)
    platform = P.array()
    img = solid(img, platform, STEEL * 0.8, (0.8, -0.6), np.array([0.6, 0.85, 1.0]), 1.0)
    for a in np.linspace(0, 2 * math.pi, 16)[:-1]:
        img = dot(img, px + math.cos(a) * 120, py + math.sin(a) * 44, 1.6, GOLD, gain=1.6, halo=4)
    # A human ship, waiting where it was told to wait.
    S = Layer()
    ship(S, 'sleek', 1290, 620, 70, math.radians(190))
    img = solid(img, S.array(), STEEL * 0.6, (0.8, -0.6), ICE, 1.0, k=2)
    img = dot(img, 1325, 622, 2, AMBER, gain=2)
    finish(img, 'colony_kepler', rng, grain=0.02)


# 10. A favour -------------------------------------------------------------------------------
# A crate with the House of the Elephant's mark drifts toward an asteroid
# off the lane. Somebody has scaffolding up on the far side, and lights.
def elephant_crate():
    rng = np.random.default_rng(1616)
    img = space(rng, stars=1300)
    sun = np.exp(-(((XX - 150) ** 2 + (YY - 120) ** 2) / 34 ** 2))
    img = add(img, sun * 3 + glow(sun > 0.2, 70, 4), HOT)
    ax, ay, ar = 1120, 470, 330
    d = np.hypot((XX - ax) / ar, (YY - ay) / (ar * 0.8))
    rock = smooth(1.02, 0.98, d + (noise(rng, 30) - 0.5) * 0.35)
    craters = smooth(0.62, 0.7, noise(rng, 8)) * rock
    lit = smooth(0.2, -0.9, ((XX - ax) * 0.8 + (YY - ay) * 0.5) / ar)
    texture = 0.6 + 0.4 * noise(rng, 5) + 0.25 * noise(rng, 18)
    img = over(img, rock, np.array([0.03, 0.028, 0.025]))
    img = add(img, rock * lit * texture * 0.3, np.array([0.55, 0.48, 0.4]))
    img = add(img, craters * lit * -0.08, np.ones(3))
    img = add(img, rim(rock, (-0.8, -0.5), 4) * 0.7, HOT * 0.6)
    S = Layer()
    # Scaffolding on the rock's far limb, just showing over the top.
    base = ay - ar * 0.62
    for k in range(9):
        x = 1000 + k * 40
        top = base - 110 - (k % 3) * 30
        S.line([(x, base), (x, top)], 3)
        S.line([(x, top), (x + 40, top + 35)], 2)
    S.line([(1000, base - 110), (1320, base - 110)], 3)
    S.line([(1000, base - 55), (1320, base - 55)], 2)
    scaffold = S.array()
    img = silhouette(img, scaffold, (-0.8, -0.5), rim_colour=HOT, rim_gain=0.6)
    for k in range(10):
        img = dot(img, 990 + k * 38 + rng.uniform(-6, 6), base - rng.uniform(30, 150), 2,
                  HAZARD, gain=2, halo=8)
    C = Layer()
    crate(C, 640, 520, 190, 130, -0.18)
    box = C.array()
    img = solid(img, box, np.array([0.3, 0.22, 0.12]), (-0.8, -0.5), HOT, 0.9)
    mark = Layer()
    elephant(mark, 625, 512, 70)
    img = add(img, mark.array() * box * 0.35, GOLD)
    trail = Layer()
    trail.line(bezier((250, 1000), (380, 800), (520, 640), (600, 560), 30), 2, 0.5)
    img = add(img, trail.array() * 0.3, ICE * 0.6)
    O = Layer()
    O.ellipse(-80, 1350, 620, 520)
    img = silhouette(img, O.array(), (0.3, -1), colour=DARK_STEEL, rim_colour=ICE, rim_gain=0.6)
    hatch = Layer()
    hatch.rect(170, 860, 270, 920)
    door = hatch.array()
    img = over(img, door, HOT * 0.8)
    img = add(img, glow(door, 25, 1.2), GOLD)
    finish(img, 'colony_elephant', rng, grain=0.02)


# 11. Gravity ---------------------------------------------------------------------------------
# The colony's centrifuge habitat, a great ring on spokes, spinning. The
# colony wants it spun harder.
def gravity():
    rng = np.random.default_rng(1717)
    img = space(rng, stars=1500)
    cx, cy = 768, 520
    img = ring(img, cx, cy, 560, 60, aspect=0.38, rot=math.radians(-8), light=(-0.4, -0.9),
               colour=STEEL * 0.9, glow_colour=GOLD * 0.6, segments=48)
    c, s = math.cos(math.radians(-8)), math.sin(math.radians(-8))
    for a in np.linspace(0, 2 * math.pi, 90)[:-1]:
        x, y = 530 * math.cos(a), 530 * math.sin(a) * 0.38
        img = dot(img, cx + x * c - y * s, cy + x * s + y * c, 1.5, GOLD, gain=1.8, halo=4)
    S = Layer()
    for a in np.linspace(0, 2 * math.pi, 7)[:-1]:
        x, y = 505 * math.cos(a), 505 * math.sin(a) * 0.38
        S.line([(cx, cy), (cx + x * c - y * s, cy + x * s + y * c)], 9)
    S.ellipse(cx, cy, 70, 46)
    img = solid(img, S.array(), STEEL * 0.7, (-0.4, -0.9), ICE, 0.8)
    # The spin: streaks along the ring.
    M = Layer()
    for a0 in np.linspace(0, 2 * math.pi, 9)[:-1]:
        pts = []
        for a in np.linspace(a0, a0 + 0.45, 12):
            x, y = 600 * math.cos(a), 600 * math.sin(a) * 0.38
            pts.append((cx + x * c - y * s, cy + x * s + y * c))
        M.line(pts, 2, 0.6)
    img = add(img, glow(M.array(), 2, 1.0), ICE * 0.5)
    finish(img, 'colony_gravity', rng, grain=0.02)


# 12. A collection ---------------------------------------------------------------------------
# Every family put something in. The representatives set it on the desk
# under the lamp as if it were rent.
def collection():
    rng = np.random.default_rng(1818)
    img = interior(rng, base=np.array([0.035, 0.028, 0.022]), light=np.array([0.06, 0.045, 0.03]),
                   vx=768, vy=400, ribs=0.05)
    img = add(img, beam((768, 0), 0.45, 1000, math.pi / 2, 40) * 0.25, GOLD)
    img = dot(img, 768, 20, 14, HOT, gain=3)
    P = Layer()
    for x, h in ((470, 470), (768, 500), (1066, 460)):
        human(P, x, 860, h)
    img = silhouette(img, P.array(), (0, -1), rim_colour=GOLD, rim_gain=0.9)
    D = Layer()
    D.poly([(200, 700), (1336, 700), (1460, 1024), (76, 1024)])
    desk = D.array()
    img = solid(img, desk, np.array([0.12, 0.07, 0.04]), (0, -1), GOLD, 0.8, shade=0.3)
    C = Layer()
    for _ in range(420):
        t = rng.beta(2, 2)
        x = 768 + (t - 0.5) * 640
        y = 760 - 150 * (1 - ((x - 768) / 330) ** 2) * rng.uniform(0, 1) ** 0.6
        C.ellipse(x, y, 16, 6)
    for k in range(5):  # stacks
        for j in range(int(rng.uniform(6, 14))):
            C.ellipse(1060 + k * 40, 780 - j * 7, 16, 6)
    coins = C.array()
    img = solid(img, coins, GOLD * 0.8, (0, -1), HOT, 1.2, k=2, shade=0.2)
    shine = Layer()
    for _ in range(40):
        shine.ellipse(rng.uniform(470, 1066), rng.uniform(620, 770), 2, 1)
    img = add(img, glow(shine.array() * coins, 2, 6), HOT)
    finish(img, 'colony_collection', rng, grain=0.02)


# 13. The vote ------------------------------------------------------------------------------
# The colony's clamps have let go. The grid drifts away from your ship
# toward The Matriarch, Lady Idun's flagship, the House of the Elephant's
# mark on her flank and her tractor beam already on you.
def secession():
    rng = np.random.default_rng(1919)
    img = space(rng, nebula=np.array([0.18, 0.12, 0.06]), stars=1400)
    sun = np.exp(-(((XX - 160) ** 2 + (YY - 140) ** 2) / 30 ** 2))
    img = add(img, sun * 3 + glow(sun > 0.2, 70, 4), HOT)
    # The Matriarch: a heavy human hull, lit from the left.
    M = Layer()
    ship(M, 'heavy', 1150, 360, 760, math.radians(186))
    for u in (-0.3, -0.05, 0.2):  # missile bays along her belly
        x, y = 1150 - u * 760, 360 + 0.17 * 760
        M.rect(x - 22, y - 10, x + 22, y + 6)
    hull = M.array()
    img = solid(img, hull, np.array([0.16, 0.13, 0.1]), (-0.8, -0.4), HOT, 0.9, shade=0.45)
    mark = Layer()
    elephant(mark, 1120, 330, 120)
    img = add(img, mark.array() * hull * 0.5, GOLD)
    words = Layer()
    words.text(1180, 445, 'THE MATRIARCH', 26)
    img = add(img, words.array() * hull * 0.35, np.array([0.9, 0.85, 0.75]))
    for u in (-0.3, -0.05, 0.2):
        img = dot(img, 1150 - u * 760, 360 + 0.17 * 760, 5, np.array([1.0, 0.9, 0.6]), gain=2, halo=14)
    for v in (-0.12, 0.0, 0.12):
        img = dot(img, 1150 + 0.5 * 760, 360 + v * 760, 7, AMBER, gain=2.5, halo=20)
    # Her tractor beam, down onto your ship.
    img = add(img, beam((900, 420), 0.09, 900, math.atan2(980 - 420, 160 - 900), 22) * 0.35,
              np.array([0.6, 0.85, 1.0]))
    # Your ship, the empty clamps where the colony was.
    O = Layer()
    O.ellipse(-100, 1360, 700, 560)
    own = O.array()
    img = silhouette(img, own, (0.3, -1), colour=DARK_STEEL, rim_colour=ICE, rim_gain=0.7)
    clamps = Layer()
    for k in range(3):
        x = 260 + k * 90
        y = 860 - k * 55
        clamps.line([(x, y), (x + 20, y - 40), (x + 50, y - 46)], 8)
    img = silhouette(img, clamps.array(), (0.3, -1), colour=DARK_STEEL * 1.5, rim_colour=HAZARD,
                     rim_gain=0.7)
    # The colony grid, drifting away, every window lit.
    G = Layer()
    windows = []
    gx, gy, cell = 560, 520, 62
    for row in range(3):
        for col in range(3):
            x = gx + col * (cell + 10) + row * 14
            y = gy + row * (cell + 10) - col * 18
            G.rect(x, y, x + cell, y + cell)
            for _ in range(5):
                windows.append((x + rng.uniform(8, cell - 8), y + rng.uniform(8, cell - 8)))
    grid = G.array()
    img = solid(img, grid, np.array([0.22, 0.18, 0.12]), (-0.8, -0.4), GOLD, 0.8, k=2, shade=0.3)
    for x, y in windows:
        img = dot(img, x, y, 1.6, GOLD, gain=1.8, halo=4)
    for x, y in ((gx - 10, gy + 120), (gx + 210, gy + 40)):
        img = dot(img, x, y, 4, ICE, gain=2, halo=16)  # its own little thrusters
    finish(img, 'colony_secession', rng, grain=0.02)


SCENES = {f.__name__: f for f in (
    volunteers, draft, veterans, helmet, strike, headcount, engineer, gor_news, tern_news, kepler,
    elephant_crate, gravity, collection, secession)}

if __name__ == '__main__':
    scene_main(SCENES, 'colony mockups')
