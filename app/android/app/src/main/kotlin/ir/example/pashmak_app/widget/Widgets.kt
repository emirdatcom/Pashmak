package ir.example.pashmak_app.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import ir.example.pashmak_app.MainActivity
import ir.example.pashmak_app.R
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widgets (docs/20 §8). All state comes from the snapshot the app writes; no network, no timers
 * (`updatePeriodMillis=0`). Taps run a Dart background callback; the launch intents are the fallback.
 *
 * [نیاز به راستی‌آزمایی]: written against home_widget 0.10 without an Android SDK; compile and test on devices.
 */
private fun scheme(context: Context) = context.getString(R.string.widget_scheme)

private fun action(context: Context, path: String): Uri = Uri.parse("${scheme(context)}://$path")

class CatSmallWidget : HomeWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray, data: SharedPreferences) {
        val s = Snapshot.read(data)
        for (id in ids) {
            val v = RemoteViews(context.packageName, R.layout.widget_cat_small)
            v.setTextViewText(R.id.cat_face, s?.catEmoji ?: "😺")
            v.setTextViewText(R.id.progress_text, s?.progressText ?: "")
            v.setProgressBar(R.id.progress_bar, maxOf(s?.totalCount ?: 0, 1), s?.doneCount ?: 0, false)
            v.setOnClickPendingIntent(R.id.widget_root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, action(context, "home?source=widget")))
            manager.updateAppWidget(id, v)
        }
    }
}

class HabitsMediumWidget : HomeWidgetProvider() {
    private val rows = listOf(
        Triple(R.id.row1, R.id.row1_title, R.id.row1_check),
        Triple(R.id.row2, R.id.row2_title, R.id.row2_check),
        Triple(R.id.row3, R.id.row3_title, R.id.row3_check),
    )

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray, data: SharedPreferences) {
        val s = Snapshot.read(data)
        for (id in ids) {
            val v = RemoteViews(context.packageName, R.layout.widget_habits_medium)
            v.setTextViewText(R.id.streak_text, s?.streakText ?: "")
            rows.forEachIndexed { i, (row, title, check) ->
                val h = s?.habits?.getOrNull(i)
                if (h == null) {
                    v.setViewVisibility(row, View.GONE)
                } else {
                    v.setViewVisibility(row, View.VISIBLE)
                    v.setTextViewText(title, h.title)
                    v.setTextViewText(check, if (h.done) "☑" else "☐")
                    // Tick in the background (Dart `widgetBackgroundCallback`); the row also reopens nothing on failure.
                    v.setOnClickPendingIntent(row, HomeWidgetBackgroundIntent.getBroadcast(context, action(context, "habit/${h.id}")))
                }
            }
            v.setOnClickPendingIntent(R.id.checkin_button, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, action(context, "checkin?source=widget")))
            v.setViewVisibility(R.id.checkin_button, if (s?.checkedIn == true) View.GONE else View.VISIBLE)
            manager.updateAppWidget(id, v)
        }
    }
}

class QuickCheckInWidget : HomeWidgetProvider() {
    private val faces = listOf(R.id.mood1, R.id.mood2, R.id.mood3, R.id.mood4, R.id.mood5)

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray, data: SharedPreferences) {
        for (id in ids) {
            val v = RemoteViews(context.packageName, R.layout.widget_quick_checkin)
            faces.forEachIndexed { i, face ->
                v.setOnClickPendingIntent(face, HomeWidgetBackgroundIntent.getBroadcast(context, action(context, "checkin?mood=${i + 1}")))
            }
            manager.updateAppWidget(id, v)
        }
    }
}
