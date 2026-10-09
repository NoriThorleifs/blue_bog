/// Deterministic PRNG (mulberry32) whose entire state is a single 32-bit int.
///
/// Keeping the state in one int means a run can be saved, restored and
/// replayed exactly. The multiply is split into 16-bit halves so it gives the
/// same results on the web, where Dart ints are doubles.
class GameRng {
  GameRng(int seed) : _state = seed & 0xFFFFFFFF;

  int _state;

  int get state => _state;

  int nextUint32() {
    _state = (_state + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _state;
    t = _imul(t ^ (t >>> 15), t | 1);
    t ^= (t + _imul(t ^ (t >>> 7), t | 61)) & 0xFFFFFFFF;
    return (t ^ (t >>> 14)) & 0xFFFFFFFF;
  }

  /// Uniform double in [0, 1).
  double nextDouble() => nextUint32() / 4294967296.0;

  /// Uniform int in [0, max).
  int nextInt(int max) {
    if (max <= 0) throw ArgumentError.value(max, 'max', 'must be positive');
    return (nextDouble() * max).floor();
  }

  /// Uniform int in [min, max] inclusive.
  int range(int min, int max) => min + nextInt(max - min + 1);

  double rangeDouble(double min, double max) =>
      min + nextDouble() * (max - min);

  /// True with probability [p] (clamped to [0, 1]).
  bool chance(double p) => nextDouble() < p.clamp(0.0, 1.0);

  T pick<T>(List<T> items) => items[nextInt(items.length)];

  /// Picks an item with probability proportional to its weight. Items with a
  /// weight of zero or less are never picked. Returns null if nothing can be.
  T? weighted<T>(Iterable<T> items, double Function(T) weightOf) {
    final pool = [
      for (final item in items)
        if (weightOf(item) > 0) (item, weightOf(item)),
    ];
    if (pool.isEmpty) return null;
    final total = pool.fold<double>(0, (sum, e) => sum + e.$2);
    var roll = nextDouble() * total;
    for (final (item, weight) in pool) {
      roll -= weight;
      if (roll < 0) return item;
    }
    return pool.last.$1;
  }

  List<T> shuffled<T>(Iterable<T> items) {
    final list = items.toList();
    for (var i = list.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final swap = list[i];
      list[i] = list[j];
      list[j] = swap;
    }
    return list;
  }

  static int _imul(int a, int b) {
    final lo = a * (b & 0xFFFF);
    final hi = ((a * (b >>> 16)) & 0xFFFF) << 16;
    return (lo + hi) & 0xFFFFFFFF;
  }
}
