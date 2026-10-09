import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game_engine/galaxy/galaxy.dart';
import '../../game_engine/galaxy/territory.dart';
import '../../game_engine/run_state.dart';
import '../../providers/territory_provider.dart';

/// Draws territory borders over the map, and from act 2 on, fills each
/// territory with the colour of the faction controlling its gate node.
///
/// Territories of systems the captain hasn't found yet are left off.
class TerritoryLayer extends ConsumerStatefulWidget {
  const TerritoryLayer({super.key, required this.run});
  final RunState run;

  @override
  ConsumerState<TerritoryLayer> createState() => _TerritoryLayerState();
}

class _TerritoryLayerState extends ConsumerState<TerritoryLayer> {
  ui.Image? _image;
  String? _key;

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  /// Everything the picture depends on. Rebuilt only when this changes.
  String _keyFor(RunState run, Territory t) => [
    run.galaxy.seed,
    run.act >= 2,
    for (final id in t.nodes)
      run.revealed.contains(id) ? run.control[id]?.index : '-',
  ].join(',');

  Future<void> _paint(Territory territory) async {
    final run = widget.run;
    final key = _keyFor(run, territory);
    if (key == _key) return;
    _key = key;
    final pixels = await compute(_rasterise, (
      owners: territory.owners,
      colours: Int32List.fromList([
        for (final id in territory.nodes)
          run.revealed.contains(id) ? run.control[id]!.argb : 0,
      ]),
      factions: Int32List.fromList([
        for (final id in territory.nodes)
          run.revealed.contains(id) ? run.control[id]!.index + 1 : 0,
      ]),
      fill: run.act >= 2,
    ));
    if (!mounted || key != _key) return;
    ui.decodeImageFromPixels(
      pixels,
      Territory.gridSize,
      Territory.gridSize,
      ui.PixelFormat.rgba8888,
      (image) {
        if (!mounted || key != _key) {
          image.dispose();
          return;
        }
        setState(() {
          _image?.dispose();
          _image = image;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final territory = ref.watch(territoryProvider(widget.run.galaxy)).value;
    if (territory != null) _paint(territory);
    final image = _image;
    if (image == null) return const SizedBox.shrink();
    return RawImage(
      image: image,
      width: mapSize,
      height: mapSize,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
    );
  }
}

typedef _Job = ({
  Uint8List owners,
  Int32List colours,
  Int32List factions,
  bool fill,
});

/// Turns the ownership grid into premultiplied RGBA pixels.
Uint8List _rasterise(_Job job) {
  const n = Territory.gridSize;
  final owners = job.owners;
  final out = Uint8List(n * n * 4);

  // Hidden territories count as empty space.
  int visible(int i) {
    final o = owners[i];
    return o != 0 && job.colours[o - 1] != 0 ? o : 0;
  }

  int faction(int o) => o == 0 ? 0 : job.factions[o - 1];

  void put(int i, int argb, int alpha) {
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    out[i * 4] = r * alpha ~/ 255;
    out[i * 4 + 1] = g * alpha ~/ 255;
    out[i * 4 + 2] = b * alpha ~/ 255;
    out[i * 4 + 3] = alpha;
  }

  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      final i = y * n + x;
      final o = visible(i);
      if (o == 0) continue;
      final colour = job.colours[o - 1];

      // A border cell has a different owner within two cells of it. Borders
      // with another faction or empty space are drawn in the faction colour.
      var border = false;
      var factionBorder = false;
      for (var d = 1; d <= 2 && !factionBorder; d++) {
        for (final (nx, ny) in [
          (x - d, y),
          (x + d, y),
          (x, y - d),
          (x, y + d),
        ]) {
          final other = nx < 0 || ny < 0 || nx >= n || ny >= n
              ? 0
              : visible(ny * n + nx);
          if (other != o) {
            border = true;
            if (faction(other) != faction(o)) factionBorder = true;
          }
        }
      }

      if (factionBorder && job.fill) {
        put(i, colour, 0xD8);
      } else if (border) {
        put(i, 0xFFFFFFFF, job.fill ? 0x50 : 0x70);
      } else if (job.fill) {
        put(i, colour, 0x30);
      }
    }
  }
  return out;
}
