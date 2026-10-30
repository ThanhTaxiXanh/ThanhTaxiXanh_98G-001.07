package vn.thanhtaxixanh.car98g00107.car

import android.app.Presentation
import android.content.Context
import android.graphics.Rect
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.os.Bundle
import android.os.SystemClock
import android.view.MotionEvent
import android.view.WindowManager
import androidx.car.app.CarContext
import androidx.car.app.SurfaceCallback
import androidx.car.app.SurfaceContainer
import org.json.JSONArray
import org.json.JSONObject
import org.maplibre.android.MapLibre
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapLibreMapOptions
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.Style
import org.maplibre.android.style.layers.CircleLayer
import org.maplibre.android.style.layers.LineLayer
import org.maplibre.android.style.layers.Property
import org.maplibre.android.style.layers.PropertyFactory.*
import org.maplibre.android.style.sources.GeoJsonSource
import kotlin.math.ln

/** Renders navigation content onto the surface supplied by the Android Auto host. */
class CarSurfaceMap(
    private val context: CarContext,
    private val destination: (Double, Double) -> Unit,
    private val error: (String?) -> Unit,
    private val command: (String) -> Unit
) : SurfaceCallback {
    private var display: VirtualDisplay? = null
    private var presentation: Presentation? = null
    private var view: MapView? = null
    private var dashboard: CarDashboardLayout? = null
    private var snapshot: Map<String, Any?> = emptyMap()
    private var videoId: Long? = null
    private val videoDetach: () -> Unit = { dashboard?.releaseVideo(); videoId = null }
    private var map: MapLibreMap? = null
    private var style: Style? = null
    private var width = 0
    private var height = 0
    private var generation = 0
    private var follow = true
    private var lastRoute = ""
    private var data: Map<String, Any?> = emptyMap()
    private var visibleArea: Rect? = null

    override fun onSurfaceAvailable(container: SurfaceContainer) {
        release()
        val surface = container.surface ?: return
        if (!surface.isValid || container.width <= 0 || container.height <= 0) return
        width = container.width
        height = container.height
        val version = ++generation
        try {
            MapLibre.getInstance(context.applicationContext)
            val manager = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
            display = manager.createVirtualDisplay("ThanhTaxiXanh navigation", width, height,
                container.dpi.coerceAtLeast(160), surface,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_OWN_CONTENT_ONLY or
                    DisplayManager.VIRTUAL_DISPLAY_FLAG_PRESENTATION)
            val target = display ?: throw IllegalStateException("No navigation display")
            val window = Presentation(context, target.display)
            val mapView = MapView(window.context,
                MapLibreMapOptions.createFromAttributes(window.context).textureMode(true))
            view = mapView
            presentation = window
            val dashboardView = CarDashboardLayout(window.context, mapView, command)
            dashboard = dashboardView
            dashboardView.render(snapshot)
            visibleArea?.let { dashboardView.visibleArea(it) }
            window.setContentView(dashboardView)
            window.window?.addFlags(WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED)
            window.show()
            CarRuntime.detachVideo = videoDetach
            render(snapshot)
            mapView.onCreate(Bundle())
            mapView.onStart()
            mapView.onResume()
            mapView.addOnDidFailLoadingMapListener {
                if (version == generation) error("Không tải được bản đồ. Kiểm tra Internet rồi mở lại bản đồ.")
            }
            mapView.getMapAsync { ready ->
                if (version != generation) return@getMapAsync
                map = ready
                ready.moveCamera(CameraUpdateFactory.newCameraPosition(
                    CameraPosition.Builder().target(LatLng(21.0285, 105.8542))
                        .zoom(16.0).tilt(55.0).build()))
                ready.addOnMapClickListener { point ->
                    follow = false
                    destination(point.latitude, point.longitude)
                    true
                }
                ready.setStyle("https://tiles.openfreemap.org/styles/liberty") { loaded ->
                    if (version != generation) return@setStyle
                    style = loaded
                    loaded.addSource(GeoJsonSource("taxi-route", EMPTY))
                    loaded.addSource(GeoJsonSource("taxi-position", EMPTY))
                    loaded.addSource(GeoJsonSource("taxi-destination", EMPTY))
                    val route = LineLayer("taxi-route-line", "taxi-route").withProperties(
                        lineColor("#2563eb"), lineWidth(6f), lineCap(Property.LINE_CAP_ROUND))
                    if (loaded.getLayer("building-3d") != null) loaded.addLayerBelow(route, "building-3d")
                    else loaded.addLayer(route)
                    loaded.addLayer(CircleLayer("taxi-gps", "taxi-position").withProperties(
                        circleColor("#1565c0"), circleRadius(7f),
                        circleStrokeColor("#ffffff"), circleStrokeWidth(2f)))
                    loaded.addLayer(CircleLayer("taxi-end", "taxi-destination").withProperties(
                        circleColor("#ef6c00"), circleRadius(8f),
                        circleStrokeColor("#ffffff"), circleStrokeWidth(2f)))
                    error(null)
                    update(data)
                    applyVisibleArea()
                }
            }
        } catch (_: RuntimeException) {
            release()
            error("Chưa mở được bề mặt bản đồ trên bộ nhận này.")
        }
    }

    fun render(value: Map<String, Any?>) {
        snapshot = value
        dashboard?.render(value)
        val media = value.section("media")
        val id = media.number("viewId")?.toLong()
        val dashboard = dashboard
        if (dashboard != null && CarRuntime.videoEnabled && media["carVideo"] == true && id != null) {
            if (videoId != id) {
                videoId = id
                try {
                    val browser = CarRuntime.webView(id) ?: throw IllegalStateException("Player unavailable")
                    dashboard.showVideo(browser)
                    CarRuntime.action("videoAttached", mapOf("id" to id))
                } catch (_: RuntimeException) {
                    dashboard.releaseVideo()
                    CarRuntime.action("videoAttachFailed")
                }
            }
            dashboard.setMiniVideo(media["carPip"] == true)
        } else if (!CarRuntime.videoEnabled || media["carVideo"] != true) videoDetach()
        update(value.section("map"))
    }

    private fun update(value: Map<String, Any?>) {
        data = value
        val map = map ?: return
        val style = style ?: return
        try {
            val is3d = value["is3D"] != false
            style.getLayer("building-3d")?.setProperties(visibility(if (is3d) Property.VISIBLE else Property.NONE))
            val latitude = value.number("latitude")
            val longitude = value.number("longitude")
            val point = if (latitude != null && longitude != null) LatLng(latitude, longitude) else null
            style.getSourceAs<GeoJsonSource>("taxi-position")?.setGeoJson(
                if (point == null || value["gpsActive"] != true) EMPTY else feature("Point", listOf(point.longitude, point.latitude)))
            val endpoint = value["destinationPoint"] as? List<*>
            style.getSourceAs<GeoJsonSource>("taxi-destination")?.setGeoJson(
                if (endpoint == null) EMPTY else feature("Point", endpoint))
            val route = value["route"] as? List<*> ?: emptyList<Any>()
            val routeKey = JSONArray(route).toString()
            if (routeKey != lastRoute) style.getSourceAs<GeoJsonSource>("taxi-route")?.setGeoJson(
                if (route.size < 2) EMPTY else feature("LineString", route))
            if (route.size >= 2 && routeKey != lastRoute) {
                val bounds = LatLngBounds.Builder()
                route.forEach { item ->
                    val coordinate = item as? List<*> ?: return@forEach
                    if (coordinate.size >= 2) bounds.include(LatLng(
                        (coordinate[1] as Number).toDouble(), (coordinate[0] as Number).toDouble()))
                }
                map.moveCamera(CameraUpdateFactory.newLatLngBounds(bounds.build(), 48))
                follow = false
            } else if (follow && point != null && value["gpsActive"] == true) {
                map.moveCamera(CameraUpdateFactory.newCameraPosition(
                    CameraPosition.Builder(map.cameraPosition).target(point).zoom(17.0)
                        .bearing(value.number("heading") ?: map.cameraPosition.bearing)
                        .tilt(if (is3d) 55.0 else 0.0).build()))
            } else {
                map.moveCamera(CameraUpdateFactory.newCameraPosition(
                    CameraPosition.Builder(map.cameraPosition).tilt(if (is3d) 55.0 else 0.0).build()))
            }
            lastRoute = routeKey
        } catch (_: RuntimeException) {
            error("Chưa cập nhật được bản đồ trên màn hình xe.")
        }
    }

    fun recenter() { follow = true; update(data) }
    fun zoom(delta: Double) {
        follow = false
        val current = map ?: return
        current.moveCamera(CameraUpdateFactory.zoomTo((current.cameraPosition.zoom + delta).coerceIn(2.0, 20.0)))
    }
    override fun onScroll(distanceX: Float, distanceY: Float) {
        if (videoId != null && snapshot.section("media")["carPip"] != true) { dashboard?.scrollVideo(distanceX.toInt(), distanceY.toInt()); return }
        follow = false
        map?.scrollBy(distanceX, distanceY)
    }
    override fun onScale(focusX: Float, focusY: Float, scaleFactor: Float) {
        if (videoId != null && snapshot.section("media")["carPip"] != true) return
        if (scaleFactor.isFinite() && scaleFactor > 0f) zoom(ln(scaleFactor.toDouble()) / ln(2.0))
    }
    override fun onClick(x: Float, y: Float) {
        val now = SystemClock.uptimeMillis()
        val down = MotionEvent.obtain(now, now, MotionEvent.ACTION_DOWN, x, y, 0)
        val up = MotionEvent.obtain(now, now + 30, MotionEvent.ACTION_UP, x, y, 0)
        try { dashboard?.dispatchTouchEvent(down); dashboard?.dispatchTouchEvent(up) }
        finally { down.recycle(); up.recycle() }
    }
    override fun onVisibleAreaChanged(area: Rect) { visibleArea = Rect(area); applyVisibleArea() }
    private fun applyVisibleArea() {
        visibleArea?.let { dashboard?.visibleArea(it) }
        map?.setPadding(0, 0, 0, 0)
        map?.uiSettings?.setAttributionMargins(8, 8, 8, 8)
        map?.uiSettings?.setLogoMargins(8, 8, 8, 8)
    }
    override fun onSurfaceDestroyed(container: SurfaceContainer) { release() }
    fun close() { release() }
    private fun release() {
        generation++
        videoDetach()
        if (CarRuntime.detachVideo === videoDetach) CarRuntime.detachVideo = null
        map = null
        style = null
        try {
            view?.onPause()
            view?.onStop()
            view?.onDestroy()
        } catch (_: RuntimeException) {
            // A failed/partly created virtual display still needs releasing.
        }
        view = null
        dashboard = null
        try { presentation?.dismiss() } catch (_: RuntimeException) {}
        presentation = null
        try { display?.release() } catch (_: RuntimeException) {}
        display = null
        lastRoute = ""
    }
    private fun feature(type: String, coordinates: List<*>): String =
        JSONObject().put("type", "Feature").put("properties", JSONObject())
            .put("geometry", JSONObject().put("type", type).put("coordinates", JSONArray(coordinates))).toString()
    companion object {
        private const val EMPTY = "{\"type\":\"FeatureCollection\",\"features\":[]}"
    }
}
