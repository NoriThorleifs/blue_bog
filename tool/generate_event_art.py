"""Backdrops for every brawl event, made from the concept art.

Proof-of-concept placeholders, not final art. Writes
assets/events/<event id>_ai_generated.jpg from concept_art/, sized for a
phone and saved as JPEG to keep the app small. Run the concept generators
first if any concept is missing: generate_colony_, generate_workshop_,
generate_lane_ and generate_hell_concepts.py, and the gate, Mourner and icon
ones. lib/components/brawl/event_art.dart lists the same events.

    python3 tool/generate_event_art.py

Needs Pillow.
"""

import os

from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), '..')
CONCEPTS = os.path.join(ROOT, 'concept_art')
OUT = os.path.join(ROOT, 'assets', 'events')

# The longest side. A phone shows the backdrop about 1080 px across.
LONGEST = 1280

# Event id, and the concept it's made from, by where the event happens.
EVENTS = [
    # On the way out of a station.
    ('chewer', 'gate_3'),
    ('toll', 'lane_toll'),
    ('wreck', 'lane_wreck'),
    ('neo_terra', 'lane_exclusion'),
    ('smuggler', 'lane_smuggler'),
    ('leak', 'lane_leak'),
    ('quiet_lane', 'lane_quiet'),
    ('convoy', 'lane_convoy'),
    ('shakedown', 'lane_shakedown'),
    ('gor_duel', 'lane_duel'),
    ('unmerged_foundry', 'lane_foundry'),
    ('nobody', 'lane_nobody'),
    ('gift_boarders', 'colony_volunteers'),
    ('wrong_warp', 'gate_2'),
    # In transit: the colony's story.
    ('neo_terra_war', 'colony_draft'),
    ('veterans_home', 'colony_veterans'),
    ('the_helmet', 'colony_helmet'),
    ('petition_rifles', 'colony_rifles'),
    ('petition_gravity', 'colony_gravity'),
    ('petition_wreck', 'colony_wreck'),
    ('hell_headcount', 'colony_headcount'),
    ('red_eyes', 'icon_9'),
    ('wrong_warp_offer', 'colony_engineer'),
    ('colony_strike', 'colony_strike'),
    ('kepler_refused', 'colony_kepler'),
    ('elephant_crate', 'colony_elephant'),
    ('gor_colony_mutiny', 'colony_gor_news'),
    ('tern_colony_stays', 'colony_tern_news'),
    ('gift_spares', 'colony_spares'),
    ('gift_double_shift', 'colony_double_shift'),
    ('gift_collection', 'colony_collection'),
    ('gift_ammunition', 'colony_ammunition'),
    ('gift_shipwrights', 'colony_shipwrights'),
    # In Hell.
    ('hell_flesh', 'hell_flesh'),
    ('hell_hunter', 'icon_10'),
    ('hell_swarm', 'hell_swarm'),
    ('hell_still', 'hell_still'),
    ('hell_clocks', 'hell_clocks'),
    ('hell_barrier', 'hell_barrier'),
    ('hell_herald', 'hell_herald'),
    ('hell_mourner', 'mourner_2'),
    # The end.
    ('satan', 'hell_satan'),
]


def main():
    os.makedirs(OUT, exist_ok=True)
    for event, concept in EVENTS:
        im = Image.open(os.path.join(CONCEPTS, f'{concept}_ai_generated.png')).convert('RGB')
        scale = LONGEST / max(im.size)
        if scale < 1:
            im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
        path = os.path.join(OUT, f'{event}_ai_generated.jpg')
        im.save(path, quality=84, optimize=True, progressive=True)
        print(f'{event}: {concept}, {im.width}x{im.height}, {os.path.getsize(path) // 1024} KB')


if __name__ == '__main__':
    main()
