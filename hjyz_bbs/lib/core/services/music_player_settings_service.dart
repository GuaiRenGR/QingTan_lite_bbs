import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MusicPlayerVisualSettings {
  final bool advancedBlur;
  final bool musicReactive;
  final bool dynamicBackground;
  final bool coverBlurBackground;
  final double coverBlurAmount;
  final double coverBlurDarken;

  const MusicPlayerVisualSettings({
    this.advancedBlur = false,
    this.musicReactive = false,
    this.dynamicBackground = false,
    this.coverBlurBackground = true,
    this.coverBlurAmount = 1.5,
    this.coverBlurDarken = 0.2,
  });

  MusicPlayerVisualSettings copyWith({
    bool? advancedBlur,
    bool? musicReactive,
    bool? dynamicBackground,
    bool? coverBlurBackground,
    double? coverBlurAmount,
    double? coverBlurDarken,
  }) {
    return MusicPlayerVisualSettings(
      advancedBlur: advancedBlur ?? this.advancedBlur,
      musicReactive: musicReactive ?? this.musicReactive,
      dynamicBackground: dynamicBackground ?? this.dynamicBackground,
      coverBlurBackground: coverBlurBackground ?? this.coverBlurBackground,
      coverBlurAmount: coverBlurAmount ?? this.coverBlurAmount,
      coverBlurDarken: coverBlurDarken ?? this.coverBlurDarken,
    );
  }

  MusicPlayerVisualSettings normalized() {
    final dynamicEnabled = dynamicBackground && !coverBlurBackground;
    return copyWith(
      dynamicBackground: dynamicEnabled,
      musicReactive: musicReactive && dynamicEnabled,
      coverBlurAmount: coverBlurAmount.clamp(0.0, 500.0).toDouble(),
      coverBlurDarken: coverBlurDarken.clamp(0.0, 0.8).toDouble(),
    );
  }
}

class MusicPlayerSettingsService {
  MusicPlayerSettingsService._();

  static const _advancedBlurKey = 'music_player_advanced_blur';
  static const _musicReactiveKey = 'music_player_music_reactive';
  static const _dynamicBackgroundKey = 'music_player_dynamic_background';
  static const _coverBlurBackgroundKey =
      'music_player_cover_blur_background';
  static const _coverBlurAmountKey = 'music_player_cover_blur_amount';
  static const _coverBlurDarkenKey = 'music_player_cover_blur_darken';

  static final settings = ValueNotifier<MusicPlayerVisualSettings>(
    const MusicPlayerVisualSettings(),
  );

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loaded = MusicPlayerVisualSettings(
        advancedBlur: prefs.getBool(_advancedBlurKey) ?? false,
        musicReactive: prefs.getBool(_musicReactiveKey) ?? false,
        dynamicBackground: prefs.getBool(_dynamicBackgroundKey) ?? false,
        coverBlurBackground:
            prefs.getBool(_coverBlurBackgroundKey) ?? true,
        coverBlurAmount: prefs.getDouble(_coverBlurAmountKey) ?? 1.5,
        coverBlurDarken: prefs.getDouble(_coverBlurDarkenKey) ?? 0.2,
      ).normalized();
      settings.value = loaded;
      await _persistVisualState(prefs, loaded);
    } catch (_) {}
  }

  static Future<void> setAdvancedBlur(bool value) async {
    settings.value = settings.value.copyWith(advancedBlur: value);
    await _saveBool(_advancedBlurKey, value);
  }

  static Future<void> setMusicReactive(bool value) async {
    final current = settings.value;
    final enabled = value &&
        current.dynamicBackground &&
        !current.coverBlurBackground;
    settings.value = current.copyWith(musicReactive: enabled);
    await _saveBool(_musicReactiveKey, enabled);
  }

  static Future<void> setDynamicBackground(bool value) async {
    final current = settings.value;
    final enabled = value && !current.coverBlurBackground;
    final next = current.copyWith(
      dynamicBackground: enabled,
      musicReactive: enabled ? current.musicReactive : false,
    );
    settings.value = next;
    await _saveVisualState(next);
  }

  static Future<void> setCoverBlurBackground(bool value) async {
    final current = settings.value;
    final next = current.copyWith(
      coverBlurBackground: value,
      dynamicBackground: value ? false : current.dynamicBackground,
      musicReactive: value ? false : current.musicReactive,
    );
    settings.value = next;
    await _saveVisualState(next);
  }

  static Future<void> setCoverBlurAmount(double value) async {
    final normalized = value.clamp(0.0, 500.0).toDouble();
    settings.value = settings.value.copyWith(coverBlurAmount: normalized);
    await _saveDouble(_coverBlurAmountKey, normalized);
  }

  static Future<void> setCoverBlurDarken(double value) async {
    final normalized = value.clamp(0.0, 0.8).toDouble();
    settings.value = settings.value.copyWith(coverBlurDarken: normalized);
    await _saveDouble(_coverBlurDarkenKey, normalized);
  }

  static Future<void> _saveVisualState(
    MusicPlayerVisualSettings value,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _persistVisualState(prefs, value);
    } catch (_) {}
  }

  static Future<void> _persistVisualState(
    SharedPreferences prefs,
    MusicPlayerVisualSettings value,
  ) async {
    await Future.wait([
      prefs.setBool(_musicReactiveKey, value.musicReactive),
      prefs.setBool(_dynamicBackgroundKey, value.dynamicBackground),
      prefs.setBool(_coverBlurBackgroundKey, value.coverBlurBackground),
      prefs.setDouble(_coverBlurAmountKey, value.coverBlurAmount),
      prefs.setDouble(_coverBlurDarkenKey, value.coverBlurDarken),
    ]);
  }

  static Future<void> _saveBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }

  static Future<void> _saveDouble(String key, double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(key, value);
    } catch (_) {}
  }
}
