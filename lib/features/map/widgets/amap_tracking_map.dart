import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/tracking_map_controller.dart';
import '../models/map_display_state.dart';
import '../services/method_channel_map_adapter.dart';

class AmapTrackingMap extends StatefulWidget {
  const AmapTrackingMap({
    required this.state,
    required this.controller,
    required this.onUserGesture,
    required this.onInitializationFailed,
    this.height = 340,
    super.key,
  });

  static const viewType =
      'com.andromind.oppo_background_gps_demo/amap_tracking_map';

  final MapDisplayState state;
  final TrackingMapController controller;
  final VoidCallback onUserGesture;
  final VoidCallback onInitializationFailed;
  final double height;

  @override
  State<AmapTrackingMap> createState() => _AmapTrackingMapState();
}

class _AmapTrackingMapState extends State<AmapTrackingMap> {
  bool _mapLoaded = false;

  @override
  void didUpdateWidget(covariant AmapTrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller.update(widget.state);
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return _MapMessage(
        height: widget.height,
        message: 'AMap rendering is available in the Android application.',
      );
    }
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: AndroidView(
                viewType: AmapTrackingMap.viewType,
                creationParams: widget.state.toPlatformMap(),
                creationParamsCodec: const StandardMessageCodec(),
                onPlatformViewCreated: (viewId) {
                  final adapter = MethodChannelMapAdapter(viewId);
                  adapter.setMethodCallHandler((call) async {
                    if (call.method == 'onUserGesture') {
                      widget.onUserGesture();
                    } else if (call.method == 'onMapLoaded' && mounted) {
                      setState(() => _mapLoaded = true);
                    } else if (call.method == 'onAmapInitializationFailed') {
                      widget.onInitializationFailed();
                    }
                  });
                  widget.controller.attach(adapter);
                  widget.controller.update(widget.state);
                },
              ),
            ),
            if (!_mapLoaded)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x99FFFFFF),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text('Loading AMap...'),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MapMessage extends StatelessWidget {
  const _MapMessage({required this.height, required this.message});

  final double height;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1F7),
        border: Border.all(color: const Color(0xFFD0D5DD)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
