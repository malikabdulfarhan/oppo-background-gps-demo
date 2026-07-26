package com.andromind.oppo_background_gps_demo

import com.andromind.oppo_background_gps_demo.amap.AmapMapViewFactory
import com.andromind.oppo_background_gps_demo.amap.AmapTrackingMapView
import com.andromind.oppo_background_gps_demo.tracking.TrackingEventBridge
import com.andromind.oppo_background_gps_demo.tracking.TrackingServiceController
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var trackingController: TrackingServiceController

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        trackingController = TrackingServiceController(this)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TrackingServiceController.METHOD_CHANNEL,
        ).setMethodCallHandler(trackingController)
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TrackingServiceController.EVENT_CHANNEL,
        ).setStreamHandler(TrackingEventBridge)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            AmapTrackingMapView.VIEW_TYPE,
            AmapMapViewFactory(
                flutterEngine.dartExecutor.binaryMessenger,
                lifecycle,
            ),
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (
            !::trackingController.isInitialized ||
            !trackingController.onRequestPermissionsResult(requestCode, permissions, grantResults)
        ) {
            super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }
}
