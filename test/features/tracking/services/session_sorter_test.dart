import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_background_gps_demo/features/tracking/services/session_sorter.dart';
import 'package:oppo_background_gps_demo/features/tracking/services/tracking_models.dart';

void main() {
  test('sorts sessions newest first using start then modified time', () {
    final sessions = sortSessionsNewestFirst([
      TrackingSession(
        sessionId: 'old',
        fileName: 'old.csv',
        startTimestamp: DateTime.utc(2026, 1, 1),
      ),
      TrackingSession(
        sessionId: 'new',
        fileName: 'new.csv',
        startTimestamp: DateTime.utc(2026, 2, 1),
      ),
    ]);

    expect(sessions.map((session) => session.sessionId), ['new', 'old']);
  });
}
