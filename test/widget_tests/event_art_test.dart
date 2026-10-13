import 'dart:io';

import 'package:blue_bog/components/brawl/event_art.dart';
import 'package:blue_bog/game_engine/brawl/brawl_events.dart';
import 'package:blue_bog/game_engine/captain/species.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every event has art, and its picture exists', () {
    expect(eventArt.keys.toSet(), brawlEventsById.keys.toSet());
    for (final id in eventArt.keys) {
      expect(brawlEventsById, contains(id));
      expect(
        File('assets/events/${id}_ai_generated.jpg').existsSync(),
        isTrue,
        reason: 'run tool/generate_event_art.py',
      );
    }
  });

  test('every playable species has a portrait', () {
    for (final species in Species.values) {
      final path = 'assets/species/${EnumName(species).name}_ai_generated.png';
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });
}
