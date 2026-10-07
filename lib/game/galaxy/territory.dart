import 'dart:math';
import 'dart:typed_data';

import '../rng.dart';
import 'galaxy.dart';

/// How a gate node's border is drawn.
enum BorderStyle {
  /// Straight lines and right angles, as if ruled onto a chart by
  /// colonisers. The node measures distance as a square.
  colonial,

  /// Circle arcs, as if someone drew a radius around the gate.
  radial,

  /// Squiggly, the kind of line that comes from old disputes.
  contested,
}

/// Which gate node owns each patch of space.
///
/// Gates take up so much room in Hell that they can only sit at intervals,
/// so the galaxy is divided by which gate node is nearest. Each node only
/// reaches so far, so some space belongs to nobody. Systems without a
/// gateway (Neo Terra, Ur-Gor, Úlaval) sit inside another node's territory.
///
/// Contested borders can leave enclaves and exclaves behind. That's
/// deliberate: they read as the leftovers of old conflicts.
class Territory {
  Territory({required this.nodes, required this.styles, required this.owners});

  /// Map pixels per grid cell.
  static const cellSize = 2;
  static const gridSize = 1485;

  /// Furthest a node can claim, in its own distance measure.
  static const reach = 330.0;

  /// Gate node ids. A cell's owner value is an index into this, plus one.
  final List<String> nodes;
  final Map<String, BorderStyle> styles;

  /// [gridSize] squared cells, row by row. Zero is unclaimed space.
  final Uint8List owners;

  /// The node owning the map point ([x], [y]), if any.
  String? ownerAt(double x, double y) {
    final cx = (x / cellSize).floor();
    final cy = (y / cellSize).floor();
    if (cx < 0 || cy < 0 || cx >= gridSize || cy >= gridSize) return null;
    final owner = owners[cy * gridSize + cx];
    return owner == 0 ? null : nodes[owner - 1];
  }
}

/// Builds the territory map for [galaxy]. Pure and deterministic, and slow
/// enough (a few hundred milliseconds) that the UI runs it in an isolate.
Territory buildTerritory(Galaxy galaxy) {
  final nodes = [
    for (final s in galaxy.systems.values)
      if (galaxy.gatewaysOf(s.id).isNotEmpty) s,
  ];
  final rng = GameRng(galaxy.seed ^ 0x7E44170);
  final styles = <String, BorderStyle>{};
  final weights = <double>[];
  for (final s in nodes) {
    final style =
        _loreStyles[s.id] ?? rng.pick<BorderStyle>(BorderStyle.values);
    styles[s.id] = style;
    weights.add(style == BorderStyle.radial ? rng.rangeDouble(0.8, 1.3) : 1);
  }

  const n = Territory.gridSize;
  const cell = Territory.cellSize;
  final owners = Uint8List(n * n);

  // Bucket nodes by the coarse cells they can reach, so each grid cell only
  // checks a handful of candidates.
  const bucket = 64;
  const buckets = (n + bucket - 1) ~/ bucket;
  final candidates = List.generate(buckets * buckets, (_) => <int>[]);
  for (var i = 0; i < nodes.length; i++) {
    final p = nodes[i].position;
    final r = Territory.reach * max(weights[i], 1) * 1.5 + _wobble;
    final x0 = max(0, ((p.x - r) / cell / bucket).floor());
    final x1 = min(buckets - 1, ((p.x + r) / cell / bucket).floor());
    final y0 = max(0, ((p.y - r) / cell / bucket).floor());
    final y1 = min(buckets - 1, ((p.y + r) / cell / bucket).floor());
    for (var by = y0; by <= y1; by++) {
      for (var bx = x0; bx <= x1; bx++) {
        candidates[by * buckets + bx].add(i);
      }
    }
  }

  final noiseSeed = galaxy.seed;
  for (var cy = 0; cy < n; cy++) {
    final y = (cy + 0.5) * cell;
    for (var cx = 0; cx < n; cx++) {
      final list = candidates[(cy ~/ bucket) * buckets + cx ~/ bucket];
      if (list.isEmpty) continue;
      final x = (cx + 0.5) * cell;
      var best = Territory.reach;
      var owner = 0;
      for (final i in list) {
        final p = nodes[i].position;
        final dx = x - p.x;
        final dy = y - p.y;
        final d = switch (styles[nodes[i].id]!) {
          BorderStyle.colonial => max(dx.abs(), dy.abs()) * 1.12,
          BorderStyle.radial => sqrt(dx * dx + dy * dy) / weights[i],
          BorderStyle.contested =>
            sqrt(dx * dx + dy * dy) + _wobble * _noise(x, y, noiseSeed),
        };
        if (d <= best) {
          best = d;
          owner = i + 1;
        }
      }
      owners[cy * n + cx] = owner;
    }
  }
  return Territory(
    nodes: [for (final s in nodes) s.id],
    styles: styles,
    owners: owners,
  );
}

/// Some borders have a history.
const _loreStyles = {
  Sys.center: BorderStyle.colonial,
  Sys.orcha: BorderStyle.colonial,
  Sys.ghorDum: BorderStyle.contested,
  Sys.bhrunGai: BorderStyle.contested,
  Sys.kepler: BorderStyle.radial,
  Sys.sol: BorderStyle.radial,
};

/// How far, in map pixels, contested borders wander.
const _wobble = 80.0;

/// Smooth noise in roughly [-0.5, 0.5], two octaves of value noise.
double _noise(double x, double y, int seed) =>
    0.65 * _valueNoise(x / 110, y / 110, seed) +
    0.35 * _valueNoise(x / 37, y / 37, seed + 1) -
    0.5;

double _valueNoise(double x, double y, int seed) {
  final x0 = x.floor();
  final y0 = y.floor();
  final fx = x - x0;
  final fy = y - y0;
  final sx = fx * fx * (3 - 2 * fx);
  final sy = fy * fy * (3 - 2 * fy);
  double h(int i, int j) {
    var v = (i * 374761393 + j * 668265263 + seed * 2246822519) & 0x7FFFFFFF;
    v = ((v ^ (v >> 13)) * 1274126177) & 0x7FFFFFFF;
    return (v & 0xFFFF) / 0xFFFF;
  }

  final top = h(x0, y0) + (h(x0 + 1, y0) - h(x0, y0)) * sx;
  final bottom = h(x0, y0 + 1) + (h(x0 + 1, y0 + 1) - h(x0, y0 + 1)) * sx;
  return top + (bottom - top) * sy;
}
