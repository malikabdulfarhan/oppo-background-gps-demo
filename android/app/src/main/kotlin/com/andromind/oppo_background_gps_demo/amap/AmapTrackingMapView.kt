package com.andromind.oppo_background_gps_demo.amap

import android.content.Context
import android.graphics.Color
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import com.amap.api.maps.AMap
import com.amap.api.maps.CameraUpdateFactory
import com.amap.api.maps.CoordinateConverter
import com.amap.api.maps.MapView
import com.amap.api.maps.model.BitmapDescriptorFactory
import com.amap.api.maps.model.CircleOptions
import com.amap.api.maps.model.LatLng
import com.amap.api.maps.model.LatLngBounds
import com.amap.api.maps.model.MarkerOptions
import com.amap.api.maps.model.PolylineOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

internal class AmapTrackingMapView(
    private val context: Context,
    viewId: Int,
    messenger: BinaryMessenger,
    private val lifecycle: Lifecycle,
    creationArguments: Map<*, *>?,
) : PlatformView,
    MethodChannel.MethodCallHandler,
    DefaultLifecycleObserver {
    private val container = FrameLayout(context)
    private val channel =
        MethodChannel(
            messenger,
            "$CHANNEL_PREFIX$viewId",
        )
    private var mapView: MapView? = null
    private var amap: AMap? = null
    private var disposed = false
    private var hasInitialCameraPosition = false
    private var lastAutomaticallyCenteredLocation: LatLng? = null
    private var followLocation = true
    private var currentLocation: LatLng? = null
    private var currentAccuracyMeters = 0.0
    private var selectedPoint: LatLng? = null
    private var routePoints: List<LatLng> = emptyList()

    init {
        channel.setMethodCallHandler(this)
        lifecycle.addObserver(this)
        initializeMap(creationArguments)
    }

    override fun getView(): View = container

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "updateState" -> {
                updateState(call.arguments as? Map<*, *>)
                result.success(null)
            }
            "recenter" -> {
                recenter()
                result.success(currentLocation != null)
            }
            "fitRoute" -> {
                fitRoute()
                result.success(routePoints.isNotEmpty())
            }
            "setOptions" -> {
                applyOptions(call.arguments as? Map<*, *>)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onResume(owner: LifecycleOwner) {
        mapView?.onResume()
    }

    override fun onPause(owner: LifecycleOwner) {
        mapView?.onPause()
    }

    override fun onDestroy(owner: LifecycleOwner) {
        dispose()
    }

    override fun dispose() {
        if (disposed) {
            return
        }
        disposed = true
        lifecycle.removeObserver(this)
        channel.setMethodCallHandler(null)
        mapView?.onDestroy()
        AmapSdkConfiguration.setMapSdkInitialized(context, false)
        mapView = null
        amap = null
        container.removeAllViews()
    }

    private fun initializeMap(arguments: Map<*, *>?) {
        if (
            !AmapSdkConfiguration.isKeyConfigured(context) ||
            AmapSdkConfiguration.privacyConsent(context) != AmapPrivacyConsent.ACCEPTED
        ) {
            showUnavailable("AMap requires an API key and privacy consent.")
            return
        }

        val nativeMapView =
            try {
                AmapSdkConfiguration.applyAcceptedPrivacy(context)
                MapView(context).also { it.onCreate(null) }
            } catch (error: Throwable) {
                val reason = error.message ?: "AMap map initialization failed."
                AmapSdkConfiguration.markRuntimeFailed(reason)
                showUnavailable(
                    "AMap could not initialize. Android GPS Demo Mode remains available.",
                )
                container.post {
                    channel.invokeMethod(
                        "onAmapInitializationFailed",
                        mapOf("message" to reason.take(240)),
                    )
                }
                return
            }
        container.addView(
            nativeMapView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )
        mapView = nativeMapView
        amap =
            nativeMapView.map.apply {
                setOnMapTouchListener {
                    channel.invokeMethod("onUserGesture", null)
                }
                setOnMapLoadedListener {
                    channel.invokeMethod("onMapLoaded", null)
                }
        }
        AmapSdkConfiguration.setMapSdkInitialized(context, true)
        updateState(arguments)
    }

    private fun showUnavailable(message: String) {
        container.removeAllViews()
        container.addView(
            TextView(context).apply {
                text = message
                gravity = android.view.Gravity.CENTER
                setTextColor(Color.DKGRAY)
                setPadding(32, 32, 32, 32)
            },
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )
    }

    private fun updateState(arguments: Map<*, *>?) {
        if (arguments == null || amap == null) {
            return
        }
        applyOptions(arguments)
        followLocation = arguments["followLocation"] as? Boolean ?: followLocation
        val currentArguments = arguments["currentLocation"] as? Map<*, *>
        currentLocation = parsePoint(currentArguments)
        currentAccuracyMeters =
            (currentArguments?.get("accuracy") as? Number)?.toDouble()
                ?.takeIf { it.isFinite() && it >= 0 } ?: 0.0
        selectedPoint = parsePoint(arguments["selectedPoint"] as? Map<*, *>)
        routePoints =
            (arguments["routePoints"] as? List<*>)
                .orEmpty()
                .mapNotNull { parsePoint(it as? Map<*, *>) }
        redraw()
        if (!hasInitialCameraPosition) {
            val initial = currentLocation ?: routePoints.firstOrNull()
            if (initial != null) {
                amap?.moveCamera(CameraUpdateFactory.newLatLngZoom(initial, 17f))
                hasInitialCameraPosition = true
                lastAutomaticallyCenteredLocation = currentLocation
            }
        } else if (followLocation) {
            val location = currentLocation
            if (location != null && location != lastAutomaticallyCenteredLocation) {
                recenter()
                lastAutomaticallyCenteredLocation = location
            }
        }
    }

    private fun redraw() {
        val map = amap ?: return
        map.clear()
        if (routePoints.size >= 2) {
            map.addPolyline(
                PolylineOptions()
                    .addAll(routePoints)
                    .color(Color.rgb(33, 150, 243))
                    .width(12f)
                    .geodesic(true),
            )
        }
        routePoints.firstOrNull()?.let { start ->
            map.addMarker(
                MarkerOptions()
                    .position(start)
                    .title("Start")
                    .icon(
                        BitmapDescriptorFactory.defaultMarker(
                            BitmapDescriptorFactory.HUE_GREEN,
                        ),
                    ),
            )
        }
        routePoints.lastOrNull()?.takeIf { it != routePoints.firstOrNull() }?.let { latest ->
            map.addMarker(
                MarkerOptions()
                    .position(latest)
                    .title("Latest")
                    .icon(
                        BitmapDescriptorFactory.defaultMarker(
                            BitmapDescriptorFactory.HUE_RED,
                        ),
                    ),
            )
        }
        currentLocation?.let { location ->
            map.addCircle(
                CircleOptions()
                    .center(location)
                    .radius(currentAccuracyMeters)
                    .fillColor(Color.argb(45, 33, 150, 243))
                    .strokeColor(Color.rgb(33, 150, 243))
                    .strokeWidth(2f),
            )
            map.addMarker(
                MarkerOptions()
                    .position(location)
                    .anchor(0.5f, 0.5f)
                    .icon(
                        BitmapDescriptorFactory.defaultMarker(
                            BitmapDescriptorFactory.HUE_AZURE,
                        ),
                    ),
            )
        }
        selectedPoint?.let { selected ->
            map.addMarker(
                MarkerOptions()
                    .position(selected)
                    .title("Selected point")
                    .icon(
                        BitmapDescriptorFactory.defaultMarker(
                            BitmapDescriptorFactory.HUE_ORANGE,
                        ),
                    ),
            )
        }
    }

    private fun recenter() {
        val location = currentLocation ?: return
        amap?.animateCamera(CameraUpdateFactory.newLatLngZoom(location, 17f))
    }

    private fun fitRoute() {
        val points =
            buildList {
                addAll(routePoints)
                currentLocation?.let(::add)
            }
        if (points.isEmpty()) {
            return
        }
        if (points.size == 1) {
            amap?.animateCamera(CameraUpdateFactory.newLatLngZoom(points.first(), 17f))
            return
        }
        val builder = LatLngBounds.builder()
        points.forEach(builder::include)
        amap?.animateCamera(CameraUpdateFactory.newLatLngBounds(builder.build(), 96))
    }

    private fun applyOptions(arguments: Map<*, *>?) {
        val map = amap ?: return
        val options = arguments ?: AmapSdkConfiguration.mapPreferences(context)
        val mapType = options["mapType"] as? String ?: "STANDARD"
        map.mapType =
            when (mapType) {
                "SATELLITE" -> AMap.MAP_TYPE_SATELLITE
                "NIGHT" -> AMap.MAP_TYPE_NIGHT
                else -> AMap.MAP_TYPE_NORMAL
            }
        map.isTrafficEnabled = options["trafficEnabled"] as? Boolean ?: false
        map.uiSettings.isCompassEnabled = options["compassEnabled"] as? Boolean ?: true
        map.uiSettings.isScaleControlsEnabled = options["scaleEnabled"] as? Boolean ?: true
        map.uiSettings.isZoomControlsEnabled = false
    }

    private fun parsePoint(value: Map<*, *>?): LatLng? {
        val latitude = (value?.get("latitude") as? Number)?.toDouble() ?: return null
        val longitude = (value["longitude"] as? Number)?.toDouble() ?: return null
        if (
            !latitude.isFinite() ||
            !longitude.isFinite() ||
            latitude !in -90.0..90.0 ||
            longitude !in -180.0..180.0
        ) {
            return null
        }
        val point = LatLng(latitude, longitude)
        return if (value["coordinateSystem"] == "WGS84_LEGACY") {
            runCatching {
                CoordinateConverter(context)
                    .from(CoordinateConverter.CoordType.GPS)
                    .coord(point)
                    .convert()
            }.getOrNull() ?: point
        } else {
            point
        }
    }

    companion object {
        const val VIEW_TYPE =
            "com.andromind.oppo_background_gps_demo/amap_tracking_map"
        const val CHANNEL_PREFIX =
            "com.andromind.oppo_background_gps_demo/amap_map_"
    }
}
