# Repository Guidelines

## Project Structure & Module Organization

This repository contains two Flutter apps and one PHP backend:

- `hjyz_bbs/` is the main forum client. Code lives in `lib/`, shared infrastructure in `lib/core/`, features in `lib/features/`, tests in `test/`, and media in `assets/` and `shaders/`.
- `qingtan_music/` is the standalone Android music client. Its `lib/` tree uses `controllers/`, `models/`, `screens/`, `services/`, `utils/`, and `widgets/`; tests are under `test/`.
- `server/` is the PHP 7.4+ API. Route handling starts in `index.php`, controllers live in `app/Controllers/`, framework helpers in `core/`, and deployment settings in `config/`.
- `.github/workflows/` contains release builds. See `PRD.md`, `README.md`, and `changes.md` for product and release context.

## Build, Test, and Development Commands

Run Flutter commands from the app being changed:

```sh
cd hjyz_bbs                 # or: cd qingtan_music
flutter pub get             # install locked dependencies
flutter run                 # launch on a connected target
flutter analyze             # apply flutter_lints checks
dart format --output=none --set-exit-if-changed lib test
flutter test                # run that app's test suite
flutter build apk --release # create a release Android APK
```

The main client also supports `flutter build windows --release`; CI builds other desktop and Apple targets. Syntax-check backend edits with `php -l server/path/to/file.php`. The backend requires PHP 7.4+, PDO MySQL, and a configured database.

## Coding Style & Naming Conventions

Use Dart's two-space formatting and `package:flutter_lints/flutter.yaml`. Name files `snake_case.dart`, types `UpperCamelCase`, and members `lowerCamelCase`. Keep main-client features in their existing folder and reusable code in `lib/core/`. PHP uses four-space indentation, `UpperCamelCase` classes, and `camelCase` methods; follow nearby controller and response patterns.

## Testing Guidelines

Tests use `flutter_test` and the `*_test.dart` convention. Add focused tests to the affected app; use `testWidgets` for rendered behavior. Run `flutter analyze` and `flutter test` in every modified Flutter package. There is no coverage threshold or PHP test suite, so manually exercise affected API routes and run `php -l`.

## Commit & Pull Request Guidelines

History follows Conventional Commit-style subjects such as `feat:`, `fix:`, and `perf:`. Keep subjects imperative and limited to one logical change. Pull requests should summarize behavior, identify affected components, list verification, link issues, and include screenshots or recordings for UI changes. Note migrations, configuration changes, and platform impact.

## Security & Configuration

Never commit credentials. Copy `server/config/onedrive.local.example.php` to the ignored `onedrive.local.php`, or use the documented `ONEDRIVE_*` environment variables. Keep token caches, signing keys, build output, and local configuration out of version control.
