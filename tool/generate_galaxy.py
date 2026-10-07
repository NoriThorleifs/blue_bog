"""Generates assets/galaxy.jpg, a top-down Milky Way for the galaxy map.

The image uses the same coordinate space as the game (2970 px square, core at
(1486, 1400), Sol at (1488, 2308)), so map positions line up with it.

    python3 tool/generate_galaxy.py [seed]

Needs numpy, scipy and Pillow.
"""

import sys

import numpy as np
from PIL import Image
from scipy import ndimage

SIZE = 2970
CORE = (1486.0, 1400.0)
SOL = (1488.0, 2308.0)
DISK_RADIUS = 1380.0
BAR_ANGLE = np.radians(-28)
BAR_HALF_LENGTH = 340.0
PITCH = np.radians(15.5)

rng = np.random.default_rng(int(sys.argv[1]) if len(sys.argv) > 1 else 7)

y, x = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
dx, dy = x - CORE[0], y - CORE[1]
r = np.hypot(dx, dy) + 1e-3
theta = np.arctan2(dy, dx)


def fbm(octaves=(6, 12, 24, 48, 96), persistence=0.55):
    """Fractal noise in [0, 1] built from upsampled random grids."""
    total = np.zeros((SIZE, SIZE), np.float32)
    amplitude, norm = 1.0, 0.0
    for cells in octaves:
        grid = rng.random((cells + 1, cells + 1)).astype(np.float32)
        layer = ndimage.zoom(grid, SIZE / (cells + 1), order=3)[:SIZE, :SIZE]
        total += amplitude * layer
        norm += amplitude
        amplitude *= persistence
    total /= norm
    return (total - total.min()) / (total.max() - total.min())


def smoothstep(edge0, edge1, v):
    t = np.clip((v - edge0) / (edge1 - edge0), 0, 1)
    return t * t * (3 - 2 * t)


def wrap(a):
    return (a + np.pi) % (2 * np.pi) - np.pi


def arm(phase, amplitude, width=60.0, start=BAR_HALF_LENGTH, span=None):
    """Density of a logarithmic spiral arm, and of its inner dust lane."""
    winding = np.log(np.maximum(r, 1) / start) / np.tan(PITCH)
    offset = wrap(ragged - (phase + winding))
    across = r * offset * np.sin(PITCH)
    w = width + 0.035 * r
    density = np.exp(-(across / w) ** 2)
    lane = np.exp(-((across + 0.55 * w) / (0.3 * w)) ** 2)
    fade = smoothstep(start * 0.85, start * 1.25, r) * (
        1 - smoothstep(DISK_RADIUS * 0.85, DISK_RADIUS * 1.08, r)
    )
    if span is not None:
        lo, hi = span
        fade = fade * smoothstep(lo, lo + 0.25, winding) * (
            1 - smoothstep(hi - 0.25, hi, winding)
        )
    return amplitude * density * fade, lane * fade * amplitude


# Arms wobble a little so they don't look drawn with a compass.
ragged = theta + 0.22 * (fbm((3, 6, 12), 0.5) - 0.5)

# Bulge and bar ---------------------------------------------------------------
bx = dx * np.cos(BAR_ANGLE) + dy * np.sin(BAR_ANGLE)
by = -dx * np.sin(BAR_ANGLE) + dy * np.cos(BAR_ANGLE)
bulge = 1.5 * np.exp(-((r / 95) ** 2)) + 0.35 * np.exp(-((r / 260) ** 2))
bar = 0.75 * np.exp(-((bx / BAR_HALF_LENGTH) ** 4 + (by / 85) ** 2))
disk = 0.24 * np.exp(-r / 560) * (1 - smoothstep(DISK_RADIUS * 0.9, DISK_RADIUS * 1.15, r))

# Arms: two major arms from the bar ends, two minor ones between them, and a
# short spur through Sol, like the Orion spur.
arms = np.zeros_like(r)
lanes = np.zeros_like(r)
sol_theta = np.arctan2(SOL[1] - CORE[1], SOL[0] - CORE[0])
sol_winding = np.log(np.hypot(SOL[0] - CORE[0], SOL[1] - CORE[1]) / BAR_HALF_LENGTH) / np.tan(PITCH)
for phase, amplitude, width, span in [
    (BAR_ANGLE, 1.0, 34, None),
    (BAR_ANGLE + np.pi, 1.0, 34, None),
    (BAR_ANGLE + np.pi / 2, 0.45, 24, None),
    (BAR_ANGLE + 3 * np.pi / 2, 0.45, 24, None),
    (sol_theta - sol_winding, 0.3, 20, (sol_winding - 1.0, sol_winding + 0.8)),
]:
    density, lane = arm(phase, amplitude, width, span=span)
    arms += density
    lanes += lane

clumps = fbm()
arms *= (0.15 + 1.5 * clumps) ** 1.6
dust = fbm((10, 20, 40, 80, 160), 0.6)
lanes = np.clip(lanes * (0.4 + 0.9 * dust), 0, 1)

# Colour --------------------------------------------------------------------
background = np.array([4, 6, 12], np.float32) / 255
core_colour = np.array([1.0, 0.82, 0.58], np.float32)
disk_colour = np.array([0.82, 0.76, 0.70], np.float32)
arm_colour = np.array([0.62, 0.74, 1.0], np.float32)

light = (
    (bulge + bar)[..., None] * core_colour
    + disk[..., None] * disk_colour
    + 0.6 * arms[..., None] * arm_colour
)
light *= (1 - 0.8 * lanes)[..., None]
light = ndimage.gaussian_filter(light, sigma=(1.5, 1.5, 0))

# Star-forming regions and clusters along the arms.
weights = (arms / arms.sum()).ravel()
for count, colour, radius, brightness in [
    (420, np.array([1.0, 0.45, 0.62]), (2.5, 7.0), 0.55),
    (1600, np.array([0.75, 0.85, 1.0]), (0.8, 2.2), 0.9),
]:
    idx = rng.choice(weights.size, size=count, p=weights)
    layer = np.zeros((SIZE, SIZE), np.float32)
    np.add.at(layer, np.unravel_index(idx, (SIZE, SIZE)), rng.uniform(0.3, 1.0, count))
    for sigma in radius:
        blurred = ndimage.gaussian_filter(layer, sigma) * sigma * sigma * 6
        light += brightness * blurred[..., None] * colour / len(radius)

# Field stars over the whole image, denser in the disk.
stars = np.zeros((SIZE, SIZE), np.float32)
n = 60000
sx = rng.integers(0, SIZE, n)
sy = rng.integers(0, SIZE, n)
keep = rng.random(n) < (0.25 + 0.75 * np.exp(-r[sy, sx] / 900))
stars[sy[keep], sx[keep]] = rng.pareto(2.2, keep.sum()).clip(0, 6) * 0.25 + 0.08
stars = ndimage.gaussian_filter(stars, 0.6) * 3
light += stars[..., None] * np.array([0.9, 0.93, 1.0])

image = background + (1 - np.exp(-1.15 * light))
image = np.clip(image, 0, 1) ** 0.95
Image.fromarray((image * 255).astype(np.uint8)).save(
    "assets/galaxy.jpg", quality=88, optimize=True
)
print("wrote assets/galaxy.jpg")
