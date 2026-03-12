import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class DeviceService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<Map<String, String>> getDeviceInfo() async {
    String deviceId = 'unknown';
    String deviceName = 'Unknown Device';

    try {
      if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        deviceId = webInfo.userAgent ?? 'web';
        deviceName = webInfo.browserName.name;
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        deviceName = androidInfo.model;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'ios_unknown';
        deviceName = iosInfo.name;
      } else if (Platform.isMacOS) {
        final macInfo = await _deviceInfo.macOsInfo;
        deviceId = macInfo.systemGUID ?? 'macos_unknown';
        deviceName = macInfo.computerName;
      } else if (Platform.isWindows) {
        final winInfo = await _deviceInfo.windowsInfo;
        deviceId = winInfo.deviceId;
        deviceName = winInfo.computerName;
      } else if (Platform.isLinux) {
        final linuxInfo = await _deviceInfo.linuxInfo;
        deviceId = linuxInfo.machineId ?? 'linux_unknown';
        deviceName = linuxInfo.name;
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
    }

    return {
      'id': deviceId,
      'name': deviceName,
    };
  }
}
