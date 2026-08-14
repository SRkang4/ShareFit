package com.sharefit.app.sharefit

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val METHOD_CHANNEL =
            "com.sharefit.app.sharefit/workout_progress_notification"
        private const val NOTIFICATION_CHANNEL_ID = "sharefit_workout_progress"
        private const val NOTIFICATION_CHANNEL_NAME = "운동 진행"
        private const val NOTIFICATION_CHANNEL_DESCRIPTION = "운동 중 진행 상태를 표시합니다."

        // geolocator_android uses this foreground notification slot. Reusing it
        // prevents a second notification while running location tracking is active.
        private const val WORKOUT_NOTIFICATION_ID = 75415
        private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 4101
        private const val PERMISSION_PREFERENCES = "sharefit_notification_permission"
        private const val PERMISSION_REQUESTED_KEY = "requested"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createWorkoutNotificationChannel()

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> {
                    requestNotificationPermissionIfNeeded()
                    result.success(null)
                }

                "show" -> {
                    val title = call.argument<String>("title") ?: "운동 중"
                    val content = call.argument<String>("content") ?: ""
                    val durationSeconds =
                        (call.argument<Number>("durationSeconds")?.toLong() ?: 0L)
                            .coerceAtLeast(0L)
                    val isPaused = call.argument<Boolean>("isPaused") ?: false
                    showWorkoutNotification(title, content, durationSeconds, isPaused)
                    result.success(null)
                }

                "stop" -> {
                    NotificationManagerCompat.from(this).cancel(WORKOUT_NOTIFICATION_ID)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun createWorkoutNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            NOTIFICATION_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = NOTIFICATION_CHANNEL_DESCRIPTION
            setSound(null, null)
            enableVibration(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        val preferences = getSharedPreferences(PERMISSION_PREFERENCES, Context.MODE_PRIVATE)
        if (preferences.getBoolean(PERMISSION_REQUESTED_KEY, false)) return
        preferences.edit().putBoolean(PERMISSION_REQUESTED_KEY, true).apply()
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST_CODE,
        )
    }

    private fun showWorkoutNotification(
        title: String,
        content: String,
        durationSeconds: Long,
        isPaused: Boolean,
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_sharefit)
            .setContentTitle(title)
            .setContentText(content)
            .setStyle(NotificationCompat.BigTextStyle().bigText(content))
            .setContentIntent(pendingIntent)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setAutoCancel(false)

        if (isPaused) {
            builder.setShowWhen(false).setUsesChronometer(false)
        } else {
            builder
                .setWhen(System.currentTimeMillis() - durationSeconds * 1000L)
                .setChronometerCountDown(false)
                .setUsesChronometer(true)
                .setShowWhen(true)
        }

        NotificationManagerCompat.from(this).notify(WORKOUT_NOTIFICATION_ID, builder.build())
    }
}
