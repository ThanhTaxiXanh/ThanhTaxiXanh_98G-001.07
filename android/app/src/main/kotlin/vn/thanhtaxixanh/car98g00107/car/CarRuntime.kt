package vn.thanhtaxixanh.car98g00107.car

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.webkit.WebView
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi

/** Shared with the audio_service engine, including car-first/cold launches. */
object CarRuntime {
    private var channel: MethodChannel? = null
    private var engine: FlutterEngine? = null
    private var ready = false
    var detachVideo: (() -> Unit)? = null
    var videoEnabled = false
        private set
    @Suppress("DEPRECATION")
    fun webView(id: Long): WebView? = engine?.let { WebViewFlutterAndroidExternalApi.getWebView(it, id) }
    private val listeners = linkedSetOf<(Map<String, Any?>) -> Unit>()
    var snapshot: Map<String, Any?> = emptyMap()
        private set

    fun attach(value: FlutterEngine) {
        if (engine === value) return
        engine = value
        ready = false
        channel = MethodChannel(value.dartExecutor.binaryMessenger, "vn.thanhtaxixanh/car")
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "prepareCarVideo" -> { videoEnabled = true; result.success(null) }
                "releaseCarVideo" -> { videoEnabled = false; detachVideo?.invoke(); result.success(null) }
                "ready" -> {
                    ready = true
                    result.success(null)
                    if (listeners.isNotEmpty()) action("connect")
                }
                "snapshot" -> {
                    accept(call.arguments)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun addListener(listener: (Map<String, Any?>) -> Unit) {
        val first = listeners.isEmpty()
        listeners.add(listener)
        listener(snapshot)
        if (first && ready) action("connect")
    }

    fun removeListener(listener: (Map<String, Any?>) -> Unit) {
        listeners.remove(listener)
        if (listeners.isEmpty() && ready) action("disconnect")
    }

    fun action(type: String, extra: Map<String, Any?> = emptyMap()) {
        channel?.invokeMethod("carAction", mapOf("type" to type) + extra, object : MethodChannel.Result {
            override fun success(result: Any?) { if (type != "disconnect") accept(result) }
            override fun error(code: String, message: String?, details: Any?) {
                accept(snapshot + ("bridgeMessage" to "Chưa kết nối được dữ liệu. Mở ứng dụng trên điện thoại rồi thử lại."))
            }
            override fun notImplemented() { /* A cold engine announces ready after bootstrap. */ }
        })
    }

    private fun accept(value: Any?) {
        if (value !is Map<*, *>) return
        snapshot = value.entries.associate { it.key.toString() to it.value }
        listeners.toList().forEach { it(snapshot) }
    }
}

internal fun Map<String, Any?>.section(key: String): Map<String, Any?> =
    (get(key) as? Map<*, *>)?.entries?.associate { it.key.toString() to it.value } ?: emptyMap()
internal fun Map<String, Any?>.text(key: String, fallback: String = ""): String =
    (get(key) as? String)?.take(200) ?: fallback
internal fun Map<String, Any?>.number(key: String): Double? =
    (get(key) as? Number)?.toDouble()?.takeIf { it.isFinite() }
internal fun Map<String, Any?>.rows(key: String): List<Map<String, Any?>> =
    (get(key) as? List<*>)?.mapNotNull { value ->
        (value as? Map<*, *>)?.entries?.associate { it.key.toString() to it.value }
    } ?: emptyList()
