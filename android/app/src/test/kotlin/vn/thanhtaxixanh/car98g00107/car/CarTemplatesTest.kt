package vn.thanhtaxixanh.car98g00107.car

import android.content.Context
import android.content.ComponentName
import android.content.Intent
import android.graphics.Color
import androidx.car.app.model.PaneTemplate
import com.google.zxing.BinaryBitmap
import com.google.zxing.RGBLuminanceSource
import com.google.zxing.common.HybridBinarizer
import com.google.zxing.qrcode.QRCodeReader
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.util.ReflectionHelpers
import vn.thanhtaxixanh.car98g00107.MainActivity

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class CarTemplatesTest {
    private val context: Context get() = RuntimeEnvironment.getApplication()
    @Test fun manifestExposesMediaNavigationAndAndroidPip() {
        val packageManager = context.packageManager
        val activity = packageManager.getActivityInfo(ComponentName(context, MainActivity::class.java), 0)
        assertTrue(ReflectionHelpers.callInstanceMethod<Boolean>(activity, "supportsPictureInPicture"))
        val media = packageManager.queryIntentServices(
            Intent("android.media.browse.MediaBrowserService").setPackage(context.packageName), 0)
        assertTrue(media.any { it.serviceInfo.name.endsWith("AudioService") })
        val maps = packageManager.queryIntentServices(
            Intent("androidx.car.app.CarAppService").addCategory("androidx.car.app.category.NAVIGATION")
                .setPackage(context.packageName), 0)
        assertTrue(maps.any { it.serviceInfo.name.endsWith("TaxiCarService") })
    }
    @Test fun calendarAndMediaBuildWithHostContentLimits() {
        val data = mapOf<String, Any?>(
            "calendarTitle" to "30/10/2026", "lunarLabel" to "21/9 Âm lịch",
            "events" to listOf(mapOf("title" to "Ngày mùng 1", "detail" to "Còn 10 ngày"),
                mapOf("title" to "Ngày rằm", "detail" to "Còn 24 ngày")),
            "media" to mapOf("title" to "Video thử", "artist" to "Kênh thử", "playing" to true)
        )
        val commands = mutableListOf<String>()
        val calendar = CarTemplates.pane(context, data, CarPanel.CALENDAR, commands::add, {})
        assertEquals(4, calendar.pane.rows.size)
        assertEquals(2, calendar.pane.actions.size)
        val media = CarTemplates.pane(context, data, CarPanel.MEDIA, commands::add, {})
        assertEquals("Video thử", media.pane.rows[0].title.toString())
        assertEquals(2, media.pane.actions.size)
        val overview = CarTemplates.pane(context, data, CarPanel.OVERVIEW, commands::add, {})
        assertEquals(4, overview.pane.rows.size)
        assertEquals("30/10/2026", overview.pane.rows[0].title.toString())
        assertEquals(4, CarTemplates.modes(context, {}).actions.size)
    }
    @Test fun paymentWhileEditingShowsNoStaleQr() {
        val template = CarTemplates.pane(context, mapOf(
            "payment" to mapOf("message" to "QR đang chờ cập nhật trên điện thoại…")
        ), CarPanel.PAYMENT, {}, {})
        assertNull(template.pane.image)
        assertEquals(1, template.pane.rows.size)
        assertNull(CarTemplates.qrBitmap(listOf("01", "10")))
    }
    @Test fun androidQrBitmapDecodesTheCurrentDartPayloadWithAQuietZone() {
        val raw = javaClass.classLoader!!.getResourceAsStream("generated_car_qr.json")!!
            .bufferedReader().use { it.readText() }
        val fixture = JSONObject(raw)
        val array = fixture.getJSONArray("matrix")
        val matrix = (0 until array.length()).map { array.getString(it) }
        val bitmap = CarTemplates.qrBitmap(matrix)!!
        val pixels = IntArray(bitmap.width * bitmap.height)
        bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
        assertEquals(Color.WHITE, bitmap.getPixel(0, 0))
        val scale = bitmap.width / (matrix.size + 8)
        assertEquals(Color.WHITE, bitmap.getPixel(4 * scale - 1, 4 * scale))
        val source = RGBLuminanceSource(bitmap.width, bitmap.height, pixels)
        val decoded = QRCodeReader().decode(BinaryBitmap(HybridBinarizer(source)))
        assertEquals(fixture.getString("payload"), decoded.text)
    }
}
