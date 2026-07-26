import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/map_display_state.dart';
import '../services/map_adapter.dart';

class TrackingMapController extends ChangeNotifier {
  MapAdapter? _adapter;
  MapDisplayState? _pendingState;
  bool _disposed = false;

  bool get isReady => _adapter != null;

  void attach(MapAdapter adapter) {
    if (_disposed) {
      unawaited(adapter.dispose());
      return;
    }
    unawaited(_adapter?.dispose());
    _adapter = adapter;
    final pending = _pendingState;
    if (pending != null) {
      unawaited(adapter.updateState(pending));
    }
    notifyListeners();
  }

  void update(MapDisplayState state) {
    if (_disposed) {
      return;
    }
    _pendingState = state;
    final adapter = _adapter;
    if (adapter != null) {
      unawaited(adapter.updateState(state));
    }
  }

  Future<bool> recenter() async => await _adapter?.recenter() ?? false;

  Future<bool> fitRoute() async => await _adapter?.fitRoute() ?? false;

  @override
  void dispose() {
    _disposed = true;
    unawaited(_adapter?.dispose());
    _adapter = null;
    super.dispose();
  }

  bool get isDisposed => _disposed;
}
