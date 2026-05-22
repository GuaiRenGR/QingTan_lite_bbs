import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/update_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool autoPlayMusic = false;
  bool autoPlayVideo = true;
  bool showImagesOnMobile = true;
  bool autoCheckUpdate = true;
  String appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadVersion();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      setState(() {
        autoPlayMusic = prefs.getBool('auto_play_music') ?? false;
        autoPlayVideo = prefs.getBool('auto_play_video') ?? true;
        showImagesOnMobile = prefs.getBool('show_images_on_mobile') ?? true;
      });
    } catch (_) {}

    final enabled = await UpdateService.isAutoCheckEnabled();
    if (mounted) {
      setState(() {
        autoCheckUpdate = enabled;
      });
    }
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        appVersion = info.version;
      });
    }
  }

  Future<void> _saveBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }

  void _showInfo(String title, String content) {
    showAboutDialog(
      context: context,
      applicationName: '轻坛',
      applicationVersion: appVersion.isNotEmpty ? appVersion : '1.0.4',
      applicationIcon: const FlutterLogo(size: 42),
      children: [
        Text(content),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _Section(
            title: '账号',
            children: [
              _SettingTile(
                icon: Icons.security_outlined,
                title: '账号与安全',
                subtitle: '密码、登录设备、安全设置',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('账号与安全开发中')),
                  );
                },
              ),
            ],
          ),
          _Section(
            title: '浏览设置',
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.music_note_outlined),
                title: const Text('自动播放帖子中的音乐'),
                value: autoPlayMusic,
                onChanged: (value) {
                  setState(() {
                    autoPlayMusic = value;
                  });
                  _saveBool('auto_play_music', value);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.play_circle_outline),
                title: const Text('自动播放视频'),
                value: autoPlayVideo,
                onChanged: (value) {
                  setState(() {
                    autoPlayVideo = value;
                  });
                  _saveBool('auto_play_video', value);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.image_outlined),
                title: const Text('移动网络下显示图片'),
                value: showImagesOnMobile,
                onChanged: (value) {
                  setState(() {
                    showImagesOnMobile = value;
                  });
                  _saveBool('show_images_on_mobile', value);
                },
              ),
            ],
          ),
          _Section(
            title: '更新',
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.system_update_outlined),
                title: const Text('启动时自动检查更新'),
                value: autoCheckUpdate,
                onChanged: (value) {
                  setState(() {
                    autoCheckUpdate = value;
                  });
                  UpdateService.setAutoCheckEnabled(value);
                },
              ),
              _SettingTile(
                icon: Icons.refresh_rounded,
                title: '检查更新',
                subtitle: '当前版本 $appVersion',
                onTap: () {
                  UpdateService.check(context);
                },
              ),
            ],
          ),
          _Section(
            title: '关于',
            children: [
              _SettingTile(
                icon: Icons.groups_outlined,
                title: '关于我们',
                subtitle: '社区介绍与联系方式',
                onTap: () {
                  _showInfo(
                    '关于我们',
                    '轻坛 是一套适配虚拟主机的轻量社区系统。',
                  );
                },
              ),
              _SettingTile(
                icon: Icons.info_outline,
                title: '关于软件',
                subtitle: '版本、协议、版权信息',
                onTap: () {
                  _showInfo(
                    '关于软件',
                    '轻坛 App ${appVersion.isNotEmpty ? appVersion : '1.0.4'}\n基于 Flutter 开发。',
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
