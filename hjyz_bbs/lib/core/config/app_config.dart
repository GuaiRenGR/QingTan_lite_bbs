import '../api/server_config.dart';

class AppConfig {
  AppConfig._();

  /// 默认服务器入口（单服务器兼容）
  static const String apiEntry = 'http://newbbs.hj1bbs.top/index.php';

  /// 多服务器列表
  static const List<ServerConfig> serverList = [
    ServerConfig(
      id: 1,
      name: '主服务器',
      url: 'http://newbbs.hj1bbs.top/index.php',
      weight: 10,
    ),
  ];

  static const String defaultAvatar =
      'https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y';

  static const int pageSize = 20;

  /// 当前版本号（与 pubspec.yaml 保持一致）
  static const String appVersion = '1.2.0';

  /// 构建号（与 pubspec.yaml 保持一致）
  static const int buildNumber = 26;

  /// 下载页基础地址
  static const String downloadBase = 'http://newbbs.hj1bbs.top/download.php';
}
