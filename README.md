<p align="center">
  <img src="hjyz_bbs/icon.png" width="128" height="128" alt="轻坛应用图标">
</p>

<h1 align="center">轻坛 · QingTan</h1>

<p align="center">轻量、现代、跨平台的社区论坛，包含 Flutter 客户端、原生 Android 客户端与 PHP 服务端。</p>

<p align="center">
    <a href="README_en.md">English</a>
    ·
    <a href="PRD.md">产品文档</a>
    ·
    <a href="changes.md">更新日志</a>
  </p>

<p align="center">
    <img src="https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20HarmonyOS%20%7C%20Android%20%7C%20iOS%20%7C%20Web-2ea44f" alt="支持平台">
    <img src="https://img.shields.io/badge/Flutter-stable-02569B?logo=flutter&logoColor=white" alt="Flutter stable">
    <img src="https://img.shields.io/badge/Dart-%5E3.11.1-0175C2?logo=dart&logoColor=white" alt="Dart 3.11.1 或更高版本">
    <img src="https://img.shields.io/badge/PHP-7.4%2B-777BB4?logo=php&logoColor=white" alt="PHP 7.4 或更高版本">
  </p>
<p align="center">
    <img src="https://img.shields.io/badge/Version-1.2.5%2B31-00A98F" alt="版本 1.2.5+31">
    <a href="https://github.com/GuaiRenGR/QingTan_lite_bbs/actions/workflows/main.yml"><img src="https://github.com/GuaiRenGR/QingTan_lite_bbs/actions/workflows/main.yml/badge.svg" alt="构建状态"></a>
    <a href="https://github.com/GuaiRenGR/QingTan_lite_bbs/releases"><img src="https://img.shields.io/github/v/release/GuaiRenGR/QingTan_lite_bbs?display_name=tag&sort=semver" alt="最新版本"></a>
    <a href="https://github.com/GuaiRenGR/QingTan_lite_bbs/stargazers"><img src="https://img.shields.io/github/stars/GuaiRenGR/QingTan_lite_bbs?style=flat" alt="GitHub Stars"></a>
  </p>

## ✨ 项目简介

轻坛是一套完整的社区论坛解决方案。主客户端使用 Flutter 构建，在移动端、桌面端和 Web 上提供一致体验；PHP API 负责用户、帖子、互动、媒体与管理能力。仓库还包含原生 Android 客户端和独立的轻听音乐应用。

> [!NOTE]
> 主客户端支持 Windows、macOS、Linux、HarmonyOS、Android、iOS 与 Web。当前 GitHub Actions 尚未编译和发布 HarmonyOS 产物。

## 🚀 核心功能

- 📝 图文、文章和 Markdown 发帖，支持 BBCode 与回复可见内容
- 💬 评论、点赞、收藏、关注、分享、举报与私信
- 🎬 视频播放、多线程下载和 `hyjzbbs://` 深度链接
- 🎵 全局音乐播放、动态取色、歌词同步与歌单管理
- 🧭 推荐、热门、精华、版块、标签和全文搜索
- 🏅 每日签到、铭牌、认证标识与创作者数据统计
- 🎨 六种可持久化主题色与 Material 3 界面
- 🛡️ 设备管理、登录记录、用户权限和帖子管理

## 🧩 仓库组成

| 目录 | 说明 | 技术 |
| --- | --- | --- |
| [`hjyz_bbs/`](hjyz_bbs/) | 轻坛主客户端 | Flutter · Riverpod · GoRouter · Dio · MediaKit |
| [`qingtan_kotlin/`](qingtan_kotlin/) | 轻坛原生 Android 客户端 | Kotlin · Jetpack Compose · Material 3 |
| [`qingtan_music/`](qingtan_music/) | 独立 Android 音乐客户端 | Flutter · Riverpod · Just Audio |
| [`server/`](server/) | 论坛 API 与安装/升级工具 | PHP 7.4+ · PDO MySQL · OneDrive |

```text
QingTan_lite_bbs/
├── hjyz_bbs/          # 跨平台论坛客户端
├── qingtan_kotlin/    # 原生 Android 论坛客户端
├── qingtan_music/     # 独立音乐客户端
├── server/            # PHP API 服务端
├── PRD.md             # 产品需求文档
└── changes.md         # 版本更新日志
```

## 🛠️ 快速开始

### 环境要求

