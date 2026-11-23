
import 'call_screen_platform_interface.dart';

class CallScreen {
  Future<String?> getPlatformVersion() {
    return CallScreenPlatform.instance.getPlatformVersion();
  }
}
