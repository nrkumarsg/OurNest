package com.ournest.app

import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var activeRingtone: Ringtone? = null
    private var activeVibrator: Vibrator? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.ournest.app/alarm_buzzer"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startBuzzer" -> {
                    startHardwareAlarmBuzzer()
                    result.success(true)
                }
                "stopBuzzer" -> {
                    stopHardwareAlarmBuzzer()
                    result.success(true)
                }
                "updateBadge" -> {
                    val count = (call.argument<Int>("count") ?: 0).coerceAtLeast(0)
                    updateLauncherBadgeCount(count)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun updateLauncherBadgeCount(count: Int) {
        try {
            val intent = Intent("android.intent.action.BADGE_COUNT_UPDATE").apply {
                putExtra("badge_count", count)
                putExtra("badge_count_package_name", packageName)
                putExtra("badge_count_class_name", MainActivity::class.java.name)
            }
            sendBroadcast(intent)
        } catch (_: Exception) {
        }
        try {
            val sonyIntent = Intent("com.sonyericsson.home.action.UPDATE_BADGE").apply {
                putExtra("com.sonyericsson.home.intent.extra.badge.ACTIVITY_NAME", MainActivity::class.java.name)
                putExtra("com.sonyericsson.home.intent.extra.badge.SHOW_MESSAGE", count > 0)
                putExtra("com.sonyericsson.home.intent.extra.badge.MESSAGE", count.toString())
                putExtra("com.sonyericsson.home.intent.extra.badge.PACKAGE_NAME", packageName)
            }
            sendBroadcast(sonyIntent)
        } catch (_: Exception) {
        }
    }

    private fun startHardwareAlarmBuzzer() {
        try {
            stopHardwareAlarmBuzzer()
            val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

            if (alarmUri != null) {
                val ringtone = RingtoneManager.getRingtone(applicationContext, alarmUri)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    ringtone?.audioAttributes = AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    ringtone?.isLooping = true
                }
                ringtone?.play()
                activeRingtone = ringtone
            }

            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vm?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }
            val pattern = longArrayOf(0, 800, 400, 800, 400)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, 0)
            }
            activeVibrator = vibrator
        } catch (_: Exception) {
        }
    }

    private fun stopHardwareAlarmBuzzer() {
        try {
            activeRingtone?.stop()
            activeRingtone = null
        } catch (_: Exception) {
        }
        try {
            activeVibrator?.cancel()
            activeVibrator = null
        } catch (_: Exception) {
        }
    }

    override fun onDestroy() {
        stopHardwareAlarmBuzzer()
        super.onDestroy()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyLockScreenPolicy(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        applyLockScreenPolicy(intent)
    }

    /**
     * Only a ringing shared alarm may appear over the lock screen / wake the
     * screen. Normal launches (family chat) must require unlocking (audit F15).
     *
     * flutter_local_notifications puts the notification payload in the
     * "payload" extra; our alarm payloads start with "alarm_ring:" or
     * "alarm_escalate:" (see alarm_scheduler_service.dart).
     */
    private fun applyLockScreenPolicy(intent: Intent?) {
        val payload = intent?.getStringExtra("payload") ?: ""
        val isAlarm = payload.startsWith("alarm_ring:") || payload.startsWith("alarm_escalate:")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(isAlarm)
            setTurnScreenOn(isAlarm)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (isAlarm) window.addFlags(flags) else window.clearFlags(flags)
        }
    }
}
