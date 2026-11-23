package com.example.ustaapp

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.ustaapp/call_screen"
    private var wakeLock: PowerManager.WakeLock? = null
    private var methodChannel: MethodChannel? = null
    private var pendingCallId: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "wakeScreenAndUnlock" -> {
                    val callId = call.argument<String>("cagri_id")
                    wakeUpAndBringToFront(callId)
                    result.success(true)
                }
                "getPendingCallId" -> {
                    val id = pendingCallId
                    pendingCallId = null
                    result.success(id)
                }
                "checkSpecialPermissions" -> {
                    val hasOverlay = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(this)
                    } else true

                    val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
                    val isBatteryIgnored = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        powerManager?.isIgnoringBatteryOptimizations(packageName) ?: false
                    } else true

                    result.success(mapOf(
                        "overlay" to hasOverlay,
                        "battery" to isBatteryIgnored
                    ))
                }
                "requestBatteryOptimization" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            try {
                                val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                                startActivity(intent)
                                result.success(true)
                            } catch (e2: Exception) {
                                result.error("BATTERY_ERROR", e2.message, null)
                            }
                        }
                    } else {
                        result.success(true)
                    }
                }
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            try {
                                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                    data = Uri.parse("package:$packageName")
                                }
                                startActivity(intent)
                                result.success(true)
                            } catch (e2: Exception) {
                                result.error("OVERLAY_ERROR", e2.message, null)
                            }
                        }
                    } else {
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }

        pendingCallId?.let { cid ->
            channel.invokeMethod("onIncomingCall", cid)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleCallIntent(intent)
        wakeUpAndUnlock()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleCallIntent(intent)
        wakeUpAndUnlock()
    }

    private fun handleCallIntent(intent: Intent?) {
        val cid = intent?.getStringExtra("cagri_id")
        if (!cid.isNullOrEmpty()) {
            pendingCallId = cid
            methodChannel?.invokeMethod("onIncomingCall", cid)
        }
    }

    override fun onResume() {
        super.onResume()
        wakeUpAndUnlock()
    }

    private fun wakeUpAndBringToFront(cagriId: String?) {
        wakeUpAndUnlock()
        if (!cagriId.isNullOrEmpty()) {
            pendingCallId = cagriId
        }
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or
                         Intent.FLAG_ACTIVITY_SINGLE_TOP or
                         Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                putExtra("cagri_id", cagriId)
            }
            startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        if (!cagriId.isNullOrEmpty()) {
            methodChannel?.invokeMethod("onIncomingCall", cagriId)
        }
    }

    private fun wakeUpAndUnlock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
            if (powerManager != null) {
                @Suppress("DEPRECATION")
                val wl = powerManager.newWakeLock(
                    PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                    PowerManager.ACQUIRE_CAUSES_WAKEUP or
                    PowerManager.ON_AFTER_RELEASE,
                    "UstaApp:CallWakeLock"
                )
                wl.acquire(30000) // 30 saniye boyunca ekranı fiziksel açık ve parlak tut
                wakeLock = wl
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            keyguardManager?.requestDismissKeyguard(this, null)
        }
        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
        )
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
