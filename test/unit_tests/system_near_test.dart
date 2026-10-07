import 'package:blue_bog/game/captain/species.dart';
import 'package:blue_bog/game/content/content.dart';
import 'package:blue_bog/game/engine.dart';
import 'package:blue_bog/game/galaxy/galaxy.dart';
import 'package:blue_bog/presentation/map/galaxy_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final run = GameEngine(storyContent).newRun(Species.tern, seed: 11);
  Offset at(String id) {
    final p = run.galaxy[id].position;
    return Offset(p.x, p.y);
  }

  test('picks the system under the tap', () {
    for (final id in run.revealed) {
      expect(systemNear(run, at(id) + const Offset(5, -5), 40), id);
    }
  });

  test('picks the nearer of two neighbours', () {
    final kepler = at(Sys.kepler);
    final bhrun = at(Sys.bhrunGai);
    final nearKepler = Offset.lerp(kepler, bhrun, 0.3)!;
    final radius = (bhrun - kepler).distance;
    expect(systemNear(run, nearKepler, radius), Sys.kepler);
  });

  test('ignores taps on empty space and hidden systems', () {
    expect(systemNear(run, const Offset(5, 5), 40), isNull);
    expect(systemNear(run, at(Sys.neoTerra), 1), isNull);
  });
}
