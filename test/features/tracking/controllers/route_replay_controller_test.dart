import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_background_gps_demo/features/tracking/controllers/route_replay_controller.dart';

void main() {
  test('replay progresses, pauses, changes speed, and disposes', () async {
    final controller = RouteReplayController(
      pointCount: 4,
      baseInterval: const Duration(milliseconds: 80),
    );

    controller.togglePlayback();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(controller.selectedIndex, 1);

    controller.setSpeed(2);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(controller.selectedIndex, 2);

    controller.pause();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(controller.selectedIndex, 2);
    expect(controller.isPlaying, isFalse);

    controller.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(controller.selectedIndex, 2);
  });

  test('empty and single-point replay never starts', () {
    final empty = RouteReplayController(pointCount: 0);
    final single = RouteReplayController(pointCount: 1);

    empty.togglePlayback();
    single.togglePlayback();

    expect(empty.isPlaying, isFalse);
    expect(single.isPlaying, isFalse);
    empty.dispose();
    single.dispose();
  });
}
