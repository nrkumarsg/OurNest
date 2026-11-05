package com.ournest.app

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

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
