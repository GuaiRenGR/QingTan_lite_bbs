import 'package:flutter_test/flutter_test.dart';
import 'package:hjyz_bbs/core/services/music_player_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await MusicPlayerSettingsService.init();
  });

  test('uses the requested now-playing effect defaults', () {
    final settings = MusicPlayerSettingsService.settings.value;

    expect(settings.dynamicBackground, isFalse);
    expect(settings.musicReactive, isFalse);
    expect(settings.coverBlurBackground, isTrue);
    expect(settings.coverBlurAmount, 40.0);
    expect(settings.coverBlurDarken, 0.4);
  });

  test('cover blur disables dynamic background and audio reactivity', () async {
    await MusicPlayerSettingsService.setCoverBlurBackground(false);
    await MusicPlayerSettingsService.setDynamicBackground(true);
    await MusicPlayerSettingsService.setMusicReactive(true);
    await MusicPlayerSettingsService.setCoverBlurBackground(true);

    final settings = MusicPlayerSettingsService.settings.value;
    expect(settings.coverBlurBackground, isTrue);
    expect(settings.dynamicBackground, isFalse);
    expect(settings.musicReactive, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('music_player_cover_blur_background'), isTrue);
    expect(prefs.getBool('music_player_dynamic_background'), isFalse);
    expect(prefs.getBool('music_player_music_reactive'), isFalse);
  });

  test('audio reactivity requires the dynamic background', () async {
    await MusicPlayerSettingsService.setCoverBlurBackground(false);
    await MusicPlayerSettingsService.setDynamicBackground(false);
    await MusicPlayerSettingsService.setMusicReactive(true);

    final settings = MusicPlayerSettingsService.settings.value;
    expect(settings.dynamicBackground, isFalse);
    expect(settings.musicReactive, isFalse);
  });

  test('normalizes persisted conflicts and effect ranges', () {
    const conflicted = MusicPlayerVisualSettings(
      dynamicBackground: true,
      musicReactive: true,
      coverBlurBackground: true,
      coverBlurAmount: 800,
      coverBlurDarken: -1,
    );

    final normalized = conflicted.normalized();
    expect(normalized.dynamicBackground, isFalse);
    expect(normalized.musicReactive, isFalse);
    expect(normalized.coverBlurAmount, 500);
    expect(normalized.coverBlurDarken, 0);
  });
}
