import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../config/app_config.dart';
import 'download_service.dart';

class UpdateService {
  static const autoCheckKey = 'auto_check_update';

  static Future<bool> isAutoCheckEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(autoCheckKey) ?? true;
  }

  static Future<void> setAutoCheckEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(autoCheckKey, value);
  }

  static Future<void> checkOnStart(BuildContext context) async {
    final enabled = await isAutoCheckEnabled();
    if (!enabled) return;

    if (!context.mounted) return;

    await check(context, silent: true);
  }

  /// 获取当前平台对应的 os 参数
  static String get _platformOs {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'android';
  }

  /// 获取当前平台显示名
  static String get _platformName {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Android';
  }

  static Future<void> check(
    BuildContext context, {
    bool silent = false,
  }) async {
    final result = await ApiClient.instance.get(
      'app/version/check',
      query: {
        'platform': _platformOs,
        'version': AppConfig.appVersion,
        'build_number': AppConfig.buildNumber,
      },
    );

    if (!context.mounted) return;

    if (!result.success || result.data is! Map<String, dynamic>) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message.isEmpty ? '检查更新失败' : result.message)),
        );
      }
      return;
    }

    final data = result.data as Map<String, dynamic>;
    final hasUpdate = data['has_update'] == true;

    if (!hasUpdate) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前已是最新版本')),
        );
      }
      return;
    }

    final forceUpdate = data['force_update'] == true;
    final title = data['title']?.toString() ?? '发现新版本';
    final content = data['content']?.toString() ?? '';
    final version = data['version']?.toString() ?? '';

    // 使用 download.php?os=xxx 作为下载地址
    final downloadUrl = '${AppConfig.downloadBase}?os=$_platformOs';
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(
            '版本：$version\n平台：$_platformName\n\n$content',
          ),
          actions: [
            if (!forceUpdate)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('稍后再说'),
              ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();

                // 使用内置下载器下载，完成后自动打开
                final fileName = 'QingTan_${version}_$_platformOs'
                    '${Platform.isWindows ? ".exe" : Platform.isAndroid ? ".apk" : ""}';

                DownloadService.instance.download(
                  url: downloadUrl,
                  fileName: fileName,
                  taskId: 'update_$version',
                  openOnComplete: true,
                );
                messenger.showSnackBar(
                  const SnackBar(content: Text('已开始下载，可在下载管理中查看进度')),
                );
              },
              child: const Text('立即更新'),
            ),
          ],
        );
      },
    );
  }
}
