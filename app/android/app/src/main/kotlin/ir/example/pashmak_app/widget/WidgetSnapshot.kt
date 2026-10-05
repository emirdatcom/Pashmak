package ir.example.pashmak_app.widget

import android.content.SharedPreferences
import org.json.JSONObject

/** Parsed `snapshot` JSON written by Dart (lib/core/widgets_home/widget_snapshot.dart). */
data class HabitRow(val id: String, val title: String, val done: Boolean)

data class Snapshot(
    val catMood: String,
    val habits: List<HabitRow>,
    val progressText: String,
    val streakText: String,
    val doneCount: Int,
    val totalCount: Int,
    val checkedIn: Boolean,
) {
    val catEmoji: String
        get() = when (catMood) {
            "sleepy" -> "😴"
            "sad" -> "😿"
            "proud" -> "😸"
            else -> "😺"
        }

    companion object {
        const val KEY = "snapshot"

        /**
         * Returns null when the app never published. After `valid_until_ms` (the app's day boundary) the
         * ticks of the previous day are hidden: nothing is shown as done until the app/WorkManager refreshes.
         */
        fun read(prefs: SharedPreferences, nowMs: Long = System.currentTimeMillis()): Snapshot? {
            val raw = prefs.getString(KEY, null) ?: return null
            return try {
                val j = JSONObject(raw)
                val stale = nowMs >= j.optLong("valid_until_ms", Long.MAX_VALUE)
                val arr = j.optJSONArray("habits_today")
                val rows = (0 until (arr?.length() ?: 0)).map {
                    val h = arr!!.getJSONObject(it)
                    HabitRow(h.getString("id"), h.getString("title"), !stale && h.getBoolean("done"))
                }
                Snapshot(
                    catMood = j.optString("cat_mood", "happy"),
                    habits = rows,
                    progressText = if (stale) "" else j.optString("progress_text", ""),
                    streakText = j.optString("streak_text", ""),
                    doneCount = if (stale) 0 else j.optInt("done_count"),
                    totalCount = j.optInt("total_count"),
                    checkedIn = !stale && j.optBoolean("checked_in_today"),
                )
            } catch (e: Exception) {
                null
            }
        }
    }
}
