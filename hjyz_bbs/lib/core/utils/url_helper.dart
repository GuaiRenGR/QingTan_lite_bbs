import 'package:shared_preferences/shared_preferences.dart';

class UrlHelper {
  UrlHelper._();

  static bool _httpsEnabled = false;

  static const _targetHost = 'newbbs.hj1bbs.top';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _httpsEnabled = prefs.getBool('use_https') ?? false;
  }

  static void setEnabled(bool value) {
    _httpsEnabled = value;
  }

  static bool get isEnabled => _httpsEnabled;

  static String fix(String url) {
    if (!_httpsEnabled || url.isEmpty) return url;
    if (url.startsWith('http://$_targetHost')) {
      return url.replaceFirst('http://$_targetHost', 'https://$_targetHost');
    }
    return url;
  }
}
