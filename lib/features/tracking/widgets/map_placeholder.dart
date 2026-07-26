import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/location_record.dart';

class MapPlaceholder extends StatelessWidget {
  const MapPlaceholder({
    required this.routePoints,
    required this.latestLocation,
    required this.followLocation,
    super.key,
  });

  final List<LocationRecord> routePoints;
  final LocationRecord? latestLocation;
  final bool followLocation;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 330,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1F7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD0D5DD)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _FakeMapPainter(
                routePoints: routePoints,
                latestLocation: latestLocation,
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: _MapLabel(icon: Icons.layers_outlined, label: 'FAKE MAP'),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: _MapLabel(
              icon: followLocation
                  ? Icons.gps_fixed_rounded
                  : Icons.gps_not_fixed_rounded,
              label: followLocation ? 'FOLLOWING' : 'FREE VIEW',
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFF155EEF),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      latestLocation == null
                          ? 'Waiting for the first simulated sample'
                          : '${latestLocation!.latitude.toStringAsFixed(6)}, '
                                '${latestLocation!.longitude.toStringAsFixed(6)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF344054),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${routePoints.length} pts',
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapLabel extends StatelessWidget {
  const _MapLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF475467)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF475467),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FakeMapPainter extends CustomPainter {
  const _FakeMapPainter({
    required this.routePoints,
    required this.latestLocation,
  });

  final List<LocationRecord> routePoints;
  final LocationRecord? latestLocation;

  @override
  void paint(Canvas canvas, Size size) {
    _paintMapBackground(canvas, size);

    final points = _screenPoints(size);
    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF1570EF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    for (final point in points) {
      canvas.drawCircle(point, 3.2, Paint()..color = const Color(0xFF84ADFF));
    }

    final markerPoint = points.isNotEmpty
        ? points.last
        : Offset(size.width * 0.52, size.height * 0.46);
    _paintCurrentMarker(canvas, markerPoint);
  }

  void _paintMapBackground(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFEAF1F7),
    );

    final blockPaint = Paint()..color = const Color(0xFFDDE8E1);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.05,
          size.height * 0.16,
          size.width * 0.22,
          size.height * 0.25,
        ),
        const Radius.circular(14),
      ),
      blockPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.72,
          size.height * 0.48,
          size.width * 0.24,
          size.height * 0.23,
        ),
        const Radius.circular(14),
      ),
      blockPaint,
    );

    final minorRoad = Paint()
      ..color = Colors.white.withValues(alpha: 0.72)
      ..strokeWidth = 3;
    for (var x = -size.height; x < size.width; x += 64) {
      canvas.drawLine(
        Offset(x.toDouble(), 0),
        Offset(x + size.height, size.height),
        minorRoad,
      );
    }
    for (var y = 48.0; y < size.height; y += 66) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 24), minorRoad);
    }

    final mainRoadBorder = Paint()
      ..color = const Color(0xFFD5DEE7)
      ..strokeWidth = 17
      ..style = PaintingStyle.stroke;
    final mainRoad = Paint()
      ..color = const Color(0xFFFDFEFF)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke;
    final roadPath = Path()
      ..moveTo(-10, size.height * 0.78)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.62,
        size.width * 0.55,
        size.height * 0.76,
        size.width + 10,
        size.height * 0.32,
      );
    canvas
      ..drawPath(roadPath, mainRoadBorder)
      ..drawPath(roadPath, mainRoad);
  }

  List<Offset> _screenPoints(Size size) {
    if (routePoints.isEmpty) {
      return const [];
    }

    var minLatitude = routePoints.first.latitude;
    var maxLatitude = routePoints.first.latitude;
    var minLongitude = routePoints.first.longitude;
    var maxLongitude = routePoints.first.longitude;

    for (final point in routePoints.skip(1)) {
      minLatitude = math.min(minLatitude, point.latitude);
      maxLatitude = math.max(maxLatitude, point.latitude);
      minLongitude = math.min(minLongitude, point.longitude);
      maxLongitude = math.max(maxLongitude, point.longitude);
    }

    const minimumSpan = 0.0007;
    final latitudeCenter = (minLatitude + maxLatitude) / 2;
    final longitudeCenter = (minLongitude + maxLongitude) / 2;
    final latitudeSpan = math.max(maxLatitude - minLatitude, minimumSpan);
    final longitudeSpan = math.max(maxLongitude - minLongitude, minimumSpan);
    minLatitude = latitudeCenter - (latitudeSpan / 2);
    maxLatitude = latitudeCenter + (latitudeSpan / 2);
    minLongitude = longitudeCenter - (longitudeSpan / 2);
    maxLongitude = longitudeCenter + (longitudeSpan / 2);

    const horizontalPadding = 42.0;
    const topPadding = 58.0;
    const bottomPadding = 78.0;
    final drawableWidth = size.width - (horizontalPadding * 2);
    final drawableHeight = size.height - topPadding - bottomPadding;

    return routePoints.map((point) {
      final x =
          horizontalPadding +
          ((point.longitude - minLongitude) /
              (maxLongitude - minLongitude) *
              drawableWidth);
      final y =
          topPadding +
          ((maxLatitude - point.latitude) /
              (maxLatitude - minLatitude) *
              drawableHeight);
      return Offset(x, y);
    }).toList();
  }

  void _paintCurrentMarker(Canvas canvas, Offset point) {
    canvas.drawCircle(point, 19, Paint()..color = const Color(0x331570EF));
    canvas.drawCircle(point, 11, Paint()..color = Colors.white);
    canvas.drawCircle(point, 7, Paint()..color = const Color(0xFF155EEF));
    canvas.drawCircle(
      point.translate(-2, -2),
      2,
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );
  }

  @override
  bool shouldRepaint(covariant _FakeMapPainter oldDelegate) {
    return oldDelegate.routePoints != routePoints ||
        oldDelegate.latestLocation != latestLocation;
  }
}
