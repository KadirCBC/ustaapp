package com.example.call_screen

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class CallScreenPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    companion object {
        const val CHANNEL = "com.example.ustaapp/call_screen"
        var pluginInstance: CallScreenPlugin? = null
        var appContext: Context? = null
        var currentActivity: Activity? = null
        var pendingCallId: String? = null
        var activeChannel: MethodChannel? = null

        fun stopRinging() {
            // Audio players handled via Flutter layers
        }

        fun wakeAndLaunch(context: Context, cagriId: String) {
            pendingCallId = cagriId

            // 1. Ekranı ve İşlemciyi Güçlü Şekilde Uyandır (WakeLock)
            try {
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
                @Suppress("DEPRECATION")
                val wl = powerManager?.newWakeLock(
                    PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                    PowerManager.ACQUIRE_CAUSES_WAKEUP or
                    PowerManager.ON_AFTER_RELEASE,
                    "ustaapp:call_wake_lock"
                )
                wl?.acquire(35000) // 35 saniye ekranı aydınlat
            } catch (e: Exception) {
                e.printStackTrace()
            }

            // 2. MainActivity'yi Tam Ekran Olarak Doğrudan Öne Getir
            try {
                val intent = Intent(context, Class.forName("com.example.ustaapp.MainActivity")).apply {
                    action = "com.example.ustaapp.INCOMING_CALL"
                    addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP
                    )
                    putExtra("cagri_id", cagriId)
                }
                context.startActivity(intent)
            } catch (e: Exception) {
                e.printStackTrace()
            }

            // 3. UI motoru açıksa anında event gönder
            try {
                activeChannel?.invokeMethod("onIncomingCall", cagriId)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        appContext = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL)
        activeChannel = channel
        channel?.setMethodCallHandler(this)
        pluginInstance = this
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        if (activeChannel == channel) {
            activeChannel = null
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        currentActivity = binding.activity
        applyLockScreenFlags(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        currentActivity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        currentActivity = binding.activity
        applyLockScreenFlags(binding.activity)
    }

    override fun onDetachedFromActivity() {
        currentActivity = null
    }

    private fun applyLockScreenFlags(activity: Activity) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                activity.setShowWhenLocked(true)
                activity.setTurnScreenOn(true)
                val keyguardManager = activity.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
                keyguardManager?.requestDismissKeyguard(activity, null)
            }
            @Suppress("DEPRECATION")
            activity.window.addFlags(
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        val ctx = appContext
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${Build.VERSION.RELEASE}")
            }
            "wakeScreenAndUnlock" -> {
                val callId = call.argument<String>("cagri_id") ?: ""
                if (ctx != null) {
                    wakeAndLaunch(ctx, callId)
                    result.success(true)
                } else {
                    result.success(false)
                }
            }
            "stopRinging" -> {
                stopRinging()
                result.success(true)
            }
            "getPendingCallId" -> {
                val id = pendingCallId
                pendingCallId = null
                result.success(id)
            }
            "checkSpecialPermissions" -> {
                val hasOverlay = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && ctx != null) {
                    Settings.canDrawOverlays(ctx)
                } else true

                val powerManager = ctx?.getSystemService(Context.POWER_SERVICE) as? PowerManager
                val isBatteryIgnored = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && ctx != null) {
                    powerManager?.isIgnoringBatteryOptimizations(ctx.packageName) ?: false
                } else true

                val notificationManager = ctx?.getSystemService(Context.NOTIFICATION_SERVICE) as? android.app.NotificationManager
                val canFullScreen = if (Build.VERSION.SDK_INT >= 34 && notificationManager != null) {
                    notificationManager.canUseFullScreenIntent()
                } else true

                val isXiaomiDevice = Build.MANUFACTURER.equals("Xiaomi", ignoreCase = true) ||
                                     Build.MANUFACTURER.equals("Redmi", ignoreCase = true) ||
                                     Build.MANUFACTURER.equals("POCO", ignoreCase = true)

                result.success(mapOf(
                    "overlay" to hasOverlay,
                    "battery" to isBatteryIgnored,
                    "fullScreen" to canFullScreen,
                    "isXiaomi" to isXiaomiDevice
                ))
            }
            "isXiaomi" -> {
                val isXiaomiDevice = Build.MANUFACTURER.equals("Xiaomi", ignoreCase = true) ||
                                     Build.MANUFACTURER.equals("Redmi", ignoreCase = true) ||
                                     Build.MANUFACTURER.equals("POCO", ignoreCase = true)
                result.success(isXiaomiDevice)
            }
            "openMiuiPermissions" -> {
                if (ctx != null) {
                    try {
                        val intent = Intent("miui.intent.action.APP_PERM_EDITOR").apply {
                            setClassName("com.miui.securitycenter", "com.miui.permcenter.permissions.PermissionsEditorActivity")
                            putExtra("extra_pkgname", ctx.packageName)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        ctx.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:${ctx.packageName}")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            ctx.startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("MIUI_PERM_ERROR", e2.message, null)
                        }
                    }
                } else {
                    result.success(false)
                }
            }
            "requestFullScreenIntentPermission" -> {
                if (Build.VERSION.SDK_INT >= 34 && ctx != null) {
                    try {
                        val intent = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
                            data = Uri.parse("package:${ctx.packageName}")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        ctx.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("FULL_SCREEN_INTENT_ERROR", e.message, null)
                    }
                } else {
                    result.success(true)
                }
            }
            }
            "requestBatteryOptimization" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && ctx != null) {
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:${ctx.packageName}")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        ctx.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            ctx.startActivity(intent)
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
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && ctx != null) {
                    try {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:${ctx.packageName}")
                        ).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        ctx.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:${ctx.packageName}")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            ctx.startActivity(intent)
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
}
