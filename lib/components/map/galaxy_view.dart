import 'dart:math';

import 'package:flutter/material.dart' hide Route;

import '../../game_engine/engine.dart';
import '../../game_engine/galaxy/galaxy.dart';
import '../../game_engine/run_state.dart';
import '../theme.dart';
import 'territory_layer.dart';

/// The pannable, zoomable galaxy with systems and routes drawn on top.
///
/// Markers and lines are counter-scaled against the zoom so they stay the
/// same size on screen however far in or out the player is.
class GalaxyView extends StatefulWidget {
  const GalaxyView({
    super.key,
    required this.run,
    required this.routes,
    required this.selected,
    required this.onSelect,
    this.focusY = 0.5,
  });

  final RunState run;
  final List<Route> routes;
  final String? selected;
  final ValueChanged<String> onSelect;

  /// Where on screen, as a fraction of the height, the ship is centred.
  /// Phones keep it above the bottom panel.
  final double focusY;

  @override
  State<GalaxyView> createState() => _GalaxyViewState();
}

class _GalaxyViewState extends State<GalaxyView> {
  final _transform = TransformationController();
  Size? _viewport;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(GalaxyView old) {
    super.didUpdateWidget(old);
    // Follow the ship when it lands somewhere unexpected, like out of Hell.
    if (old.run.location != widget.run.location && widget.run.hell == null) {
      final viewport = _viewport;
      if (viewport != null && !_isOnScreen(widget.run.here.position)) {
        _centerOn(widget.run.here.position, viewport);
      }
    }
  }

  bool _isOnScreen(Point<double> p) {
    final viewport = _viewport!;
    final screen = MatrixUtils.transformPoint(
      _transform.value,
      Offset(p.x, p.y),
    );
    return (Offset.zero & viewport).deflate(60).contains(screen);
  }

  /// Map zoom. Read from x alone; the z scale isn't meaningful here.
  double get _zoom => _transform.value.entry(0, 0);

  void _centerOn(Point<double> p, Size viewport, {double? scale}) {
    final zoom = scale ?? _zoom;
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        viewport.width / 2 - p.x * zoom,
        viewport.height * widget.focusY - p.y * zoom,
        0,
        1,
      )
      ..scaleByDouble(zoom, zoom, zoom, 1);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final viewport = box.biggest;
        // Happens for a frame during route transitions.
        if (viewport.isEmpty) return const SizedBox.shrink();
        final fit = min(viewport.width, viewport.height) / mapSize;
        if (_viewport == null) {
          _viewport = viewport;
          _centerOn(
            widget.run.here.position,
            viewport,
            scale: max(fit * 1.6, 0.45),
          );
        }
        _viewport = viewport;

        return InteractiveViewer(
          transformationController: _transform,
          constrained: false,
          minScale: fit * 0.9,
          maxScale: 2.5,
          boundaryMargin: const EdgeInsets.all(mapSize / 3),
          child: SizedBox.square(
            dimension: mapSize,
            child: AnimatedBuilder(
              animation: _transform,
              // Rebuilt with the run, not on every zoom tick.
              child: Stack(
                children: [
                  Image.asset(
                    'assets/galaxy_ai_generated.jpg',
                    width: mapSize,
                    height: mapSize,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: TerritoryLayer(run: widget.run),
                    ),
                  ),
                ],
              ),
              builder: (context, image) {
                final zoom = _zoom;
                // One tap handler for the whole map. Per-marker tap targets
                // don't work here: counter-scaling blows their boxes up
                // until neighbours overlap and steal each other's taps.
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    final id = systemNear(
                      widget.run,
                      details.localPosition,
                      tapRadius / zoom,
                    );
                    if (id != null) widget.onSelect(id);
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(child: image!),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _RoutesPainter(
                              widget.run,
                              widget.routes,
                              zoom,
                            ),
                          ),
                        ),
                      ),
                      for (final id in widget.run.revealed)
                        _positioned(widget.run.galaxy[id], zoom),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _positioned(StarSystem system, double zoom) {
    const width = 150.0;
    const height = 64.0;
    const dotCentre = 16.0;
    final route = widget.routes.where((r) => r.to == system.id).firstOrNull;
    return Positioned(
      left: system.position.x - width / 2,
      top: system.position.y - dotCentre,
      width: width,
      height: height,
      child: Transform.scale(
        scale: 1 / zoom,
        alignment: const Alignment(0, -1 + 2 * dotCentre / height),
        child: _SystemMarker(
          name: widget.run.nameOf(system.id),
          status: _statusOf(system, route),
          selected: widget.selected == system.id,
          onSelect: () => widget.onSelect(system.id),
        ),
      ),
    );
  }

