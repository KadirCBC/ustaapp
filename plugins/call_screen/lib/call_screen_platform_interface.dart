import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'call_screen_method_channel.dart';

abstract class CallScreenPlatform extends PlatformInterface {
  /// Constructs a CallScreenPlatform.
  CallScreenPlatform() : super(token: _token);

  static final Object _token = Object();

  static CallScreenPlatform _instance = MethodChannelCallScreen();

  /// The default instance of [CallScreenPlatform] to use.
  ///
  /// Defaults to [MethodChannelCallScreen].
  static CallScreenPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [CallScreenPlatform] when
  /// they register themselves.
  static set instance(CallScreenPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
