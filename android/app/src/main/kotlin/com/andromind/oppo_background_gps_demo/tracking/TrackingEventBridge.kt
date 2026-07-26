package com.andromind.oppo_background_gps_demo.tracking

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

internal object TrackingEventBridge : EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var eventSink: EventChannel.EventSink? = null

    override fun onListen(
        arguments: Any?,
        events: EventChannel.EventSink?,
    ) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun emit(event: Map<String, Any?>) {
        mainHandler.post { eventSink?.success(event) }
    }
}
