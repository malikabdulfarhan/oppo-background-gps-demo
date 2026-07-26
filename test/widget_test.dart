import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_background_gps_demo/features/chat/models/chat_configuration.dart';
import 'package:oppo_background_gps_demo/features/chat/models/chat_conversation.dart';
import 'package:oppo_background_gps_demo/features/chat/models/chat_user.dart';
import 'package:oppo_background_gps_demo/features/map/controllers/tracking_map_controller.dart';
import 'package:oppo_background_gps_demo/features/map/models/map_display_state.dart';
import 'package:oppo_background_gps_demo/features/map/services/tracking_map_adapter.dart';
import 'package:oppo_background_gps_demo/features/tracking/models/location_record.dart';
import 'package:oppo_background_gps_demo/features/tracking/screens/tracking_screen.dart';
import 'package:oppo_background_gps_demo/features/tracking/services/tracking_models.dart';
import 'package:oppo_background_gps_demo/features/tracking/services/tracking_service.dart';

import 'features/chat/fake_chat_service.dart';

void main() {
  testWidgets('tracking screen starts native service and displays an event', (
    tester,
  ) async {
    final service = _WidgetFakeTrackingService();
    final localChat = FakeChatService(
      providerType: ChatProviderType.localDemo,
      conversations: const [
        ChatConversation(
          id: 'local_dispatch',
          participant: ChatUser(
            userId: 'dispatch',
            displayName: 'Dispatch Coordinator',
          ),
          providerType: ChatProviderType.localDemo,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TrackingScreen(
          trackingService: service,
          trackingMapAdapter: const _WidgetFakeMapAdapter(),
          localChatService: localChat,
          tencentChatService: FakeChatService(
            providerType: ChatProviderType.tencentCloud,
            isConfigured: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Map Track Demo'), findsOneWidget);
    expect(find.text('Stopped'), findsOneWidget);
    expect(find.text('5000 ms'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Diagnostics'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    expect(
      find.text('Local UI Demo — Not connected to Tencent Cloud'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Stop'), findsNothing);
    await tester.tap(find.text('Dispatch Coordinator'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Share current tracking status'));
    await tester.pump();
    expect(find.text('No location sample is available yet.'), findsOneWidget);
    expect(service.startCalls, 0);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Live'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, 'Stop'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Start Tracking'));
    await tester.pumpAndSettle();

    expect(find.text('Running in background'), findsOneWidget);

    service.emitLocation(
      LocationRecord(
        sequence: 1,
        timestamp: DateTime.utc(2026, 7, 26, 12),
        latitude: 24.861,
        longitude: 67.002,
        accuracyMeters: 4.2,
        provider: 'gps',
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('MOV 5s'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('MOV 5s'), findsOneWidget);
    expect(find.textContaining('24.861000'), findsAtLeast(1));

    await tester.pumpWidget(const SizedBox.shrink());
    await service.close();
  });
}

class _WidgetFakeMapAdapter implements TrackingMapAdapter {
  const _WidgetFakeMapAdapter();

  @override
  bool get isAvailable => true;

  @override
  Widget buildLiveMap({
    required MapDisplayState state,
    required TrackingMapController controller,
    required VoidCallback onUserGesture,
    required VoidCallback onInitializationFailed,
  }) => const SizedBox(
    height: 340,
    child: Center(child: Text('Fake map adapter')),
  );

  @override
  Widget buildReplayMap({
    required MapDisplayState state,
    required TrackingMapController controller,
    required VoidCallback onInitializationFailed,
  }) => const SizedBox(
    height: 340,
    child: Center(child: Text('Fake replay adapter')),
  );
}

class _WidgetFakeTrackingService implements TrackingService {
  final StreamController<TrackingEvent> _events =
      StreamController<TrackingEvent>.broadcast();
  int startCalls = 0;

  @override
  Future<TrackingPermissionStatus> ensurePermissions() async =>
      const TrackingPermissionStatus(
        locationGranted: true,
        preciseLocationGranted: true,
        locationPermanentlyDenied: false,
        notificationPermissionGranted: true,
        message: 'Permissions granted',
      );

  @override
  Future<TrackingStartResult> startTracking() async {
    startCalls += 1;
    return const TrackingStartResult(
      success: true,
      isTracking: true,
      sessionId: 'session-1',
      message: 'Tracking started',
    );
  }

  @override
  Future<void> stopTracking() async {}

  @override
  Future<TrackingServiceStatus> getStatus() async =>
      const TrackingServiceStatus.stopped();

  @override
  Stream<TrackingEvent> get events => _events.stream;

  @override
  Future<TrackingSession?> getCurrentSession() async => null;

  @override
  Future<List<LocationRecord>> getCurrentSessionRecords() async => const [];

  @override
  Future<List<TrackingSession>> listTrackingSessions() async => const [];

  @override
  Future<TrackingSessionRecords> getSessionRecords(String sessionId) async =>
      const TrackingSessionRecords(records: []);

  @override
  Future<bool> shareSessionLog(String sessionId) async => true;

  @override
  Future<SessionOperationResult> deleteSession(String sessionId) async =>
      const SessionOperationResult(success: true, message: 'Deleted');

  @override
  Future<AmapConfiguration> getAmapConfiguration() async =>
      const AmapConfiguration(
        apiKeyConfigured: true,
        privacyConsent: AmapPrivacyConsent.accepted,
        sdkInitialized: false,
        locationEngine: 'AMAP',
      );

  @override
  Future<LocationEngineConfiguration> getLocationEngineConfiguration() async =>
      const LocationEngineConfiguration(
        selected: LocationEnginePreference.amap,
        resolved: LocationEngineType.amap,
        amapOptionAvailable: true,
      );

  @override
  Future<LocationEngineConfiguration> setLocationEnginePreference(
    LocationEnginePreference preference,
  ) async => LocationEngineConfiguration(
    selected: preference,
    resolved: preference == LocationEnginePreference.amap
        ? LocationEngineType.amap
        : LocationEngineType.androidLocationManager,
    amapOptionAvailable: true,
  );

  @override
  Future<LocationEngineConfiguration> retryAmapInitialization() =>
      getLocationEngineConfiguration();

  @override
  Future<AmapConfiguration> setAmapPrivacyConsent(
    AmapPrivacyConsent consent,
  ) async => AmapConfiguration(
    apiKeyConfigured: true,
    privacyConsent: consent,
    sdkInitialized: false,
    locationEngine: 'AMAP',
  );

  @override
  Future<TrackingMapPreferences> getMapPreferences() async =>
      const TrackingMapPreferences();

  @override
  Future<TrackingMapPreferences> setMapPreferences(
    TrackingMapPreferences preferences,
  ) async => preferences;

  @override
  Future<BatteryOptimizationStatus> getBatteryOptimizationStatus() async =>
      const BatteryOptimizationStatus.unknown();

  @override
  Future<bool> openBatteryOptimizationSettings() async => true;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<bool> shareCurrentLog() async => true;

  void emitLocation(LocationRecord location) {
    _events.add(
      TrackingEvent(type: TrackingEventType.location, location: location),
    );
  }

  Future<void> close() => _events.close();
}
