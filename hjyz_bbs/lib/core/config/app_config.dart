class AppConfig {
  AppConfig._();

  static const String apiEntry = 'http://newbbs.hj1bbs.top/index.php';

  static const String defaultAvatar =
      'https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y';

  static const int pageSize = 20;

  /// 当前版本号（与 pubspec.yaml 保持一致）
  static const String appVersion = '1.1.5';

  /// 构建号（与 pubspec.yaml 保持一致）
  static const int buildNumber = 10;

  /// 下载页基础地址
  static const String downloadBase = 'http://newbbs.hj1bbs.top/download.php';
}
