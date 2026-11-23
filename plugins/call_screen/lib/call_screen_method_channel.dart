import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'call_screen_platform_interface.dart';

/// An implementation of [CallScreenPlatform] that uses method channels.
class MethodChannelCallScreen extends CallScreenPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('call_screen');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
