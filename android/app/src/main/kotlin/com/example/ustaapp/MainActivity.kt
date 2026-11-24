package com.example.ustaapp

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import com.example.call_screen.CallScreenPlugin
import org.json.JSONObject

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        wakeUpAndUnlock()
        handleCallIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        wakeUpAndUnlock()
        handleCallIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        wakeUpAndUnlock()
    }

    private fun handleCallIntent(intent: Intent?) {
        if (intent == null) return

        var cid: String? = intent.getStringExtra("cagri_id")

        // 1. Doğrudan intent extrasında cagri_id yoksa, flutter_local_notifications payload'ına bak
        if (cid.isNullOrEmpty()) {
            val payload = intent.getStringExtra("payload")
            if (!payload.isNullOrEmpty()) {
                try {
                    val json = JSONObject(payload)
                    val data = json.optJSONObject("data")
                    cid = data?.optString("cagri_id") ?: json.optString("cagri_id")
                } catch (e: Exception) {
                    val match = Regex("\"cagri_id\"\\s*:\\s*\"([^\"]+)\"").find(payload)
                    cid = match?.groupValues?.get(1)
                }
            }
        }

        // 2. Diğer olası intent bundle anahtarlarını kontrol et
        if (cid.isNullOrEmpty()) {
            val extras = intent.extras
            if (extras != null) {
                for (key in extras.keySet()) {
                    val value = extras.get(key)?.toString()
                    if (value != null && (key.contains("cagri", ignoreCase = true) || key.contains("call", ignoreCase = true))) {
                        cid = value
                        break
                    }
                }
            }
        }

        if (!cid.isNullOrEmpty()) {
            CallScreenPlugin.pendingCallId = cid
            CallScreenPlugin.activeChannel?.invokeMethod("onIncomingCall", cid)
        }
    }

    private fun wakeUpAndUnlock() {
        try {
            // Güçlü WakeLock ile ekranı aydınlat
            val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
            @Suppress("DEPRECATION")
            val wl = powerManager?.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
                "ustaapp:main_activity_wake"
            )
            wl?.acquire(20000)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
                val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
                keyguardManager?.requestDismissKeyguard(this, null)
            }
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
