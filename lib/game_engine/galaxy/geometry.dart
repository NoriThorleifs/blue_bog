import 'dart:math';

Point<double> polar(Point<double> from, double r, double angle) =>
    Point(from.x + r * cos(angle), from.y + r * sin(angle));

double bearingFrom(Point<double> from, Point<double> to) =>
    atan2(to.y - from.y, to.x - from.x);

double degrees(double deg) => deg * pi / 180;

double _cross(Point<double> o, Point<double> a, Point<double> b) =>
    (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);

bool segmentsCross(
  Point<double> a,
  Point<double> b,
  Point<double> c,
  Point<double> d,
) {
  final d1 = _cross(c, d, a);
  final d2 = _cross(c, d, b);
  final d3 = _cross(a, b, c);
  final d4 = _cross(a, b, d);
  return ((d1 > 0) != (d2 > 0)) && ((d3 > 0) != (d4 > 0));
}

double distanceToSegment(Point<double> p, Point<double> a, Point<double> b) {
  final ab = b - a;
  final lengthSquared = ab.x * ab.x + ab.y * ab.y;
  final t = lengthSquared == 0
      ? 0.0
      : (((p.x - a.x) * ab.x + (p.y - a.y) * ab.y) / lengthSquared).clamp(
          0.0,
          1.0,
        );
  return p.distanceTo(Point(a.x + ab.x * t, a.y + ab.y * t));
}
