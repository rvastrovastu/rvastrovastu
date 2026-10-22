package com.rvastrovastu.rv_astro_vastu

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Today's Panchang on the home screen. The app writes a week of days
 * (already localized) as JSON under "days"; the widget shows today's.
 */
class TodayWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val entry = pick(widgetData.getString("days", null), today)
        val rahuLabel = widgetData.getString("rahuLabel", "Rahu Kaal") ?: "Rahu Kaal"
        val empty = widgetData.getString("emptyText", null)
            ?: context.getString(R.string.today_widget_empty)

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.today_widget).apply {
                if (entry == null) {
                    setTextViewText(R.id.widget_title, empty)
                    setViewVisibility(R.id.widget_detail, View.GONE)
                    setViewVisibility(R.id.widget_rahu, View.GONE)
                    setViewVisibility(R.id.widget_rashifal, View.GONE)
                } else {
                    setTextViewText(R.id.widget_title, entry.optString("title"))
                    setTextViewText(R.id.widget_detail, entry.optString("detail"))
                    setViewVisibility(R.id.widget_detail, View.VISIBLE)
                    setTextViewText(
                        R.id.widget_rahu,
                        "$rahuLabel ${entry.optString("rahu")}",
                    )
                    setViewVisibility(R.id.widget_rahu, View.VISIBLE)
                    val rashifal = entry.optString("rashifal", "")
                    if (rashifal.isEmpty() || rashifal == "null") {
                        setViewVisibility(R.id.widget_rashifal, View.GONE)
                    } else {
                        setTextViewText(R.id.widget_rashifal, rashifal)
                        setViewVisibility(R.id.widget_rashifal, View.VISIBLE)
                    }
                }
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    /** Today's entry, else the latest one before it. */
    private fun pick(json: String?, today: String): JSONObject? {
        if (json.isNullOrEmpty()) return null
        return try {
            val days = JSONArray(json)
            var best: JSONObject? = null
            for (i in 0 until days.length()) {
                val day = days.getJSONObject(i)
                val date = day.optString("date")
                if (date == today) return day
                if (date < today) best = day
            }
            best
        } catch (e: Exception) {
            null
        }
    }
}
