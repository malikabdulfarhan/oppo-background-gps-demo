import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/map_display_state.dart';
import '../models/map_point.dart';

class FallbackRouteMap extends StatelessWidget {
  const FallbackRouteMap({
    required this.state,
    this.reason = 'AMap key not configured',
    this.height = 340,
    super.key,
  });

  final MapDisplayState state;
  final String reason;
  final double height;

  @override
  Widget build(BuildContext context) {
    final current = state.selectedPoint ?? state.currentLocation;
    return Semantics(
      label: 'Fallback route preview',
      child: Container(
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAFC),
          border: Border.all(color: const Color(0xFFD0D5DD)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _FallbackRoutePainter(
                  routePoints: state.routePoints,
                  currentLocation: state.currentLocation,
                  selectedPoint: state.selectedPoint,
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: _MapLabel(
                title: 'ROUTE PREVIEW',
                subtitle: 'Route Preview — $reason',
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _MapLabel(
                title: current == null
                    ? 'Waiting for the first GPS sample'
                    : '${current.latitude.toStringAsFixed(6)}, '
                          '${current.longitude.toStringAsFixed(6)}',
                subtitle: current == null
                    ? 'Android GPS Demo Mode is ready • '
                          'Follow ${state.followLocation ? 'on' : 'off'}'
                    : 'Live GPS route recorded on this device'
                          '${current.accuracyMeters == null ? '' : ' • ±${current.accuracyMeters!.toStringAsFixed(1)} m'}'
                          ' • Follow ${state.followLocation ? 'on' : 'off'}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapLabel extends StatelessWidget {
  const _MapLabel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xEFFFFFFF),
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [
        BoxShadow(
          color: Color(0x22000000),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Color(0xFF475467)),
          ),
        ],
      ),
    ),
  );
}

class _FallbackRoutePainter extends CustomPainter {
  const _FallbackRoutePainter({
    required this.routePoints,
    this.currentLocation,
    this.selectedPoint,
  });

  final List<MapPoint> routePoints;
  final MapPoint? currentLocation;
  final MapPoint? selectedPoint;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFE4EAF0)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 36) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y < size.height; y += 36) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final points = <MapPoint>[...routePoints, ?currentLocation, ?selectedPoint];
    if (points.isEmpty) {
      return;
    }
    final projection = _Projection(points, size);
    if (routePoints.length > 1) {
      final path = Path();
      for (var index = 0; index < routePoints.length; index++) {
        final offset = projection.offset(routePoints[index]);
        if (index == 0) {
          path.moveTo(offset.dx, offset.dy);
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF1570EF)
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    if (routePoints.isNotEmpty) {
      _drawMarker(
        canvas,
        projection.offset(routePoints.first),
        const Color(0xFF12B76A),
        6,
      );
      _drawMarker(
        canvas,
        projection.offset(routePoints.last),
        const Color(0xFF175CD3),
        6,
      );
    }
    if (currentLocation case final point?) {
      final offset = projection.offset(point);
      final accuracy = point.accuracyMeters;
      if (accuracy != null && accuracy.isFinite && accuracy > 0) {
        final radius = math.min(42.0, math.max(10.0, accuracy / 3));
        canvas.drawCircle(
          offset,
          radius,
          Paint()..color = const Color(0x281570EF),
        );
      }
      _drawMarker(canvas, offset, const Color(0xFF1570EF), 8);
    }
    if (selectedPoint case final point?) {
      _drawMarker(canvas, projection.offset(point), const Color(0xFFF79009), 8);
    }
  }

  void _drawMarker(Canvas canvas, Offset offset, Color color, double radius) {
    canvas
      ..drawCircle(offset, radius + 3, Paint()..color = Colors.white)
      ..drawCircle(offset, radius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _FallbackRoutePainter oldDelegate) =>
      oldDelegate.routePoints != routePoints ||
      oldDelegate.currentLocation != currentLocation ||
      oldDelegate.selectedPoint != selectedPoint;
}

class _Projection {
  _Projection(List<MapPoint> points, this.size)
    : minLatitude = points.map((point) => point.latitude).reduce(math.min),
      maxLatitude = points.map((point) => point.latitude).reduce(math.max),
      minLongitude = points.map((point) => point.longitude).reduce(math.min),
      maxLongitude = points.map((point) => point.longitude).reduce(math.max);

  final Size size;
  final double minLatitude;
  final double maxLatitude;
  final double minLongitude;
  final double maxLongitude;

  Offset offset(MapPoint point) {
    const padding = 42.0;
    final width = math.max(1.0, size.width - padding * 2);
    final height = math.max(1.0, size.height - padding * 2);
    final longitudeRange = math.max(0.00001, maxLongitude - minLongitude);
    final latitudeRange = math.max(0.00001, maxLatitude - minLatitude);
    final x =
        padding + (point.longitude - minLongitude) / longitudeRange * width;
    final y = padding + (maxLatitude - point.latitude) / latitudeRange * height;
    return Offset(x, y);
  }
}
