package vn.thanhtaxixanh.car98g00107.car

import android.content.Intent
import androidx.car.app.CarAppService
import androidx.car.app.Screen
import androidx.car.app.Session
import androidx.car.app.validation.HostValidator
import com.ryanheise.audioservice.AudioServicePlugin

class TaxiCarService : CarAppService() {
    override fun onCreate() {
        super.onCreate()
        CarRuntime.attach(AudioServicePlugin.getFlutterEngine(this))
    }
    override fun createHostValidator(): HostValidator =
        HostValidator.Builder(this)
            // AndroidX's published Android Auto host certificate allowlist.
            // https://github.com/androidx/androidx/blob/androidx-main/car/app/app/src/main/res/values/config.xml
            .addAllowedHost("com.google.android.projection.gearhead",
                "fdb00c43dbde8b51cb312aa81d3b5fa17713adb94b28f598d77f8eb89daceedf")
            .addAllowedHost("com.google.android.projection.gearhead",
                "70811a3eacfd2e83e18da9bfede52df16ce91f2e69a44d21f18ab66991130771")
            .addAllowedHost("com.google.android.projection.gearhead",
                "1975b2f17177bc89a5dff31f9e64a6cae281a53dc1d1d59b1d147fe1c82afa00")
            .build()

    override fun onCreateSession(): Session = object : Session() {
        override fun onCreateScreen(intent: Intent): Screen = TaxiCarScreen(carContext)
    }
}
