import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game_engine/galaxy/galaxy.dart';
import '../game_engine/galaxy/territory.dart';

/// Territory for a galaxy, built once in a background isolate.
final territoryProvider = FutureProvider.family<Territory, Galaxy>(
  (ref, galaxy) => compute(buildTerritory, galaxy),
);