- Flutter stable，Dart SDK `^3.11.1`
- PHP 7.4+，并启用 PDO MySQL
- MySQL 数据库
- 构建 Android 时需要 JDK 17

### 运行 Flutter 主客户端

```bash
cd hjyz_bbs
flutter pub get
flutter run
```

执行质量检查：

```bash
flutter analyze
dart format --output=none --set-exit-if-changed lib test
flutter test
```

### 部署服务端

1. 配置 `server/config/` 中的数据库连接。
2. 将 `server/config/onedrive.local.example.php` 复制为 `server/config/onedrive.local.php`，填写 OneDrive 配置；也可以使用文档中对应的 `ONEDRIVE_*` 环境变量。
3. 在受信任的环境中访问或运行 `server/install.php`，完成数据库初始化。
4. 将 `server/` 部署到支持 PHP 7.4+ 和 PDO MySQL 的 Web 服务器。

升级已有站点前，请阅读 [`changes.md`](changes.md) 并按目标版本执行对应的 `server/upgrade_version_*.php`。升级成功后应立即删除服务器上的升级脚本。

## 📦 构建与发布

```bash
cd hjyz_bbs
flutter build apk --release
flutter build windows --release
flutter build linux --release
flutter build macos --release
flutter build ios --release --no-codesign
flutter build web --release
```

仓库的 GitHub Actions 会在 `v*` 标签推送时构建 Android、Windows、Linux、macOS 与未签名 iOS 产物，并上传到 GitHub Releases。各平台仍需在对应操作系统和工具链中构建。

## 🔐 配置与安全

- 不要提交数据库密码、OneDrive 凭据、签名密钥或令牌缓存。
- `server/config/onedrive.local.php` 与 `server/cache/onedrive_token.json` 已被 Git 忽略。
- 生产环境部署前，请限制安装与升级脚本的访问权限，并在使用后删除它们。

## 📈 Star 趋势

<div align="center">
  <a href="https://www.star-history.com/?type=date&repos=GuaiRenGR%2FQingTan_lite_bbs">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=GuaiRenGR/QingTan_lite_bbs&type=date&theme=dark&legend=top-left&sealed_token=87PhZgk-GAy0ZdBCbIMOYvZw7PIuAiIfAyqqj-K8-jJXXAHCp5FWpnasttnqnhBNmyV8MzPf0zXKupWcFB842FzBNgQBedZlKSZZEdmsNGFR8sG6cD3E8uu6yr6rLctKSrjepiVKTI7THmHERgL6kSoJqVlhtXwTYhURQhFojj5f3H9f7nw1BIhN7_Ow">
      <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=GuaiRenGR/QingTan_lite_bbs&type=date&legend=top-left&sealed_token=87PhZgk-GAy0ZdBCbIMOYvZw7PIuAiIfAyqqj-K8-jJXXAHCp5FWpnasttnqnhBNmyV8MzPf0zXKupWcFB842FzBNgQBedZlKSZZEdmsNGFR8sG6cD3E8uu6yr6rLctKSrjepiVKTI7THmHERgL6kSoJqVlhtXwTYhURQhFojj5f3H9f7nw1BIhN7_Ow">
      <img alt="轻坛 Star History 趋势图" src="https://api.star-history.com/chart?repos=GuaiRenGR/QingTan_lite_bbs&type=date&legend=top-left&sealed_token=87PhZgk-GAy0ZdBCbIMOYvZw7PIuAiIfAyqqj-K8-jJXXAHCp5FWpnasttnqnhBNmyV8MzPf0zXKupWcFB842FzBNgQBedZlKSZZEdmsNGFR8sG6cD3E8uu6yr6rLctKSrjepiVKTI7THmHERgL6kSoJqVlhtXwTYhURQhFojj5f3H9f7nw1BIhN7_Ow">
    </picture>
  </a>
</div>

## 🤝 参与贡献

欢迎通过 [Issues](https://github.com/GuaiRenGR/QingTan_lite_bbs/issues) 反馈问题或提出建议。提交代码前，请运行受影响项目的格式化、静态分析和测试，并让一次提交只包含一个明确的逻辑变更。

## 📄 第三方声明

音乐播放器的动态背景参考 NeriPlayer 的 HyperBackground 实现。相关来源与许可证信息见 [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) 和 [`LICENSES/`](LICENSES/)。

<div align="center">
  <sub>用 Flutter 与 PHP 构建 · 感谢每一颗 ⭐</sub>
</div>
