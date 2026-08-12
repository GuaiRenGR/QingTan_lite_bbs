<p align="center">
  <img src="hjyz_bbs/icon.png" width="128" height="128" alt="QingTan app icon">
</p>

<h1 align="center">QingTan · 轻坛</h1>

<p align="center">A lightweight, modern, cross-platform community forum with Flutter clients and a PHP backend.</p>

<p align="center">
    <a href="README.md">简体中文</a>
    ·
    <a href="PRD.md">Product Spec</a>
    ·
    <a href="changes.md">Changelog</a>
  </p>

<p align="center">
    <img src="https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20HarmonyOS%20%7C%20Android%20%7C%20iOS%20%7C%20Web-2ea44f" alt="Supported platforms">
    <img src="https://img.shields.io/badge/Flutter-stable-02569B?logo=flutter&logoColor=white" alt="Flutter stable">
    <img src="https://img.shields.io/badge/Dart-%5E3.11.1-0175C2?logo=dart&logoColor=white" alt="Dart 3.11.1 or later">
    <img src="https://img.shields.io/badge/PHP-7.4%2B-777BB4?logo=php&logoColor=white" alt="PHP 7.4 or later">
  </p>
<p align="center">
    <img src="https://img.shields.io/badge/Version-1.2.4%2B30-00A98F" alt="Version 1.2.4+30">
    <a href="https://github.com/GuaiRenGR/QingTan_lite_bbs/actions/workflows/main.yml"><img src="https://github.com/GuaiRenGR/QingTan_lite_bbs/actions/workflows/main.yml/badge.svg" alt="Build status"></a>
    <a href="https://github.com/GuaiRenGR/QingTan_lite_bbs/releases"><img src="https://img.shields.io/github/v/release/GuaiRenGR/QingTan_lite_bbs?display_name=tag&sort=semver" alt="Latest release"></a>
    <a href="https://github.com/GuaiRenGR/QingTan_lite_bbs/stargazers"><img src="https://img.shields.io/github/stars/GuaiRenGR/QingTan_lite_bbs?style=flat" alt="GitHub Stars"></a>
  </p>

## ✨ Overview

QingTan is a complete community forum solution. Its primary Flutter app delivers a consistent experience across mobile, desktop, and the web, while the PHP API handles users, posts, interactions, media, and administration. The repository also includes a native Android client and the standalone QingTan Music app.

> [!NOTE]
> The primary client supports Windows, macOS, Linux, HarmonyOS, Android, iOS, and the web. The current GitHub Actions workflows do not build or publish HarmonyOS artifacts yet.

## 🚀 Features

- 📝 Image, article, and Markdown posts with BBCode and reply-to-view content
- 💬 Comments, likes, bookmarks, follows, sharing, reports, and direct messages
- 🎬 Video playback, multi-threaded downloads, and `hyjzbbs://` deep links
- 🎵 Global music playback, dynamic colors, synchronized lyrics, and playlists
- 🧭 Recommendations, trending and featured feeds, boards, tags, and search
- 🏅 Daily check-ins, badges, verification marks, and creator analytics
- 🎨 Six persistent color themes with a Material 3 interface
- 🛡️ Device management, login history, user permissions, and post moderation

## 🧩 Repository Layout

| Path | Purpose | Stack |
| --- | --- | --- |
| [`hjyz_bbs/`](hjyz_bbs/) | Primary QingTan client | Flutter · Riverpod · GoRouter · Dio · MediaKit |
| [`qingtan_kotlin/`](qingtan_kotlin/) | Native QingTan Android client | Kotlin · Jetpack Compose · Material 3 |
| [`qingtan_music/`](qingtan_music/) | Standalone Android music client | Flutter · Riverpod · Just Audio |
| [`server/`](server/) | Forum API, installer, and upgrades | PHP 7.4+ · PDO MySQL · OneDrive |

```text
QingTan_lite_bbs/
├── hjyz_bbs/          # Cross-platform forum client
├── qingtan_kotlin/    # Native Android forum client
├── qingtan_music/     # Standalone music client
├── server/            # PHP API backend
├── PRD.md             # Product requirements
└── changes.md         # Release changelog
```

## 🛠️ Getting Started

### Requirements

- Flutter stable with Dart SDK `^3.11.1`
- PHP 7.4+ with PDO MySQL enabled
- A MySQL database
- JDK 17 for Android builds

### Run the primary Flutter client

```bash
cd hjyz_bbs
flutter pub get
flutter run
```

Run the project checks:

```bash
flutter analyze
dart format --output=none --set-exit-if-changed lib test
flutter test
```

### Deploy the backend

1. Configure the database connection under `server/config/`.
2. Copy `server/config/onedrive.local.example.php` to `server/config/onedrive.local.php` and add your OneDrive configuration, or use the documented `ONEDRIVE_*` environment variables.
3. Run or open `server/install.php` in a trusted environment to initialize the database.
4. Deploy `server/` to a web server with PHP 7.4+ and PDO MySQL.

Before upgrading an existing deployment, read [`changes.md`](changes.md) and run the matching `server/upgrade_version_*.php` script for the target version. Remove the upgrade script from the server immediately after it succeeds.

## 📦 Build and Release

```bash
cd hjyz_bbs
flutter build apk --release
flutter build windows --release
flutter build linux --release
flutter build macos --release
flutter build ios --release --no-codesign
flutter build web --release
```

On `v*` tags, GitHub Actions builds Android, Windows, Linux, macOS, and unsigned iOS artifacts and uploads them to GitHub Releases. Each target still requires its corresponding host operating system and toolchain for local builds.

## 🔐 Configuration and Security

- Never commit database passwords, OneDrive credentials, signing keys, or token caches.
- `server/config/onedrive.local.php` and `server/cache/onedrive_token.json` are ignored by Git.
- Restrict access to installer and upgrade scripts in production, then remove them after use.

## 📈 Star History

<div align="center">
  <a href="https://star-history.com/#GuaiRenGR/QingTan_lite_bbs&Date">
    <img src="https://api.star-history.com/svg?repos=GuaiRenGR/QingTan_lite_bbs&type=Date" alt="QingTan Star History chart">
  </a>
</div>

## 🤝 Contributing

Bug reports and ideas are welcome in [Issues](https://github.com/GuaiRenGR/QingTan_lite_bbs/issues). Before submitting code, run formatting, static analysis, and tests for each affected project, and keep every commit focused on one logical change.

## 📄 Third-Party Notices

The music player's dynamic background is based on NeriPlayer's HyperBackground implementation. See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) and [`LICENSES/`](LICENSES/) for source and license details.

<div align="center">
  <sub>Built with Flutter and PHP · Thanks for every ⭐</sub>
</div>
