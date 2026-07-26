# 第三方来源说明

## NeriPlayer

音乐播放器动态背景
`hjyz_bbs/lib/features/music/dynamic_music_background.dart` 参考并翻译改写自
NeriPlayer 的 `HyperBackground.kt`、`BgEffectPainter.java` 和
`hyper_background_effect.glsl`。

- 项目：https://github.com/cwuom/NeriPlayer
- 原作者：NeriPlayer developers
- 原始版权：Copyright (C) 2025 NeriPlayer developers
- 许可证：GNU General Public License v3.0 or later
- 修改说明：2026 年将 Android RuntimeShader、Palette 与音频响应流程翻译为
  Flutter CustomPainter、跨平台封面量化器及播放位置驱动的节拍包络。

该翻译改写组件遵循 GNU GPL v3.0 or later。许可证全文见
`LICENSES/NeriPlayer-GPL-3.0.txt`，亦可访问：
https://www.gnu.org/licenses/gpl-3.0.html
