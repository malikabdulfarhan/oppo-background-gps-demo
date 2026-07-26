import 'tracking_models.dart';

List<TrackingSession> sortSessionsNewestFirst(
  Iterable<TrackingSession> sessions,
) {
  final sorted = sessions.toList();
  sorted.sort(
    (first, second) =>
        (second.startTimestamp ?? second.lastModified ?? DateTime(1970))
            .compareTo(
              first.startTimestamp ?? first.lastModified ?? DateTime(1970),
            ),
  );
  return sorted;
}
