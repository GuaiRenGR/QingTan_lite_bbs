import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';

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

  static Future<void> check(
    BuildContext context, {
    bool silent = false,
  }) async {
    final info = await PackageInfo.fromPlatform();

    final platform = Platform.isAndroid
        ? 'android'
        : Platform.isIOS
            ? 'ios'
            : 'all';

    final buildNumber = int.tryParse(info.buildNumber) ?? 1;

    final result = await ApiClient.instance.get(
      'app/version/check',
      query: {
        'platform': platform,
        'version': info.version,
        'build_number': buildNumber,
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
    final downloadUrl = data['download_url']?.toString() ?? '';

    await showDialog<void>(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(
            '版本：$version\n\n$content',
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
                if (downloadUrl.isEmpty) return;

                final uri = Uri.tryParse(downloadUrl);
                if (uri == null) return;

                await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
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
