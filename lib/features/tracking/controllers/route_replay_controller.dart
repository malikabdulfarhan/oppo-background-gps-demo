import 'dart:async';

import 'package:flutter/foundation.dart';

class RouteReplayController extends ChangeNotifier {
  RouteReplayController({
    required this.pointCount,
    this.baseInterval = const Duration(milliseconds: 800),
  });

  final int pointCount;
  final Duration baseInterval;
  Timer? _timer;
  int _selectedIndex = 0;
  int _speed = 1;
  bool _playing = false;
  bool _disposed = false;

  int get selectedIndex => _selectedIndex;
  int get speed => _speed;
  bool get isPlaying => _playing;

  void select(int index) {
    pause();
    if (pointCount == 0) {
      _selectedIndex = 0;
    } else {
      _selectedIndex = index.clamp(0, pointCount - 1);
    }
    notifyListeners();
  }

  void previous() => select(_selectedIndex - 1);

  void next() => select(_selectedIndex + 1);

  void setSpeed(int value) {
    if (value != 1 && value != 2 && value != 4) {
      return;
    }
    _speed = value;
    if (_playing) {
      _startTimer();
    }
    notifyListeners();
  }

  void togglePlayback() {
    if (_playing) {
      pause();
      return;
    }
    if (pointCount <= 1) {
      return;
    }
    if (_selectedIndex >= pointCount - 1) {
      _selectedIndex = 0;
    }
    _playing = true;
    _startTimer();
    notifyListeners();
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
    if (_playing) {
      _playing = false;
      notifyListeners();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(microseconds: baseInterval.inMicroseconds ~/ _speed),
      (_) {
        if (_disposed || _selectedIndex >= pointCount - 1) {
          pause();
          return;
        }
        _selectedIndex += 1;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
