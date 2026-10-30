package vn.thanhtaxixanh.car98g00107.car

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import androidx.car.app.model.Action
import androidx.car.app.model.ActionStrip
import androidx.car.app.model.CarIcon
import androidx.car.app.model.Pane
import androidx.car.app.model.PaneTemplate
import androidx.car.app.model.Row
import androidx.core.graphics.drawable.IconCompat
import vn.thanhtaxixanh.car98g00107.R

enum class CarPanel { OVERVIEW, CALENDAR, PAYMENT, MEDIA }

/** Template content remains short; the host chooses its size and position. */
object CarTemplates {
    fun pane(
        context: Context, data: Map<String, Any?>, panel: CarPanel,
        command: (String) -> Unit, recent: () -> Unit, back: Boolean = false
    ): PaneTemplate {
        val pane = Pane.Builder()
        val title: String
        when (panel) {
            CarPanel.OVERVIEW -> {
                title = "Thanh Taxi Xanh"
                pane.addRow(row(data.text("calendarTitle", "Đang tải lịch…"), data.text("lunarLabel")))
                val event = data.rows("events").firstOrNull()
                pane.addRow(row(event?.text("title") ?: "Sự kiện",
                    event?.text("detail") ?: "Chưa có sự kiện sắp tới"))
                val payment = data.section("payment")
                pane.addRow(row(
                    payment.text("holder").ifEmpty { "VietQR nhận tiền" },
                    payment.text("message").ifEmpty {
                        payment.text("bank") + " • " +
                            payment.text("amount").ifEmpty { "Người chuyển nhập số tiền" }
                    }))
                if (payment.text("message").isEmpty()) qrBitmap(payment["matrix"])?.let {
                    pane.setImage(CarIcon.Builder(IconCompat.createWithBitmap(it)).build())
                }
                val media = data.section("media")
                val playing = media["playing"] == true
                pane.addRow(row(media.text("title", "Media • YouTube"),
                    (if (playing) "Đang phát • " else "Tạm dừng • ") + media.text("artist")))
                pane.addAction(action(if (playing) "Tạm dừng" else "Phát") { command("playPause") })
                pane.addAction(action("Xem tuyến ô tô") { command("route") })
            }
            CarPanel.CALENDAR -> {
                title = "Lịch Việt Nam"
                pane.addRow(row(data.text("calendarTitle", "Đang tải lịch…"), data.text("lunarLabel")))
                data.rows("events").take(2).forEach {
                    pane.addRow(row(it.text("title"), it.text("detail")))
                }
                val map = data.section("map")
                val speed = map.number("speed")?.let { "%.0f km/h".format(it) } ?: "GPS chưa có tốc độ"
                val detail = map.text("message").ifEmpty {
                    data.text("bridgeMessage").ifEmpty {
                        map.text("routeLabel").ifEmpty { "Chạm bản đồ để chọn điểm đến" }
                    }
                }
                pane.addRow(row(speed, detail))
                pane.addAction(action("Xem tuyến ô tô") { command("route") })
                pane.addAction(action("Xóa điểm đến") { command("clearRoute") })
            }
            CarPanel.PAYMENT -> {
                title = "VietQR nhận tiền"
                val payment = data.section("payment")
                val message = payment.text("message")
                if (message.isNotEmpty()) {
                    pane.addRow(row(message, "Thiết lập tài khoản và số tiền trên điện thoại"))
                } else {
                    pane.addRow(row(payment.text("holder", "Tài khoản nhận"), payment.text("bank") + " • " + payment.text("account")))
                    pane.addRow(row(
                        payment.text("amount").ifEmpty { "Người chuyển nhập số tiền" } +
                            if (payment.text("amount").isEmpty()) "" else " VND",
                        payment.text("note")
                    ))
                    qrBitmap(payment["matrix"])?.let {
                        pane.setImage(CarIcon.Builder(IconCompat.createWithBitmap(it)).build())
                    }
                }
            }
            CarPanel.MEDIA -> {
                title = "Media • YouTube"
                val media = data.section("media")
                val playing = media["playing"] == true
                pane.addRow(row(media.text("title", "YouTube"), media.text("artist")))
                pane.addRow(row(if (playing) "Đang phát âm thanh" else "Đã tạm dừng",
                    media.text("message").ifEmpty { "Video gần đây được lưu từ điện thoại" }))
                pane.addAction(action(if (playing) "Tạm dừng" else "Phát") { command("playPause") })
                pane.addAction(action("Video gần đây", recent))
            }
        }
        @Suppress("DEPRECATION")
        return PaneTemplate.Builder(pane.build()).setTitle(title)
            .setHeaderAction(if (back) Action.BACK else Action.APP_ICON)
            .setActionStrip(ActionStrip.Builder().addAction(action("3D/2D") { command("3d") }).build())
            .build()
    }

    fun row(title: String, detail: String = ""): Row {
        val builder = Row.Builder().setTitle(title.take(160).ifEmpty { "Thanh Taxi Xanh" })
        if (detail.isNotEmpty()) builder.addText(detail.take(200))
        return builder.build()
    }
    fun action(title: String, click: () -> Unit): Action =
        Action.Builder().setTitle(title).setOnClickListener(click).build()

    fun modes(context: Context, select: (CarPanel) -> Unit): ActionStrip =
        ActionStrip.Builder()
            .addAction(iconAction(context, R.drawable.ic_car_home) { select(CarPanel.OVERVIEW) })
            .addAction(iconAction(context, android.R.drawable.ic_menu_my_calendar) { select(CarPanel.CALENDAR) })
            .addAction(iconAction(context, R.drawable.ic_car_qr) { select(CarPanel.PAYMENT) })
            .addAction(iconAction(context, R.drawable.ic_car_music) { select(CarPanel.MEDIA) })
            .build()

    fun mapActions(context: Context, gps: () -> Unit, zoom: (Double) -> Unit): ActionStrip =
        ActionStrip.Builder().addAction(Action.PAN)
            .addAction(iconAction(context, android.R.drawable.ic_menu_mylocation, gps))
            .addAction(iconAction(context, android.R.drawable.ic_input_add) { zoom(1.0) })
            .addAction(iconAction(context, R.drawable.ic_car_minus) { zoom(-1.0) })
            .build()

    private fun iconAction(context: Context, resource: Int, click: () -> Unit): Action =
        Action.Builder().setIcon(CarIcon.Builder(IconCompat.createWithResource(context, resource)).build())
            .setOnClickListener(click).build()

    /** Quiet zone is painted in pixels, not approximated by template padding. */
    fun qrBitmap(value: Any?): Bitmap? {
        val matrix = (value as? List<*>)?.map { it as? String ?: return null } ?: return null
        val modules = matrix.size
        if (modules !in 21..177 || modules % 4 != 1 ||
            matrix.any { it.length != modules || it.any { bit -> bit != '0' && bit != '1' } }) return null
        val scale = (480 / (modules + 8)).coerceAtLeast(1)
        val size = (modules + 8) * scale
        val pixels = IntArray(size * size) { Color.WHITE }
        matrix.forEachIndexed { row, line ->
            line.forEachIndexed { col, bit ->
                if (bit == '1') {
                    for (y in (row + 4) * scale until (row + 5) * scale) {
                        for (x in (col + 4) * scale until (col + 5) * scale) pixels[y * size + x] = Color.BLACK
                    }
                }
            }
        }
        return Bitmap.createBitmap(pixels, size, size, Bitmap.Config.ARGB_8888)
    }
}
