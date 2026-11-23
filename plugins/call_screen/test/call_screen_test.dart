import 'package:flutter_test/flutter_test.dart';
import 'package:call_screen/call_screen.dart';
import 'package:call_screen/call_screen_platform_interface.dart';
import 'package:call_screen/call_screen_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockCallScreenPlatform
    with MockPlatformInterfaceMixin
    implements CallScreenPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final CallScreenPlatform initialPlatform = CallScreenPlatform.instance;

  test('$MethodChannelCallScreen is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelCallScreen>());
  });

  test('getPlatformVersion', () async {
    CallScreen callScreenPlugin = CallScreen();
    MockCallScreenPlatform fakePlatform = MockCallScreenPlatform();
    CallScreenPlatform.instance = fakePlatform;

    expect(await callScreenPlugin.getPlatformVersion(), '42');
  });
}
