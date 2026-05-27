import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  /// 卡片/容器背景色 (light: white, dark: surface)
  static Color card(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  /// 脚手架背景色
  static Color scaffoldBg(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  /// 主要文字颜色
  static Color text(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  /// 次要文字颜色
  static Color textSecondary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  /// 输入框填充色
  static Color inputFill(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHighest;

  /// 分割线/边框色
  static Color border(BuildContext context) =>
      Theme.of(context).colorScheme.outlineVariant;
}
