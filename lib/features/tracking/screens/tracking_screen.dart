import 'dart:async';

import 'package:flutter/material.dart';

import '../../chat/controllers/chat_controller.dart';
import '../../chat/models/chat_configuration.dart';
import '../../chat/screens/chat_home_screen.dart';
import '../../chat/services/chat_service.dart';
import '../../map/models/map_display_state.dart';
import '../../map/services/tracking_map_adapter.dart';
import '../controllers/tracking_controller.dart';
import '../services/tracking_models.dart';
import '../services/tracking_service.dart';
import '../widgets/amap_privacy_dialog.dart';
import 'diagnostics_screen.dart';
import 'live_tracking_view.dart';
import 'session_history_screen.dart';
import 'tracking_settings_screen.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({
    this.trackingService,
    this.mapBuilder,
    this.trackingMapAdapter,
    this.chatConfiguration = const ChatConfiguration(),
    this.localChatService,
    this.tencentChatService,
    super.key,
  });

  final TrackingService? trackingService;
  final Widget Function(MapDisplayState state)? mapBuilder;
  final TrackingMapAdapter? trackingMapAdapter;
  final ChatConfiguration chatConfiguration;
  final ChatService? localChatService;
  final ChatService? tencentChatService;

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with WidgetsBindingObserver {
  late final TrackingController _controller;
  late final ChatController _chatController;
  int _selectedIndex = 0;
  int _sessionsRefreshToken = 0;
  bool _consentPromptOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = TrackingController(trackingService: widget.trackingService);
    _chatController = ChatController(
      configuration: widget.chatConfiguration,
      localService: widget.localChatService,
      tencentService: widget.tencentChatService,
    );
    unawaited(_initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _chatController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      unawaited(_controller.refreshNativeState());
      unawaited(_chatController.handleAppResumed());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _chatController]),
      builder: (context, _) {
        final pages = [
          LiveTrackingView(
            controller: _controller,
            onReviewPrivacy: _reviewPrivacy,
            mapBuilder: widget.mapBuilder,
            trackingMapAdapter: widget.trackingMapAdapter,
          ),
          SessionHistoryScreen(
            controller: _controller,
            refreshToken: _sessionsRefreshToken,
          ),
          ChatHomeScreen(
            controller: _chatController,
            trackingController: _controller,
          ),
          DiagnosticsScreen(
            controller: _controller,
            chatController: _chatController,
          ),
          TrackingSettingsScreen(controller: _controller),
        ];
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Map Track Demo',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            actions: [
              if (_selectedIndex == 0)
                TextButton.icon(
                  onPressed: _controller.isTracking
                      ? _controller.stopTracking
                      : null,
                  icon: const Icon(Icons.stop_circle_outlined, size: 20),
                  label: const Text('Stop'),
                ),
            ],
          ),
          body: SafeArea(
            child: IndexedStack(index: _selectedIndex, children: pages),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
                if (index == 1) {
                  _sessionsRefreshToken += 1;
                }
              });
              if (index == 3) {
                unawaited(
                  _controller.refreshNativeState(restoreRecords: false),
                );
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.my_location_outlined),
                selectedIcon: Icon(Icons.my_location),
                label: 'Live',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: 'Sessions',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble),
                label: 'Chat',
              ),
              NavigationDestination(
                icon: Icon(Icons.monitor_heart_outlined),
                selectedIcon: Icon(Icons.monitor_heart),
                label: 'Diagnostics',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _initialize() async {
    await Future.wait([_controller.initialize(), _chatController.initialize()]);
    if (mounted &&
        _controller.amapConfiguration.apiKeyConfigured &&
        _controller.amapConfiguration.privacyConsent ==
            AmapPrivacyConsent.notSelected) {
      await _reviewPrivacy();
    }
  }

  Future<void> _reviewPrivacy() async {
    if (_consentPromptOpen || !mounted) {
      return;
    }
    _consentPromptOpen = true;
    final decision = await showAmapPrivacyDialog(context);
    _consentPromptOpen = false;
    if (decision != null && mounted) {
      await _controller.setAmapPrivacyConsent(decision);
    }
  }
}
