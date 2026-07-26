import 'dart:async';

import 'package:flutter/material.dart';

import '../analytics/route_metrics.dart';
import '../analytics/route_metrics_calculator.dart';
import '../controllers/tracking_controller.dart';
import '../services/tracking_models.dart';
import '../services/session_sorter.dart';
import 'route_replay_screen.dart';

class SessionHistoryScreen extends StatefulWidget {
  const SessionHistoryScreen({
    required this.controller,
    this.refreshToken = 0,
    super.key,
  });

  final TrackingController controller;
  final int refreshToken;

  @override
  State<SessionHistoryScreen> createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends State<SessionHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<TrackingSession> _sessions = const [];
  final Map<String, TrackingSessionRecords> _records = {};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant SessionHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      unawaited(_load());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_sessions.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 140),
            Icon(Icons.history_toggle_off, size: 56, color: Color(0xFF98A2B3)),
            SizedBox(height: 12),
            Center(child: Text('No previous tracking sessions')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        itemCount: _sessions.length + (_error == null ? 0 : 1),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (_error != null && index == 0) {
            return Card(
              color: const Color(0xFFFFF4ED),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(_error!),
              ),
            );
          }
          final session = _sessions[index - (_error == null ? 0 : 1)];
          return _SessionCard(
            session: session,
            details: _records[session.sessionId],
            device:
                '${widget.controller.batteryStatus.manufacturer} '
                '${widget.controller.batteryStatus.model}',
            onViewRoute: () => _openReplay(session),
            onShare: () => _share(session),
            onSummary: () => _showSummary(session),
            onDelete: () => _delete(session),
          );
        },
      ),
    );
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final sessions = sortSessionsNewestFirst(
        await widget.controller.listTrackingSessions(),
      );
      final details = await Future.wait(
        sessions.map((session) async {
          final records = await widget.controller.getSessionRecords(
            session.sessionId,
          );
          return MapEntry(session.sessionId, records);
        }),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _sessions = sessions;
        _records
          ..clear()
          ..addEntries(details);
      });
    } on Object catch (error) {
      debugPrint('Session history load failed: $error');
      if (mounted) {
        setState(
          () => _error =
              'Unable to load session history. Pull down to try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openReplay(TrackingSession session) async {
    final details = _records[session.sessionId];
    if (details == null || !mounted) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RouteReplayScreen(
          session: session,
          sessionRecords: details,
          configuration: widget.controller.amapConfiguration,
          engineConfiguration: widget.controller.locationEngineConfiguration,
          preferences: widget.controller.mapPreferences,
          onShare: () => widget.controller.shareSessionLog(session.sessionId),
        ),
      ),
    );
  }

  Future<void> _share(TrackingSession session) async {
    final shared = await widget.controller.shareSessionLog(session.sessionId);
    if (!mounted || shared) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to share this session CSV.')),
    );
  }

  Future<void> _delete(TrackingSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete session?'),
        content: Text('Delete ${session.fileName}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final result = await widget.controller.deleteSession(session.sessionId);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) {
      await _load();
    }
  }

  Future<void> _showSummary(TrackingSession session) async {
    final details = _records[session.sessionId];
    if (details == null) {
      return;
    }
    final metrics = const RouteMetricsCalculator().calculate(
      details.records,
      additionalAmapErrors: details.amapErrorCount,
    );
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session summary'),
        content: Text(
          'Duration: ${RouteMetrics.formatDuration(metrics.duration)}\n'
          'Samples: ${metrics.totalSamples}\n'
          'Route points: ${metrics.uniqueRoutePoints}\n'
          'Distance: ${RouteMetrics.formatDistance(metrics.distanceMeters)}\n'
          'Average accuracy: '
          '${metrics.averageAccuracyMeters.toStringAsFixed(1)} m\n'
          'Longest gap: '
          '${RouteMetrics.formatDuration(metrics.longestUpdateGap)}\n'
          'Locked-screen samples: ${metrics.lockedScreenSamples}\n'
          'AMap errors: ${metrics.amapErrorCount}\n'
          'Skipped rows: ${details.skippedRows}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.details,
    required this.device,
    required this.onViewRoute,
    required this.onShare,
    required this.onSummary,
    required this.onDelete,
  });

  final TrackingSession session;
  final TrackingSessionRecords? details;
  final String device;
  final VoidCallback onViewRoute;
  final VoidCallback onShare;
  final VoidCallback onSummary;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final metrics = const RouteMetricsCalculator().calculate(
      details?.records ?? const [],
      additionalAmapErrors: details?.amapErrorCount ?? session.amapErrorCount,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _date(session.startTimestamp ?? session.lastModified),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    session.isActive ? 'Active' : session.locationEngine,
                  ),
                ),
              ],
            ),
            Text(
              session.isActive
                  ? 'End: Active'
                  : 'End: ${_date(session.endTimestamp)}',
            ),
            const SizedBox(height: 8),
            Text(
              '${RouteMetrics.formatDuration(metrics.duration)} • '
              '${metrics.totalSamples} samples • '
              '${metrics.uniqueRoutePoints} points • '
              '${RouteMetrics.formatDistance(metrics.distanceMeters)}',
            ),
            Text(
              'Avg accuracy ${metrics.averageAccuracyMeters.toStringAsFixed(1)} m • '
              'Longest gap ${RouteMetrics.formatDuration(metrics.longestUpdateGap)} • '
              '${metrics.lockedScreenSamples} locked',
            ),
            const SizedBox(height: 6),
            Text(
              '${session.fileName}\n$device',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if ((details?.skippedRows ?? session.skippedRows) > 0)
              Text(
                '${details?.skippedRows ?? session.skippedRows} corrupted '
                'row(s) skipped',
                style: const TextStyle(color: Color(0xFFB54708)),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: onViewRoute,
                  icon: const Icon(Icons.route),
                  label: const Text('View Route'),
                ),
                TextButton(onPressed: onSummary, child: const Text('Summary')),
                TextButton(onPressed: onShare, child: const Text('Share CSV')),
                TextButton(
                  onPressed: session.isActive ? null : onDelete,
                  child: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _date(DateTime? value) =>
      value?.toLocal().toString().split('.').first ?? 'Unknown';
}
