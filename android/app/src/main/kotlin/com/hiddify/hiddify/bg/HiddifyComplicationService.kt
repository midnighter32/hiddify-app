package com.hiddify.hiddify.bg

import android.app.PendingIntent
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.drawable.Icon
import androidx.wear.watchface.complications.data.ComplicationData
import androidx.wear.watchface.complications.data.ComplicationText
import androidx.wear.watchface.complications.data.ComplicationType
import androidx.wear.watchface.complications.data.MonochromaticImage
import androidx.wear.watchface.complications.data.PlainComplicationText
import androidx.wear.watchface.complications.data.ShortTextComplicationData
import androidx.wear.watchface.complications.data.SmallImage
import androidx.wear.watchface.complications.data.SmallImageType
import androidx.wear.watchface.complications.datasource.ComplicationDataSourceService
import androidx.wear.watchface.complications.datasource.ComplicationRequest
import com.hiddify.hiddify.MainActivity
import com.hiddify.hiddify.R
import java.io.File

/// Watch-face complication ("circle"): shows the connected country's flag +
/// ping while the VPN is on, or the Hiddify icon when off. Tapping opens the
/// app. Data is read from the Flutter shared preferences the app writes;
/// refreshed by the system every minute (UPDATE_PERIOD_SECONDS).
class HiddifyComplicationService : ComplicationDataSourceService() {

    override fun getPreviewData(type: ComplicationType): ComplicationData? {
        if (type != ComplicationType.SHORT_TEXT) return null
        return ShortTextComplicationData.Builder(
            PlainComplicationText.Builder("78").build(),
            ComplicationText.EMPTY,
        ).setMonochromaticImage(hiddifyIcon()).build()
    }

    override fun onComplicationRequest(
        request: ComplicationRequest,
        listener: ComplicationRequestListener,
    ) {
        if (request.complicationType != ComplicationType.SHORT_TEXT) {
            listener.onComplicationData(null)
            return
        }
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val connected = prefs.getBoolean("flutter.hiddify_wear_connected", false)
        listener.onComplicationData(
            if (connected) {
                connectedData(
                    prefs.getString("flutter.hiddify_wear_ping", "") ?: "",
                    prefs.getString("flutter.hiddify_wear_flag_path", "") ?: "",
                )
            } else {
                disconnectedData()
            },
        )
    }

    private fun connectedData(ping: String, flagPath: String): ComplicationData {
        val builder = ShortTextComplicationData.Builder(
            PlainComplicationText.Builder(if (ping.isEmpty()) "--" else ping).build(),
            ComplicationText.EMPTY,
        ).setTapAction(openAppIntent())

        // Decode to a Bitmap here (our process can read our files) and embed it
        // in the Icon — a file path would be unreadable by the watch-face process.
        val flagFile = if (flagPath.isNotEmpty()) File(flagPath) else null
        val bitmap = if (flagFile != null && flagFile.exists()) {
            BitmapFactory.decodeFile(flagPath)
        } else {
            null
        }
        if (bitmap != null) {
            builder.setSmallImage(
                SmallImage.Builder(Icon.createWithBitmap(bitmap), SmallImageType.PHOTO).build(),
            )
        } else {
            builder.setMonochromaticImage(hiddifyIcon())
        }
        return builder.build()
    }

    private fun disconnectedData(): ComplicationData {
        return ShortTextComplicationData.Builder(
            PlainComplicationText.Builder("Off").build(),
            ComplicationText.EMPTY,
        ).setMonochromaticImage(hiddifyIcon()).setTapAction(openAppIntent()).build()
    }

    private fun hiddifyIcon() =
        MonochromaticImage.Builder(Icon.createWithResource(this, R.drawable.ic_stat_logo)).build()

    private fun openAppIntent(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        return PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }
}
