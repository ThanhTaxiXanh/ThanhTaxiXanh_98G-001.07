package vn.thanhtaxixanh.car98g00107

import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import vn.thanhtaxixanh.car98g00107.car.CarRuntime

class MainActivity : AudioServiceActivity() {
    private var pipChannel: MethodChannel? = null
    private var playing = false
    private var videoVisible = false
    private var autoEnter = true

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        CarRuntime.attach(flutterEngine)
        pipChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vn.thanhtaxixanh/player_pip")
        pipChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "setPlayback" -> {
                    playing = call.argument<Boolean>("playing") == true
                    videoVisible = call.argument<Boolean>("visible") == true
                    autoEnter = call.argument<Boolean>("autoEnter") != false
                    updatePip()
                    result.success(null)
                }
                "enterPip" -> result.success(enterPip())
                else -> result.notImplemented()
            }
        }
    }

    private fun supported(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
        packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)

    private fun params(): PictureInPictureParams {
        val builder = PictureInPictureParams.Builder().setAspectRatio(Rational(16, 9))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(autoEnter && playing && videoVisible)
                .setSeamlessResizeEnabled(true)
        }
        return builder.build()
    }
    private fun updatePip() {
        if (!supported()) return
        try { setPictureInPictureParams(params()) } catch (_: RuntimeException) {}
    }
    private fun enterPip(): Boolean {
        if (!supported() || !videoVisible) return false
        return try { enterPictureInPictureMode(params()) } catch (_: RuntimeException) { false }
    }
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S && autoEnter && playing && videoVisible) enterPip()
    }
    override fun onPictureInPictureModeChanged(inPip: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(inPip, newConfig)
        pipChannel?.invokeMethod("pipState", inPip)
    }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        pipChannel?.setMethodCallHandler(null)
        pipChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
