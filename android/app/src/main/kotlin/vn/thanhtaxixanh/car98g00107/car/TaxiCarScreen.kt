package vn.thanhtaxixanh.car98g00107.car

import androidx.car.app.AppManager
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.car.app.navigation.model.MapController
import androidx.car.app.navigation.model.MapWithContentTemplate
import androidx.car.app.navigation.model.NavigationTemplate
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner

class TaxiCarScreen(context: CarContext) : Screen(context), DefaultLifecycleObserver {
    private var panel = CarPanel.OVERVIEW
    private var data: Map<String, Any?> = emptyMap()
    private var mapError: String? = null
    private val renderer = CarSurfaceMap(context, { latitude, longitude ->
        CarRuntime.action("destination", mapOf("latitude" to latitude, "longitude" to longitude))
    }, { message ->
        mapError = message
        refresh()
    })
    private val listener: (Map<String, Any?>) -> Unit = { value ->
        data = value
        renderer.update(value.section("map"))
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
    private fun select(value: CarPanel) {
        if (carContext.carAppApiLevel >= 7) { panel = value; invalidate() }
        else screenManager.push(CarDetailScreen(carContext, value))
    }
    override fun onGetTemplate(): Template {
        val modes = CarTemplates.modes(carContext, ::select)
        val mapActions = CarTemplates.mapActions(carContext,
            { CarRuntime.action("gps"); renderer.recenter() }, renderer::zoom)
        if (carContext.carAppApiLevel >= 7) {
            val contents = if (mapError != null) data + ("bridgeMessage" to mapError) else data
            return MapWithContentTemplate.Builder()
                .setContentTemplate(CarTemplates.pane(carContext, contents, panel,
                    { CarRuntime.action(it) }, { screenManager.push(CarRecentScreen(carContext)) }))
                .setActionStrip(modes)
                .setMapController(MapController.Builder().setMapActionStrip(mapActions).build())
                .build()
        }
        return NavigationTemplate.Builder().setActionStrip(modes).setMapActionStrip(mapActions).build()
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
