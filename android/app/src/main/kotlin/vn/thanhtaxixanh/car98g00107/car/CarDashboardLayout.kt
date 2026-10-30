package vn.thanhtaxixanh.car98g00107.car

import android.content.Context
import android.graphics.Color
import android.graphics.Rect
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

/** App-owned passenger dashboard inside the area made visible by the car host. */
class CarDashboardLayout(context: Context, mapView: View, private val command: (String) -> Unit) : FrameLayout(context) {
    val mapContainer = FrameLayout(context)
    val sidebar = LinearLayout(context).apply { orientation = LinearLayout.VERTICAL; setBackgroundColor(Color.rgb(237, 242, 251)) }
    private val calendarRow = LinearLayout(context).apply { orientation = LinearLayout.VERTICAL }
    private val paymentRow = LinearLayout(context).apply { orientation = LinearLayout.VERTICAL }
    private val mediaRow = LinearLayout(context).apply { orientation = LinearLayout.VERTICAL }
    private val calendar = label(16f)
    private val events = label(13f)
    private val payment = label(13f)
    val qrImage = ImageView(context).apply { scaleType = ImageView.ScaleType.FIT_CENTER; contentDescription = "VietQR nhận tiền"; setBackgroundColor(Color.WHITE) }
    private val media = label(14f)
    private val status = label(14f).apply { setBackgroundColor(0xddffffff.toInt()); setPadding(8, 4, 8, 4) }
    private val play = ImageButton(context)
    private var weights = intArrayOf(25, 50, 25)
    private var area: Rect? = null
    private var qrKey: Any? = null
    private val videoLayer = FrameLayout(context).apply { visibility = View.GONE; setBackgroundColor(Color.BLACK) }
    private var video: View? = null
    private var miniVideo = false

