package com.andromind.oppo_background_gps_demo.amap

import android.content.Context
import androidx.lifecycle.Lifecycle
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

internal class AmapMapViewFactory(
    private val messenger: BinaryMessenger,
    private val lifecycle: Lifecycle,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(
        context: Context,
        viewId: Int,
        args: Any?,
    ): PlatformView =
        AmapTrackingMapView(
            context = context,
            viewId = viewId,
            messenger = messenger,
            lifecycle = lifecycle,
            creationArguments = args as? Map<*, *>,
        )
}
