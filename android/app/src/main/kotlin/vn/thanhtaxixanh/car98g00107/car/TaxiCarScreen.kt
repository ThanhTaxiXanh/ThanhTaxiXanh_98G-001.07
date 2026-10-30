package vn.thanhtaxixanh.car98g00107.car

import androidx.car.app.AppManager
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.CarToast
import androidx.car.app.model.Action
import androidx.car.app.model.ActionStrip
import androidx.car.app.model.CarIcon
import androidx.core.graphics.drawable.IconCompat
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.car.app.navigation.model.NavigationTemplate
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner

class TaxiCarScreen(context: CarContext) : Screen(context), DefaultLifecycleObserver {
    private var data: Map<String, Any?> = emptyMap()
    private var mapError: String? = null
    private val renderer = CarSurfaceMap(context, { latitude, longitude ->
        CarRuntime.action("destination", mapOf("latitude" to latitude, "longitude" to longitude))
    }, { message ->
        if (message != null && message != mapError) CarToast.makeText(carContext, message, CarToast.LENGTH_LONG).show()
        mapError = message
        refresh()
    }, { CarRuntime.action(it) })
    private val listener: (Map<String, Any?>) -> Unit = { value ->
        data = value
        renderer.render(value)
        refresh()
    }

    init { lifecycle.addObserver(this) }
    override fun onCreate(owner: LifecycleOwner) { CarRuntime.addListener(listener) }
    override fun onStart(owner: LifecycleOwner) {
        carContext.getCarService(AppManager::class.java).setSurfaceCallback(renderer)
        invalidate()
    }
    override fun onDestroy(owner: LifecycleOwner) {
        carContext.getCarService(AppManager::class.java).setSurfaceCallback(null)
        renderer.close()
        CarRuntime.removeListener(listener)
    }
    private fun refresh() {
        if (lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) invalidate()
    }
    override fun onGetTemplate(): Template {
        fun icon(resource: Int, click: () -> Unit): Action = Action.Builder()
            .setIcon(CarIcon.Builder(IconCompat.createWithResource(carContext, resource)).build())
            .setOnClickListener(click).build()
        val actions = ActionStrip.Builder()
            .addAction(icon(vn.thanhtaxixanh.car98g00107.R.drawable.ic_car_home) { CarRuntime.action("closeYouTube") })
            .addAction(icon(vn.thanhtaxixanh.car98g00107.R.drawable.ic_car_music) {
                if (data.section("media")["carVideo"] == true) CarRuntime.action("toggleCarPip")
                else CarRuntime.action("openYouTube")
            })
            .addAction(icon(android.R.drawable.ic_menu_preferences) { screenManager.push(CarSettingsScreen(carContext)) })
            .build()
        val media = data.section("media")
        val mapActions = if (media["carVideo"] == true) ActionStrip.Builder()
            .addAction(Action.PAN)
            .addAction(icon(android.R.drawable.ic_media_previous) { CarRuntime.action("previous") })
            .addAction(icon(if (media["playing"] == true) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play) { CarRuntime.action("playPause") })
            .addAction(icon(android.R.drawable.ic_media_next) { CarRuntime.action("next") }).build()
        else CarTemplates.mapActions(carContext,
            { CarRuntime.action("gps"); renderer.recenter() }, renderer::zoom)
        // The dashboard owns the split inside the app's available Surface. A
        // MapWithContentTemplate would let the host rearrange/resize the pane.
        return NavigationTemplate.Builder().setActionStrip(actions).setMapActionStrip(mapActions).build()
    }
}

private class CarDetailScreen(context: CarContext, private val panel: CarPanel) :
    Screen(context), DefaultLifecycleObserver {
    private var data: Map<String, Any?> = CarRuntime.snapshot
    private val listener: (Map<String, Any?>) -> Unit = { value ->
        data = value
        if (lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) invalidate()
    }
    init { lifecycle.addObserver(this) }
    override fun onCreate(owner: LifecycleOwner) { CarRuntime.addListener(listener) }
    override fun onDestroy(owner: LifecycleOwner) { CarRuntime.removeListener(listener) }
    override fun onGetTemplate(): Template = CarTemplates.pane(carContext, data, panel,
        { CarRuntime.action(it) }, { screenManager.push(CarRecentScreen(carContext)) }, back = true)
}

private class CarRecentScreen(context: CarContext) : Screen(context) {
    override fun onGetTemplate(): Template {
        val videos = CarRuntime.snapshot.section("media").rows("recent")
        val list = ItemList.Builder().setNoItemsMessage("Chọn và phát một video trên điện thoại trước.")
        videos.take(10).forEach { video ->
            list.addItem(Row.Builder().setTitle(video.text("title", "YouTube"))
                .addText(video.text("artist")).setOnClickListener {
                    CarRuntime.action("playVideo", mapOf("id" to video.text("id")))
                    finish()
                }.build())
        }
        @Suppress("DEPRECATION")
        return ListTemplate.Builder().setSingleList(list.build()).setTitle("YouTube gần đây")
            .setHeaderAction(Action.BACK).build()
    }
}

private class CarSettingsScreen(context: CarContext) : Screen(context) {
    override fun onGetTemplate(): Template {
        val list = ItemList.Builder()
        list.addItem(Row.Builder().setTitle("Bản đồ trái 60% • Bảng phải 40%")
            .addText("Chọn tỷ lệ Lịch / QR / Media").build())
        list.addItem(Row.Builder().setTitle("YouTube gần đây").setOnClickListener {
            screenManager.push(CarRecentScreen(carContext))
        }.build())
        listOf(Triple("QR lớn • 25 / 50 / 25", "qr", "layoutPreset"),
            Triple("Ba hàng cân đối • 33 / 34 / 33", "balanced", "layoutPreset"),
            Triple("Ưu tiên lịch • 45 / 35 / 20", "events", "layoutPreset"),
            Triple("Đổi bản đồ 3D/2D", "", "3d")).forEach { (title, preset, type) ->
            list.addItem(Row.Builder().setTitle(title).setOnClickListener {
                CarRuntime.action(type, mapOf("preset" to preset)); finish()
            }.build())
        }
        @Suppress("DEPRECATION")
        return ListTemplate.Builder().setSingleList(list.build()).setTitle("Bố cục màn hình khách")
            .setHeaderAction(Action.BACK).build()
    }
}
