# Nexus

A Material Design 3 aggregation toolbox for **Android** and **Windows**. The current release establishes an adaptive, feature-empty application shell ready for future tools.

## Highlights

- Material Design 3 UI with responsive desktop and mobile navigation.
- Android 12+ dynamic colors with a stable Material 3 fallback palette.
- Automatic light/dark mode controlled by the operating system.
- Android application ID: `com.voxyn.nexus`.

## Development

This project is generated and maintained with Flutter **3.44.6**.

```powershell
flutter pub get
flutter analyze
flutter test
```

Run against an attached Android device/emulator or Windows desktop target:

```powershell
flutter run
```

## CI

GitHub Actions validates formatting-relevant static analysis and tests, builds a debug Android APK, and uploads it as the `nexus-debug-apk` workflow artifact. Trigger it with a push, pull request, or the **Run workflow** button in GitHub Actions.