    init {
        setBackgroundColor(Color.BLACK)
        mapContainer.addView(mapView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        mapContainer.addView(status, LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT, Gravity.TOP or Gravity.START))
        addView(mapContainer); addView(sidebar)
        addView(videoLayer)
        calendarRow.addView(calendar)
        calendarRow.addView(events, LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, 0, 1f))
        paymentRow.addView(payment)
        paymentRow.addView(qrImage, LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, 0, 1f))
        mediaRow.addView(media, LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, 0, 1f))
        val controls = LinearLayout(context).apply { gravity = Gravity.CENTER; orientation = LinearLayout.HORIZONTAL }
        fun button(view: ImageButton, resource: Int, description: String, action: String) {
            view.setImageResource(resource); view.contentDescription = description
            view.setBackgroundColor(Color.TRANSPARENT)
            view.setOnClickListener { command(action) }
            controls.addView(view, LinearLayout.LayoutParams(0, dp(40), 1f))
        }
        button(ImageButton(context), android.R.drawable.ic_media_previous, "Bài trước", "previous")
        button(play, android.R.drawable.ic_media_play, "Phát", "playPause")
        button(ImageButton(context), android.R.drawable.ic_media_next, "Bài sau", "next")
        mediaRow.addView(controls)
        listOf(calendarRow, paymentRow, mediaRow).forEachIndexed { index, row ->
            row.setPadding(dp(5), dp(3), dp(5), dp(3))
            sidebar.addView(row, LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, 0, weights[index].toFloat()))
        }
    }
    fun showVideo(value: View) {
        if (video !== value || value.parent !== videoLayer) {
            releaseVideo()
            (value.parent as? ViewGroup)?.removeView(value)
            videoLayer.addView(value, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
            video = value
        }
        videoLayer.visibility = View.VISIBLE
        mapContainer.visibility = View.INVISIBLE
        sidebar.visibility = View.INVISIBLE
    }
    fun releaseVideo() {
        video?.let { if (it.parent === videoLayer) videoLayer.removeView(it) }
        video = null
        videoLayer.visibility = View.GONE
        mapContainer.visibility = View.VISIBLE
        sidebar.visibility = View.VISIBLE
    }
    fun scrollVideo(x: Int, y: Int) { video?.scrollBy(x, y) }
    fun setMiniVideo(value: Boolean) {
        if (miniVideo != value) { miniVideo = value; requestLayout() }
        if (video != null) {
            mapContainer.visibility = if (value) View.VISIBLE else View.INVISIBLE
            sidebar.visibility = if (value) View.VISIBLE else View.INVISIBLE
        }
    }

    fun render(data: Map<String, Any?>) {
        calendar.text = data.text("calendarTitle", "Đang tải lịch…") + "\n" + data.text("lunarLabel")
        events.text = data.rows("events").take(2).joinToString("\n") { it.text("title") + " · " + it.text("detail") }
            .ifEmpty { "Chưa có sự kiện sắp tới" }
        val receipt = data.section("payment")
        val message = receipt.text("message")
        payment.text = if (message.isNotEmpty()) message else listOf(
            receipt.text("holder"), receipt.text("bank") + " • " + receipt.text("account"),
            receipt.text("amount").takeIf { it.isNotEmpty() }?.plus(" VND") ?: "Người chuyển nhập số tiền"
        ).filter { it.isNotEmpty() }.joinToString("\n")
        val matrix = if (message.isEmpty()) receipt["matrix"] else null
        if (matrix != qrKey) {
            val bitmap = CarTemplates.qrBitmap(matrix)
            if (bitmap == null) qrImage.setImageDrawable(null) else qrImage.setImageBitmap(bitmap)
            qrKey = matrix
        }
        qrImage.visibility = if (matrix == null) View.GONE else View.VISIBLE
        val current = data.section("media")
        media.text = current.text("title", "YouTube") + "\n" + current.text("message").ifEmpty { current.text("artist") }
        val playing = current["playing"] == true
        play.setImageResource(if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play)
        play.contentDescription = if (playing) "Tạm dừng" else "Phát"
        val map = data.section("map")
        status.text = listOf(
            map.number("speed")?.let { "%.0f km/h".format(it) } ?: "GPS chưa bật",
            map.text("message").ifEmpty { map.text("routeLabel") },
            data.text("bridgeMessage")
        ).filter { it.isNotEmpty() }.joinToString("\n")
        val config = data.section("layout")
        val candidate = listOf("calendar", "payment", "media").map { config.number(it)?.toInt() ?: 0 }
        val next = if (candidate.all { it in 15..70 } && candidate.sum() == 100) candidate.toIntArray() else intArrayOf(25, 50, 25)
        if (!weights.contentEquals(next)) {
            weights = next
            listOf(calendarRow, paymentRow, mediaRow).forEachIndexed { i, row ->
                row.layoutParams = LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, 0, weights[i].toFloat())
            }
        }
    }
    fun visibleArea(value: Rect) { area = Rect(value); requestLayout() }
    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        val visible = Rect(area ?: Rect(0, 0, width, height))
        if (!visible.intersect(0, 0, width, height) || visible.isEmpty) visible.set(0, 0, width, height)
        val mapWidth = visible.width() * 3 / 5
        mapContainer.layout(visible.left, visible.top, visible.left + mapWidth, visible.bottom)
        sidebar.layout(visible.left + mapWidth, visible.top, visible.right, visible.bottom)
        val videoWidth = if (miniVideo) mapWidth / 2 else visible.width()
        val videoHeight = if (miniVideo) (videoWidth * 9 / 16).coerceAtMost(visible.height()) else visible.height()
        val videoLeft = if (miniVideo) visible.left + mapWidth - videoWidth else visible.left
        videoLayer.layout(videoLeft, visible.top, videoLeft + videoWidth, visible.top + videoHeight)
    }
    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val w = MeasureSpec.getSize(widthMeasureSpec); val h = MeasureSpec.getSize(heightMeasureSpec)
        setMeasuredDimension(w, h)
        val visible = Rect(area ?: Rect(0, 0, w, h))
        if (!visible.intersect(0, 0, w, h) || visible.isEmpty) visible.set(0, 0, w, h)
        val mapWidth = visible.width() * 3 / 5
        mapContainer.measure(MeasureSpec.makeMeasureSpec(mapWidth, MeasureSpec.EXACTLY), MeasureSpec.makeMeasureSpec(visible.height(), MeasureSpec.EXACTLY))
        sidebar.measure(MeasureSpec.makeMeasureSpec(visible.width() - mapWidth, MeasureSpec.EXACTLY), MeasureSpec.makeMeasureSpec(visible.height(), MeasureSpec.EXACTLY))
        val videoWidth = if (miniVideo) mapWidth / 2 else visible.width()
        val videoHeight = if (miniVideo) (videoWidth * 9 / 16).coerceAtMost(visible.height()) else visible.height()
        videoLayer.measure(MeasureSpec.makeMeasureSpec(videoWidth, MeasureSpec.EXACTLY), MeasureSpec.makeMeasureSpec(videoHeight, MeasureSpec.EXACTLY))
    }
    private fun label(size: Float) = TextView(context).apply { textSize = size; setTextColor(Color.rgb(20, 35, 50)); maxLines = 5; ellipsize = android.text.TextUtils.TruncateAt.END }
    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
}
