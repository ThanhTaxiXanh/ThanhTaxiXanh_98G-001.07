package vn.thanhtaxixanh.car98g00107.car

import android.graphics.Rect
import android.view.View
import android.widget.FrameLayout
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class CarDashboardLayoutTest {
    @Test fun dashboardMeasuresSixtyFortyInsideTheHostsVisibleArea() {
        val context = RuntimeEnvironment.getApplication()
        val dashboard = CarDashboardLayout(context, View(context), {})
        dashboard.visibleArea(Rect(100, 40, 900, 540))
        dashboard.render(mapOf("layout" to mapOf("calendar" to 30, "payment" to 45, "media" to 25)))
        dashboard.measure(View.MeasureSpec.makeMeasureSpec(1000, View.MeasureSpec.EXACTLY), View.MeasureSpec.makeMeasureSpec(600, View.MeasureSpec.EXACTLY))
        dashboard.layout(0, 0, 1000, 600)
        assertEquals(100, dashboard.mapContainer.left)
        assertEquals(480, dashboard.mapContainer.width)
        assertEquals(320, dashboard.sidebar.width)
        assertEquals(580, dashboard.sidebar.left)
        assertEquals(3, dashboard.sidebar.childCount)
        assertEquals(150, dashboard.sidebar.getChildAt(0).height)
        assertEquals(225, dashboard.sidebar.getChildAt(1).height)
        assertEquals(125, dashboard.sidebar.getChildAt(2).height)
    }
    @Test fun videoUsesOneViewAndDetachesBeforeReturningToThePhone() {
        val context = RuntimeEnvironment.getApplication()
        val phone = FrameLayout(context)
        val browser = View(context)
        phone.addView(browser)
        val dashboard = CarDashboardLayout(context, View(context), {})
        dashboard.showVideo(browser)
        assertEquals(0, phone.childCount)
        assertNotNull(browser.parent)
        assertEquals(View.INVISIBLE, dashboard.sidebar.visibility)
        dashboard.setMiniVideo(true)
        dashboard.measure(View.MeasureSpec.makeMeasureSpec(1000, View.MeasureSpec.EXACTLY), View.MeasureSpec.makeMeasureSpec(600, View.MeasureSpec.EXACTLY))
        dashboard.layout(0, 0, 1000, 600)
        assertEquals(View.VISIBLE, dashboard.sidebar.visibility)
        assertEquals(300, browser.width)
        assertEquals(168, browser.height)
        dashboard.releaseVideo()
        assertNull(browser.parent)
        assertEquals(View.VISIBLE, dashboard.sidebar.visibility)
        phone.addView(browser)
        // Repeated car cleanup must not detach the newly restored phone view.
        dashboard.releaseVideo()
        assertSame(phone, browser.parent)
    }
    @Test fun invalidatedPaymentClearsTheDisplayedQr() {
        val context = RuntimeEnvironment.getApplication()
        val dashboard = CarDashboardLayout(context, View(context), {})
        val raw = javaClass.classLoader!!.getResourceAsStream("generated_car_qr.json")!!.bufferedReader().use { it.readText() }
        val array = org.json.JSONObject(raw).getJSONArray("matrix")
        val matrix = (0 until array.length()).map { array.getString(it) }
        dashboard.render(mapOf("payment" to mapOf("matrix" to matrix)))
        assertNotNull(dashboard.qrImage.drawable)
        dashboard.render(mapOf("payment" to mapOf("matrix" to matrix, "message" to "Đang cập nhật")))
        assertNull(dashboard.qrImage.drawable)
    }
}