  _MarkerStatus _statusOf(StarSystem system, Route? route) {
    final run = widget.run;
    if (system.id == run.location) {
      return run.inHell ? _MarkerStatus.hellEntry : _MarkerStatus.here;
    }
    if (route != null) {
      return route.isSublight ? _MarkerStatus.sublight : _MarkerStatus.gateway;
    }
    return run.visited.contains(system.id)
        ? _MarkerStatus.visited
        : _MarkerStatus.known;
  }
}

/// How close, in screen pixels, a tap must land to a system to select it.
const tapRadius = 36.0;

/// The revealed system nearest to [point] (in map coordinates) within
/// [radius], if any.
String? systemNear(RunState run, Offset point, double radius) {
  String? best;
  var bestDistance = radius;
  for (final id in run.revealed) {
    final p = run.galaxy[id].position;
    final d = (Offset(p.x, p.y) - point).distance;
    if (d <= bestDistance) {
      best = id;
      bestDistance = d;
    }
  }
  return best;
}

enum _MarkerStatus { here, hellEntry, gateway, sublight, visited, known }

class _SystemMarker extends StatelessWidget {
  const _SystemMarker({
    required this.name,
    required this.status,
    required this.selected,
    required this.onSelect,
  });

  final String name;
  final _MarkerStatus status;
  final bool selected;

  /// For screen readers only. Taps are handled by [GalaxyView].
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final (color, size) = switch (status) {
      _MarkerStatus.here => (Palette.gateway, 18.0),
      _MarkerStatus.hellEntry => (Palette.hell, 18.0),
      _MarkerStatus.gateway => (Colors.white, 14.0),
      _MarkerStatus.sublight => (Palette.sublight, 13.0),
      _MarkerStatus.visited => (const Color(0xFFB8C2D6), 10.0),
      _MarkerStatus.known => (Palette.muted, 9.0),
    };
    final bright =
        status != _MarkerStatus.known && status != _MarkerStatus.visited;
    return Semantics(
      button: true,
      label: name,
      onTap: onSelect,
      child: IgnorePointer(
        child: Column(
          children: [
            SizedBox.square(
              dimension: 32,
              child: Center(
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: selected
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                    boxShadow: [
                      if (bright)
                        BoxShadow(
                          color: color.withValues(alpha: 0.8),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      if (status == _MarkerStatus.here)
                        BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 2,
                          spreadRadius: 9,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bright ? FontWeight.w600 : FontWeight.w400,
                color: bright ? Colors.white : const Color(0xFFC8D0E0),
                shadows: const [Shadow(blurRadius: 4), Shadow(blurRadius: 8)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutesPainter extends CustomPainter {
  _RoutesPainter(this.run, this.routes, this.zoom);

  final RunState run;
  final List<Route> routes;
  final double zoom;

  Offset _at(String id) {
    final p = run.galaxy[id].position;
    return Offset(p.x, p.y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final px = 1 / zoom;
    final fromHere = {for (final r in routes) r.to};
    bool visible(String a, String b) =>
        run.revealed.contains(a) && run.revealed.contains(b);
    bool outbound(String a, String b) =>
        (a == run.location && fromHere.contains(b)) ||
        (b == run.location && fromHere.contains(a));

    for (final lane in run.galaxy.lanes) {
      if (!visible(lane.a, lane.b)) continue;
      final hot = outbound(lane.a, lane.b);
      _dashed(
        canvas,
        _at(lane.a),
        _at(lane.b),
        Paint()
          ..color = Palette.sublight.withValues(alpha: hot ? 0.95 : 0.5)
          ..strokeWidth = (hot ? 2.5 : 1.5) * px
          ..strokeCap = StrokeCap.round,
        dash: 2 * px,
        gap: 7 * px,
      );
    }

    for (final gate in run.galaxy.gateways) {
      if (!visible(gate.a, gate.b)) continue;
      final a = _at(gate.a);
      final b = _at(gate.b);
      if (!run.isGatewayActive(gate)) {
        _dashed(
          canvas,
          a,
          b,
          Paint()
            ..color = Palette.deadGateway.withValues(alpha: 0.7)
            ..strokeWidth = 1.5 * px,
          dash: 10 * px,
          gap: 8 * px,
        );
        continue;
      }
      final hot = outbound(gate.a, gate.b);
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = Palette.gateway.withValues(alpha: hot ? 0.45 : 0.18)
          ..strokeWidth = (hot ? 9 : 6) * px
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * px),
      );
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = Palette.gateway.withValues(alpha: hot ? 1 : 0.6)
          ..strokeWidth = (hot ? 2.5 : 1.5) * px,
      );
    }
  }

  void _dashed(
    Canvas canvas,
    Offset a,
    Offset b,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
    final total = (b - a).distance;
    final dir = (b - a) / total;
    for (var d = 0.0; d < total; d += dash + gap) {
      canvas.drawLine(a + dir * d, a + dir * min(d + dash, total), paint);
    }
  }

  @override
  bool shouldRepaint(_RoutesPainter old) =>
      old.run != run || old.zoom != zoom || old.routes != routes;
}
