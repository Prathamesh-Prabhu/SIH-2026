import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Procedurally-generated calming soundscapes, synthesised on-device (no assets,
/// no network). Ported from mindspace's Web-Audio `AmbientSoundPlayer.tsx`.
class AmbientSoundPlayer extends StatefulWidget {
  const AmbientSoundPlayer({super.key, this.onPlay});
  final void Function(String soundId)? onPlay;

  @override
  State<AmbientSoundPlayer> createState() => _AmbientSoundPlayerState();
}

class _Sound {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  const _Sound(this.id, this.title, this.subtitle, this.icon);
}

const _sounds = <_Sound>[
  _Sound('rain', 'Gentle Rain', 'Steady acoustic pink noise for focus',
      Icons.grain),
  _Sound('ocean', 'Ocean Tides', 'Rhythmic oceanic surge for deep relaxation',
      Icons.waves),
  _Sound('binaural', '432 Hz Alpha Tone',
      'Harmonic frequency for nervous system calm', Icons.auto_awesome),
  _Sound('forest', 'Forest Breeze', 'Low rustling wind for grounding',
      Icons.air),
];

class _AmbientSoundPlayerState extends State<AmbientSoundPlayer> {
  final AudioPlayer _player = AudioPlayer();
  final Map<String, Uint8List> _cache = {};
  String? _active;
  bool _playing = false;
  double _volume = 0.5;

  @override
  void initState() {
    super.initState();
    _player.setReleaseMode(ReleaseMode.loop);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle(_Sound s) async {
    if (_active == s.id && _playing) {
      await _player.stop();
      setState(() => _playing = false);
      return;
    }
    final bytes = _cache.putIfAbsent(s.id, () => _synthWav(s.id));
    await _player.stop();
    await _player.setVolume(_volume);
    await _player.play(BytesSource(bytes, mimeType: 'audio/wav'));
    if (!mounted) return;
    setState(() {
      _active = s.id;
      _playing = true;
    });
    widget.onPlay?.call(s.id);
  }

  Future<void> _stop() async {
    await _player.stop();
    if (mounted) setState(() => _playing = false);
  }

  // ── Synthesis ────────────────────────────────────────────────────────────
  static const int _sampleRate = 22050;
  static const double _loopSeconds = 4.0;

  Uint8List _synthWav(String type) {
    final n = (_sampleRate * _loopSeconds).round();
    final samples = Float64List(n);
    final rng = Random(7);

    if (type == 'binaural') {
      // 432 Hz + 440 Hz — both complete whole cycles over a 4.0s loop.
      for (var i = 0; i < n; i++) {
        final t = i / _sampleRate;
        samples[i] = 0.28 *
            (sin(2 * pi * 432 * t) + sin(2 * pi * 440 * t)) /
            2;
      }
    } else {
      // One-pole low-passed noise, coloured per soundscape.
      var last = 0.0;
      final cutoff = switch (type) {
        'rain' => 0.10,
        'forest' => 0.06,
        _ => 0.045, // ocean
      };
      for (var i = 0; i < n; i++) {
        final white = rng.nextDouble() * 2 - 1;
        last = last + cutoff * (white - last);
        samples[i] = last * 3.2;
      }
      if (type == 'ocean') {
        // Exactly one raised-cosine swell per loop → seamless surge.
        for (var i = 0; i < n; i++) {
          final env = 0.35 + 0.65 * (0.5 - 0.5 * cos(2 * pi * i / n));
          samples[i] *= env;
        }
      }
    }

    // Short crossfade across the loop seam to kill the click.
    final fade = (_sampleRate * 0.04).round();
    for (var i = 0; i < fade; i++) {
      final k = i / fade;
      samples[i] = samples[i] * k + samples[n - fade + i] * (1 - k);
    }

    // Normalise to a comfortable peak.
    var peak = 0.0;
    for (final s in samples) {
      peak = max(peak, s.abs());
    }
    final gain = peak > 0 ? 0.6 / peak : 1.0;

    return _encodeWav16(samples, gain);
  }

  Uint8List _encodeWav16(Float64List samples, double gain) {
    final n = samples.length;
    final data = ByteData(44 + n * 2);
    void writeStr(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        data.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    final byteRate = _sampleRate * 2;
    writeStr(0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little); // PCM
    data.setUint16(22, 1, Endian.little); // mono
    data.setUint32(24, _sampleRate, Endian.little);
    data.setUint32(28, byteRate, Endian.little);
    data.setUint16(32, 2, Endian.little); // block align
    data.setUint16(34, 16, Endian.little); // bits per sample
    writeStr(36, 'data');
    data.setUint32(40, n * 2, Endian.little);

    for (var i = 0; i < n; i++) {
      final v = (samples[i] * gain).clamp(-1.0, 1.0);
      data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F0EA),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.volume_up,
                        size: 16, color: AppColors.secondary),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Ambient Calming Soundscapes',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ),
                  if (_playing)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F0EA),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Playing Live',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondary)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Procedurally generated soothing sound waves synthesised on your device. Use with headphones while doodling or breathing to mute background noise.',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                    height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final s in _sounds) ...[
          _soundTile(s),
          const SizedBox(height: 8),
        ],
        if (_playing) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Row(
              children: [
                const Icon(Icons.volume_up, size: 16, color: AppColors.secondary),
                Expanded(
                  child: Slider(
                    value: _volume,
                    onChanged: (v) {
                      setState(() => _volume = v);
                      _player.setVolume(v);
                    },
                  ),
                ),
                TextButton(
                  onPressed: _stop,
                  child: const Text('Stop',
                      style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _soundTile(_Sound s) {
    final selected = _active == s.id && _playing;
    return InkWell(
      onTap: () => _toggle(s),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFAF7F2) : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.hairline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primaryContainer
                    : const Color(0xFFFAF7F2),
                borderRadius: BorderRadius.circular(12),
                border: selected
                    ? null
                    : Border.all(color: AppColors.hairline),
              ),
              child: Icon(s.icon,
                  size: 20,
                  color: selected ? Colors.white : AppColors.secondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                  Text(s.subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(selected ? Icons.pause_circle_filled : Icons.play_circle_fill,
                color: AppColors.secondary, size: 30),
          ],
        ),
      ),
    );
  }
}
