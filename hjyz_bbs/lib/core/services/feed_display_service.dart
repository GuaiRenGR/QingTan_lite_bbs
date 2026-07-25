import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeedDisplayService {
  FeedDisplayService._();

  static const compactTextPostsKey = 'compact_text_only_posts';
  static final compactTextOnlyPosts = ValueNotifier<bool>(false);

  static Future<void> init() async {
    final preferences = await SharedPreferences.getInstance();
    compactTextOnlyPosts.value =
        preferences.getBool(compactTextPostsKey) ?? false;
  }

  static Future<void> setCompactTextOnlyPosts(bool value) async {
    compactTextOnlyPosts.value = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(compactTextPostsKey, value);
  }
}
