package com.example.ustaapp

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class CallScreenPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "com.example.ustaapp/call_screen"
        var pluginInstance: CallScreenPlugin? = null
        var appContext: Context? = null
        var pendingCallId: String? = null
        var activeChannel: MethodChannel? = null

        fun wakeAndLaunch(context: Context, cagriId: String) {
            pendingCallId = cagriId
            try {
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
                @Suppress("DEPRECATION")
                val wl = powerManager?.newWakeLock(
                    PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                    PowerManager.ACQUIRE_CAUSES_WAKEUP or
                    PowerManager.ON_AFTER_RELEASE,
                    "ustaapp:call_wake_lock"
                )
                wl?.acquire(35000) // 35 saniye ekranı aydınlat ve işlemciyi uyanık tut
            } catch (e: Exception) {
                e.printStackTrace()
            }

            try {
                val intent = Intent(context, MainActivity::class.java).apply {
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

            try {
                activeChannel?.invokeMethod("onIncomingCall", cagriId)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
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

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = appContext
        when (call.method) {
            "wakeScreenAndUnlock" -> {
                val callId = call.argument<String>("cagri_id") ?: ""
                if (ctx != null) {
                    wakeAndLaunch(ctx, callId)
                    result.success(true)
                } else {
                    result.success(false)
                }
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

                result.success(mapOf(
                    "overlay" to hasOverlay,
                    "battery" to isBatteryIgnored
                ))
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
