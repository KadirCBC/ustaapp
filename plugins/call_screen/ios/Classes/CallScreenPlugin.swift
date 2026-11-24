import Flutter
import UIKit

public class CallScreenPlugin: NSObject, FlutterPlugin {
  private static var pendingCallId: String?
  private static var channel: FlutterMethodChannel?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.example.ustaapp/call_screen", binaryMessenger: registrar.messenger())
    let instance = CallScreenPlugin()
    self.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "getPendingCallId":
      let id = CallScreenPlugin.pendingCallId
      CallScreenPlugin.pendingCallId = nil
      result(id)
    case "wakeScreenAndUnlock":
      // iOS CallKit handles screen wake through PushKit
      result(true)
    case "stopRinging":
      result(true)
    case "checkSpecialPermissions":
      result([
        "overlay": true,
        "battery": true,
        "fullScreen": true,
        "isXiaomi": false
      ])
    case "requestBatteryOptimization":
      result(true)
    case "requestOverlayPermission":
      result(true)
    case "requestFullScreenIntentPermission":
      result(true)
    case "isXiaomi":
      result(false)
    case "openMiuiPermissions":
      result(false)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
