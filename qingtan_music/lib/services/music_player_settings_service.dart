import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MusicPlayerVisualSettings {
  const MusicPlayerVisualSettings({
    this.advancedBlur = false,
    this.musicReactive = false,
    this.dynamicBackground = false,
    this.coverBlurBackground = true,
    this.coverBlurAmount = 40,
    this.coverBlurDarken = 0.4,
  });

  final bool advancedBlur;
  final bool musicReactive;
  final bool dynamicBackground;
  final bool coverBlurBackground;
  final double coverBlurAmount;
  final double coverBlurDarken;

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
      coverBlurAmount: coverBlurAmount.clamp(0, 500).toDouble(),
      coverBlurDarken: coverBlurDarken.clamp(0, 0.8).toDouble(),
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
      final preferences = await SharedPreferences.getInstance();
      final loaded = MusicPlayerVisualSettings(
        advancedBlur: preferences.getBool(_advancedBlurKey) ?? false,
        musicReactive: preferences.getBool(_musicReactiveKey) ?? false,
        dynamicBackground: preferences.getBool(_dynamicBackgroundKey) ?? false,
        coverBlurBackground:
            preferences.getBool(_coverBlurBackgroundKey) ?? true,
        coverBlurAmount: preferences.getDouble(_coverBlurAmountKey) ?? 40,
        coverBlurDarken: preferences.getDouble(_coverBlurDarkenKey) ?? 0.4,
      ).normalized();
      settings.value = loaded;
      await _persist(preferences, loaded);
    } catch (_) {}
  }

  static Future<void> setAdvancedBlur(bool value) async {
    final next = settings.value.copyWith(advancedBlur: value);
    settings.value = next;
    await _saveBool(_advancedBlurKey, value);
  }

  static Future<void> setMusicReactive(bool value) async {
    final current = settings.value;
    final enabled =
        value && current.dynamicBackground && !current.coverBlurBackground;
    final next = current.copyWith(musicReactive: enabled);
    settings.value = next;
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
    final normalized = value.clamp(0, 500).toDouble();
    settings.value = settings.value.copyWith(coverBlurAmount: normalized);
    await _saveDouble(_coverBlurAmountKey, normalized);
  }

  static Future<void> setCoverBlurDarken(double value) async {
    final normalized = value.clamp(0, 0.8).toDouble();
    settings.value = settings.value.copyWith(coverBlurDarken: normalized);
    await _saveDouble(_coverBlurDarkenKey, normalized);
  }

  static Future<void> _saveVisualState(
    MusicPlayerVisualSettings value,
  ) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await _persist(preferences, value);
    } catch (_) {}
  }

  static Future<void> _persist(
    SharedPreferences preferences,
    MusicPlayerVisualSettings value,
  ) async {
    await Future.wait([
      preferences.setBool(_advancedBlurKey, value.advancedBlur),
      preferences.setBool(_musicReactiveKey, value.musicReactive),
      preferences.setBool(_dynamicBackgroundKey, value.dynamicBackground),
      preferences.setBool(
        _coverBlurBackgroundKey,
        value.coverBlurBackground,
      ),
      preferences.setDouble(_coverBlurAmountKey, value.coverBlurAmount),
      preferences.setDouble(_coverBlurDarkenKey, value.coverBlurDarken),
    ]);
  }

  static Future<void> _saveBool(String key, bool value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(key, value);
    } catch (_) {}
  }

  static Future<void> _saveDouble(String key, double value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setDouble(key, value);
    } catch (_) {}
  }
}
