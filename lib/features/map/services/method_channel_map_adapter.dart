import 'package:flutter/services.dart';

import '../models/map_display_state.dart';
import 'map_adapter.dart';

class MethodChannelMapAdapter implements MapAdapter {
  MethodChannelMapAdapter(int viewId)
    : _channel = MethodChannel(
        'com.andromind.oppo_background_gps_demo/amap_map_$viewId',
      );

  final MethodChannel _channel;

  void setMethodCallHandler(Future<void> Function(MethodCall)? handler) {
    _channel.setMethodCallHandler(handler);
  }

  @override
  Future<void> updateState(MapDisplayState state) =>
      _channel.invokeMethod<void>('updateState', state.toPlatformMap());

  @override
  Future<bool> recenter() async =>
      await _channel.invokeMethod<bool>('recenter') ?? false;

  @override
  Future<bool> fitRoute() async =>
      await _channel.invokeMethod<bool>('fitRoute') ?? false;

  @override
  Future<void> setOptions(MapDisplayState state) =>
      _channel.invokeMethod<void>('setOptions', state.toPlatformMap());

  @override
  Future<void> dispose() async {
    setMethodCallHandler(null);
  }
}
