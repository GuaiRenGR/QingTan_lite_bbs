import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

/// 设备信息工具类，获取设备名称用于标识登录设备
class DeviceHelper {
  static String? _cachedName;
  static final _plugin = DeviceInfoPlugin();

  /// 获取设备名称（带缓存）
  static Future<String> getDeviceName() async {
    if (_cachedName != null) return _cachedName!;

    try {
      if (Platform.isAndroid) {
        final info = await _plugin.androidInfo;
        _cachedName = '${info.manufacturer} ${info.model}';
      } else if (Platform.isIOS) {
        final info = await _plugin.iosInfo;
        _cachedName = info.name;
      } else if (Platform.isWindows) {
        final info = await _plugin.windowsInfo;
        _cachedName = info.computerName;
      } else if (Platform.isMacOS) {
        final info = await _plugin.macOsInfo;
        _cachedName = info.computerName;
      } else if (Platform.isLinux) {
        final info = await _plugin.linuxInfo;
        _cachedName = info.name;
      } else {
        _cachedName = '未知设备';
      }
    } catch (_) {
      _cachedName = '未知设备';
    }

    return _cachedName!;
  }
}
