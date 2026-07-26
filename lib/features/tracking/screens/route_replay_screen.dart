import 'package:flutter/material.dart';

import '../../map/controllers/tracking_map_controller.dart';
import '../../map/models/map_display_state.dart';
import '../../map/models/map_point.dart';
import '../../map/services/tracking_map_adapter.dart';
import '../../map/widgets/map_configuration_card.dart';
import '../models/location_record.dart';
import '../controllers/route_replay_controller.dart';
import '../services/tracking_models.dart';

class RouteReplayScreen extends StatefulWidget {
  const RouteReplayScreen({
    required this.session,
    required this.sessionRecords,
    required this.configuration,
    required this.engineConfiguration,
    required this.preferences,
    required this.onShare,
    this.trackingMapAdapter,
    super.key,
  });

  final TrackingSession session;
  final TrackingSessionRecords sessionRecords;
  final AmapConfiguration configuration;
  final LocationEngineConfiguration engineConfiguration;
  final TrackingMapPreferences preferences;
  final Future<bool> Function() onShare;
  final TrackingMapAdapter? trackingMapAdapter;

  @override
  State<RouteReplayScreen> createState() => _RouteReplayScreenState();
}

class _RouteReplayScreenState extends State<RouteReplayScreen> {
  final TrackingMapController _mapController = TrackingMapController();
  late final RouteReplayController _replayController;
  bool _amapFailed = false;

  List<LocationRecord> get _records => widget.sessionRecords.records;

  @override
  void initState() {
    super.initState();
    _replayController = RouteReplayController(pointCount: _records.length)
      ..addListener(_onReplayChanged);
  }

  @override
  void dispose() {
    _replayController
      ..removeListener(_onReplayChanged)
      ..dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _records.isEmpty
        ? null
        : _records[_replayController.selectedIndex];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Replay'),
        actions: [
          IconButton(
            tooltip: 'Share session CSV',
            onPressed: _share,
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          if (!widget.configuration.apiKeyConfigured) ...[
            const MapConfigurationCard(),
            const SizedBox(height: 10),
          ],
          _mapAdapter.buildReplayMap(
            controller: _mapController,
            state: MapDisplayState(
              routePoints: _displayPoints(
                selected == null
                    ? const []
                    : _records
                          .take(_replayController.selectedIndex + 1)
                          .toList(),
              ),
              selectedPoint: selected == null
                  ? null
                  : MapPoint.fromLocationRecord(selected),
              followLocation: false,
              preferences: widget.preferences,
            ),
            onInitializationFailed: () {
              if (mounted) {
                setState(() => _amapFailed = true);
              }
            },
          ),
          const SizedBox(height: 12),
          if (_records.isEmpty)
            const _ReplayMessage(
              message: 'This session has no readable points.',
            )
          else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Slider(
                      value: _replayController.selectedIndex.toDouble(),
                      min: 0,
                      max: (_records.length - 1).toDouble(),
                      divisions: _records.length > 1 ? _records.length - 1 : 1,
                      label:
                          '${_replayController.selectedIndex + 1}/${_records.length}',
                      onChanged: (value) {
                        _replayController.select(value.round());
                      },
                    ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: [
                        IconButton.filledTonal(
                          tooltip: 'Previous point',
                          onPressed: _replayController.selectedIndex > 0
                              ? _replayController.previous
                              : null,
                          icon: const Icon(Icons.skip_previous),
                        ),
                        IconButton.filled(
                          tooltip: _replayController.isPlaying
                              ? 'Pause'
                              : 'Play',
                          onPressed: _replayController.togglePlayback,
                          icon: Icon(
                            _replayController.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                          ),
                        ),
                        IconButton.filledTonal(
                          tooltip: 'Next point',
                          onPressed:
                              _replayController.selectedIndex <
                                  _records.length - 1
                              ? _replayController.next
                              : null,
                          icon: const Icon(Icons.skip_next),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _mapController.fitRoute(),
                          icon: const Icon(Icons.fit_screen),
                          label: const Text('Fit Route'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 1, label: Text('1x')),
                        ButtonSegment(value: 2, label: Text('2x')),
                        ButtonSegment(value: 4, label: Text('4x')),
                      ],
                      selected: {_replayController.speed},
                      onSelectionChanged: (values) {
                        _replayController.setSpeed(values.first);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _PointDetails(record: selected!),
          ],
          if (widget.sessionRecords.skippedRows > 0) ...[
            const SizedBox(height: 12),
            _ReplayMessage(
              message:
                  '${widget.sessionRecords.skippedRows} corrupted CSV '
                  'row(s) were skipped.',
            ),
          ],
          if (widget.sessionRecords.locationEngine == 'LEGACY') ...[
            const SizedBox(height: 12),
            const _ReplayMessage(
              message:
                  'Legacy WGS84 points are converted only for AMap display. '
                  'The original CSV remains unchanged and routes in mainland '
                  'China may still show an offset.',
            ),
          ],
        ],
      ),
    );
  }

  TrackingMapAdapter get _mapAdapter {
    final injected = widget.trackingMapAdapter;
    if (injected != null) {
      return injected;
    }
    final canUseAmap =
        !_amapFailed &&
        widget.configuration.canUseAmap &&
        widget.engineConfiguration.shouldUseAmapMap &&
        widget.configuration.runtimeState != AmapRuntimeState.failed;
    if (canUseAmap) {
      return const AmapTrackingMapAdapter();
    }
    return FallbackRouteMapAdapter(
      reason: !widget.configuration.apiKeyConfigured
          ? 'AMap key not configured'
          : widget.engineConfiguration.fallbackReason ??
                widget.engineConfiguration.amapUnavailableReason ??
                'Android GPS Demo Mode',
    );
  }

  void _onReplayChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _share() async {
    final shared = await widget.onShare();
    if (!mounted || shared) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to share this session CSV.')),
    );
  }
}

List<MapPoint> _displayPoints(List<LocationRecord> records) {
  const limit = 2000;
  if (records.length <= limit) {
    return records.map(MapPoint.fromLocationRecord).toList(growable: false);
  }
  final stride = (records.length / limit).ceil();
  final sampled = <MapPoint>[
    for (var index = 0; index < records.length; index += stride)
      MapPoint.fromLocationRecord(records[index]),
  ];
  final last = MapPoint.fromLocationRecord(records.last);
  if (sampled.last.latitude != last.latitude ||
      sampled.last.longitude != last.longitude) {
    sampled.add(last);
  }
  return sampled;
}

class _PointDetails extends StatelessWidget {
  const _PointDetails({required this.record});

  final LocationRecord record;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Timestamp', record.formattedTimestamp),
      (
        'Coordinates',
        '${record.latitude.toStringAsFixed(6)}, '
            '${record.longitude.toStringAsFixed(6)}',
      ),
      ('Accuracy', '${record.accuracyMeters.toStringAsFixed(1)} m'),
      (
        'Speed',
        '${((record.speedMetersPerSecond ?? 0) * 3.6).toStringAsFixed(1)} km/h',
      ),
      ('Screen', record.screenState ?? 'Unknown'),
      ('Provider', record.provider ?? 'Unknown'),
      ('AMap type', '${record.amapLocationType ?? 'Unknown'}'),
      ('Coordinate system', record.coordinateSystem),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final (label, value) in rows)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(label),
                trailing: SizedBox(
                  width: 180,
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReplayMessage extends StatelessWidget {
  const _ReplayMessage({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}
