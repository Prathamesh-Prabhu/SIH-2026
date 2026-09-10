# Meditation / sleep / music audio

Out of the box the meditation player **streams** looping ambience from Google's
free Sound Library (https://developers.google.com/assistant/tools/sound-library)
— no files are needed here and nothing has to be bundled.

## Using your own tracks (optional)

Drop audio files in this folder (`assets/audio/`), then point a session at one
in `lib/data/mindfulness_content.dart`:

```dart
MeditationSession(
  title: 'Daily Calm',
  ...
  assetPath: 'audio/daily_calm.mp3',   // <-- file here: assets/audio/daily_calm.mp3
  audioUrl: _Snd.forestSpring,          // kept as a fallback; assetPath wins
),
```

Notes
- `assetPath` is relative to `assets/` (audioplayers prepends it), so
  `assets/audio/daily_calm.mp3` → `assetPath: 'audio/daily_calm.mp3'`.
- Formats: `.mp3`, `.m4a`/`.aac`, `.ogg`, `.wav` all play on Android.
- Long ambience loops seamlessly for the whole session; guided/narrated tracks
  just play once.
- Keep files reasonably small (a 3–10 min loop is plenty); they ship inside the
  APK.
- Only use audio you have the rights to distribute.
