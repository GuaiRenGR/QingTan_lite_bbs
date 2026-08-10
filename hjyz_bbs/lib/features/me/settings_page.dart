import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/api/server_manager.dart';
import '../../core/config/app_config.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/feed_display_service.dart';
import '../../core/services/music_player_settings_service.dart';
import '../../core/services/sensitive_content_service.dart';
import '../../core/services/update_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/url_helper.dart';
import '../auth/auth_controller.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool showImagesOnMobile = true;
  bool compactTextOnlyPosts = false;
  bool nativeNotifications = true;
  bool autoCheckUpdate = true;
  bool useHttps = true;
  SensitiveContentMode sensitiveContentMode = SensitiveContentMode.warn;
  bool useBuiltinDownloader = true;
  bool testingServers = false;
  bool settingsLoaded = false;
  String appVersion = '';
  String contactUrl = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadVersion();
    _loadPublicConfig();
  }

  Future<void> _loadPublicConfig() async {
    final result = await ApiClient.instance.get('system/public-config');
    if (!mounted || !result.success || result.data is! Map) return;
    setState(() {
      contactUrl = ((result.data as Map)['contact_url'] ?? '')
          .toString()
          .trim();
    });
  }

  Future<void> _openContact() async {
    final uri = Uri.tryParse(contactUrl);
    if (uri == null || !uri.hasScheme) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('管理员暂未配置联系我们链接')));
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开联系我们链接')));
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = await UpdateService.isAutoCheckEnabled();
      if (!mounted) return;
      setState(() {
        showImagesOnMobile = prefs.getBool('show_images_on_mobile') ?? true;
        compactTextOnlyPosts = FeedDisplayService.compactTextOnlyPosts.value;
        nativeNotifications = prefs.getBool('native_notifications') ?? true;
        useHttps = prefs.getBool('use_https') ?? true;
        sensitiveContentMode = SensitiveContentService.mode.value;
        useBuiltinDownloader = prefs.getBool('use_builtin_downloader') ?? true;
        autoCheckUpdate = enabled;
        settingsLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => settingsLoaded = true);
    }
  }

  Future<void> _loadVersion() async {
    if (mounted) {
      setState(() {
        appVersion = AppConfig.appVersion;
      });
    }
  }

  Future<void> _saveBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }

  Future<void> _testServers() async {
    if (testingServers) return;
    setState(() => testingServers = true);
    final manager = ServerManager.instance;
    final refreshed = await manager.refreshServerList();
    if (!refreshed) await manager.checkAllServers();
    if (!mounted) return;
    setState(() => testingServers = false);
  }

  Future<void> _selectServer(int serverId) async {
    await ServerManager.instance.selectServer(serverId);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已切换服务器')));
  }

  String _serverStatus(int serverId) {
    final health = ServerManager.instance.healthFor(serverId);
    if (health == null) return '尚未测速';
    if (!health.reachable) return '连接失败';
    return '${health.latencyMs} ms';
  }

  void _showInfo(String title, String content) {
    showAboutDialog(
      context: context,
      applicationName: '轻坛',
      applicationVersion: appVersion.isNotEmpty ? appVersion : '1.0.4',
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset('icon.png', width: 48, height: 48),
      ),
      children: [Text(content)],
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('退出登录'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await ref.read(authControllerProvider.notifier).logout();
    if (!mounted) return;

    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final appBar = AppBar(title: const Text('设置'));

    if (!settingsLoaded) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBg(context),
        appBar: appBar,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: appBar,
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
                onTap: () => context.push('/account-security'),
              ),
              if (auth.loggedIn)
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    '退出登录',
                    style: TextStyle(color: Colors.red),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _logout,
                ),
            ],
          ),
          _Section(
            title: '浏览设置',
            children: [
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
              SwitchListTile(
                secondary: const Icon(Icons.compress_rounded),
                title: const Text('缩小无图帖子占用位置'),
                subtitle: const Text('瀑布流中的无图帖子不再显示占位图'),
                value: compactTextOnlyPosts,
                onChanged: (value) {
                  setState(() => compactTextOnlyPosts = value);
                  FeedDisplayService.setCompactTextOnlyPosts(value);
                },
              ),
              ListTile(
                leading: const Icon(Icons.warning_amber_outlined),
                title: const Text('敏感图片'),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SegmentedButton<SensitiveContentMode>(
                    segments: const [
                      ButtonSegment(
                        value: SensitiveContentMode.warn,
                        icon: Icon(Icons.visibility_outlined),
                        label: Text('警告'),
                      ),
                      ButtonSegment(
                        value: SensitiveContentMode.block,
                        icon: Icon(Icons.visibility_off_outlined),
                        label: Text('屏蔽'),
                      ),
                    ],
                    selected: {sensitiveContentMode},
                    onSelectionChanged: (selection) {
                      final value = selection.first;
                      setState(() => sensitiveContentMode = value);
                      SensitiveContentService.setMode(value);
                    },
                  ),
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.lock_outlined),
                title: const Text('使用HTTPS连接'),
                subtitle: const Text('将本站链接转为HTTPS'),
                value: useHttps,
                onChanged: (value) {
                  setState(() {
                    useHttps = value;
                  });
                  _saveBool('use_https', value);
                  UrlHelper.setEnabled(value);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.download_outlined),
                title: const Text('使用内置下载器'),
                subtitle: const Text('多线程下载附件，关闭则用浏览器下载'),
                value: useBuiltinDownloader,
                onChanged: (value) {
                  setState(() {
                    useBuiltinDownloader = value;
                  });
                  _saveBool('use_builtin_downloader', value);
                },
              ),
              _SettingTile(
                icon: Icons.folder_open_outlined,
                title: '下载管理',
                subtitle: '查看和管理下载任务',
                onTap: () => context.push('/downloads'),
              ),
            ],
          ),
          ValueListenableBuilder<MusicPlayerVisualSettings>(
            valueListenable: MusicPlayerSettingsService.settings,
            builder: (context, playerSettings, _) {
              return _Section(
                title: '播放器设置',
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.blur_on_rounded),
                    title: const Text('高级模糊'),
                    value: playerSettings.advancedBlur,
                    onChanged: MusicPlayerSettingsService.setAdvancedBlur,
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.wallpaper_rounded),
                    title: const Text('正在播放模糊封面背景'),
                    subtitle: const Text('使用当前封面作为正在播放页面背景'),
                    value: playerSettings.coverBlurBackground,
                    onChanged:
                        MusicPlayerSettingsService.setCoverBlurBackground,
                  ),
                  if (playerSettings.coverBlurBackground) ...[
                    _PlayerEffectSliderTile(
                      title: '封面模糊强度',
                      valueLabel:
                          '当前模糊：${playerSettings.coverBlurAmount.toStringAsFixed(1)}',
                      value: playerSettings.coverBlurAmount,
                      max: 500,
                      divisions: 100,
                      onChanged: MusicPlayerSettingsService.setCoverBlurAmount,
                    ),
                    _PlayerEffectSliderTile(
                      title: '背景调暗',
                      valueLabel:
                          '调暗强度：${playerSettings.coverBlurDarken.toStringAsFixed(2)}',
                      value: playerSettings.coverBlurDarken,
                      max: 0.8,
                      divisions: 16,
                      onChanged: MusicPlayerSettingsService.setCoverBlurDarken,
                    ),
                  ],
                  SwitchListTile(
                    secondary: const Icon(Icons.graphic_eq_rounded),
                    title: const Text('正在播放音频律动'),
                    subtitle: Text(
                      playerSettings.coverBlurBackground
                          ? '需关闭模糊封面背景'
                          : playerSettings.dynamicBackground
                          ? '控制正在播放页面的音频律动效果'
                          : '需先开启正在播放动态背景',
                    ),
                    value: playerSettings.musicReactive,
                    onChanged:
                        playerSettings.dynamicBackground &&
                            !playerSettings.coverBlurBackground
                        ? MusicPlayerSettingsService.setMusicReactive
                        : null,
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.animation_rounded),
                    title: const Text('正在播放动态背景'),
                    subtitle: Text(
                      playerSettings.coverBlurBackground
                          ? '需关闭模糊封面背景'
                          : '控制正在播放页面的动态背景效果',
                    ),
                    value: playerSettings.dynamicBackground,
                    onChanged: playerSettings.coverBlurBackground
                        ? null
                        : MusicPlayerSettingsService.setDynamicBackground,
                  ),
                ],
              );
            },
          ),
          _Section(
            title: '通知',
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined),
                title: const Text('系统通知'),
                subtitle: const Text('在系统通知栏显示新消息'),
                value: nativeNotifications,
                onChanged: (value) {
                  setState(() {
                    nativeNotifications = value;
                  });
                  _saveBool('native_notifications', value);
                  if (value) {
                    NotificationService().startPolling();
                  } else {
                    NotificationService().stopPolling();
                  }
                },
              ),
            ],
          ),
          _Section(
            title: '服务器',
            children: [
              ListTile(
                leading: const Icon(Icons.speed_rounded),
                title: const Text('服务器测速'),
                subtitle: const Text('刷新可用服务器并检测连接速度'),
                trailing: testingServers
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                onTap: testingServers ? null : _testServers,
              ),
              for (final server in ServerManager.instance.servers)
                ListTile(
                  leading: Icon(
                    ServerManager.instance.currentServer?.id == server.id
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: ServerManager.instance.currentServer?.id == server.id
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(server.name),
                  subtitle: Text(_serverStatus(server.id)),
                  trailing:
                      ServerManager.instance.healthFor(server.id)?.reachable ==
                          true
                      ? const Icon(Icons.wifi_rounded, size: 20)
                      : const Icon(Icons.wifi_off_rounded, size: 20),
                  onTap: () => _selectServer(server.id),
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
                icon: Icons.contact_support_outlined,
                title: '联系我们',
                subtitle: contactUrl.isEmpty ? '暂未配置联系方式' : '打开管理员设置的联系页面',
                onTap: _openContact,
              ),
              _SettingTile(
                icon: Icons.groups_outlined,
                title: '关于我们',
                subtitle: '社区介绍与联系方式',
                onTap: () {
                  _showInfo('关于我们', '轻坛 是一套适配虚拟主机的轻量社区系统。');
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

class _PlayerEffectSliderTile extends StatelessWidget {
  final String title;
  final String valueLabel;
  final double value;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _PlayerEffectSliderTile({
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(56, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyLarge),
          Text(
            valueLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary(context),
            ),
          ),
          Slider(
            value: value.clamp(0.0, max).toDouble(),
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.card(context),
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
