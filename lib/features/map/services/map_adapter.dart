import '../models/map_display_state.dart';

abstract interface class MapAdapter {
  Future<void> updateState(MapDisplayState state);

  Future<bool> recenter();

  Future<bool> fitRoute();

  Future<void> setOptions(MapDisplayState state);

  Future<void> dispose();
}
