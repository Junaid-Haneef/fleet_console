---
name: run-app
description: Run, build, or test the fleet_console Flutter app. Use when the user asks to run the app, launch it on a device, build a release, or verify a change works.
---

# Run fleet_console

This is a Flutter app (package name `fleet_console`).

## Before running

1. Fetch dependencies if `pubspec.yaml` changed or `.dart_tool/` is missing:
   ```
   flutter pub get
   ```
2. List available devices to pick a target:
   ```
   flutter devices
   ```

## Run the app

- Default (first available device):
  ```
  flutter run
  ```
- Windows desktop:
  ```
  flutter run -d windows
  ```
- Chrome (quickest for a visual check):
  ```
  flutter run -d chrome
  ```

`flutter run` is long-running — start it in the background and watch the output for the startup banner or errors.

## Verify a change

1. Run static analysis first: `flutter analyze`
2. Run tests: `flutter test`
3. Only then launch the app to confirm visually.

## Build a release

- Android: `flutter build apk --release` → artifact at `build/app/outputs/flutter-apk/app-release.apk`
- Windows: `flutter build windows --release` → artifact under `build/windows/x64/runner/Release/`

Report the artifact path after a successful build.
