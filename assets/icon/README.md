# App icon

Put the launcher icon here as **`manofit_icon.png`** — square, at least
**1024×1024**, PNG.

Then from `SIH-2026/`:

```
flutter pub run flutter_launcher_icons
```

(or `deploy\apply-icon-and-build.ps1` to also build the release APK).

Config lives in `pubspec.yaml` under `flutter_launcher_icons:` — legacy icon +
Android adaptive icon (cream `#F4F1E8` background). If the "ManoFit" wordmark
near the bottom edge gets clipped by the Android-8+ circular mask, drop a
second, padded version as `manofit_icon_foreground.png` and point
`adaptive_icon_foreground` at it.
