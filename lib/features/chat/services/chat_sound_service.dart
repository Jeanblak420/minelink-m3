import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter_application_1/core/utils/logger.dart';

final _log = LoggerFactory.getLogger('ChatSound');

/// Plays short chat notification tones. Tones are synthesised to WAV at runtime
/// (no bundled assets) and cached as temp files, then played via a
/// [DeviceFileSource] — which works on Windows desktop.
class ChatSoundService {
  ChatSoundService._();
  static final ChatSoundService instance = ChatSoundService._();

  final AudioPlayer _player = AudioPlayer();
  final Map<String, String> _files = {};

  /// Tone presets: each is a list of [frequencyHz, durationMs] segments.
  /// A frequency of 0 = a short silence (used for gaps between beeps).
  static const Map<String, List<List<num>>> _tones = {
    'pop': [
      [660, 95]
    ],
    'chime': [
      [880, 90],
      [1320, 130]
    ],
    'ding': [
      [1046, 280]
    ],
    'blip': [
      [440, 65]
    ],
    'soft': [
      [523, 80],
      [784, 110]
    ],
    'ping': [
      [1568, 70],
      [2093, 110]
    ],
    'bubble': [
      [400, 45],
      [620, 45],
      [900, 60]
    ],
    'knock': [
      [220, 55],
      [0, 40],
      [180, 65]
    ],
    'trill': [
      [1046, 55],
      [1318, 55],
      [1568, 80]
    ],
    'marimba': [
      [880, 60],
      [1174, 60],
      [1568, 95]
    ],
    'glass': [
      [1318, 55],
      [1760, 130]
    ],
    'alert': [
      [988, 90],
      [0, 55],
      [988, 110]
    ],
    'coin': [
      [1318, 55],
      [1976, 130]
    ],
    'drop': [
      [880, 45],
      [587, 60],
      [392, 90]
    ],
    'send': [
      [720, 55],
      [980, 60]
    ],
  };

  /// Selectable incoming tones (shown in settings).
  static const List<String> incomingTones = [
    'pop',
    'chime',
    'ding',
    'blip',
    'soft',
    'ping',
    'bubble',
    'knock',
    'trill',
    'marimba',
    'glass',
    'alert',
    'coin',
    'drop',
  ];
  static const Map<String, String> labels = {
    'pop': 'Pop',
    'chime': 'Chime',
    'ding': 'Ding',
    'blip': 'Blip',
    'soft': 'Soft',
    'ping': 'Ping',
    'bubble': 'Bubble',
    'knock': 'Knock',
    'trill': 'Trill',
    'marimba': 'Marimba',
    'glass': 'Glass',
    'alert': 'Alert',
    'coin': 'Coin',
    'drop': 'Drop',
  };

  // ── CPS tone set (ported from CPS's NotificationSoundPlayer) ──────────────
  // Same in-memory synthesis, exposed under `cps:<name>` ids so MineLink's own
  // tones above and CPS's full set both stay selectable.
  static const Map<String, String> cpsLabels = {
    'cps:default': 'Classic',
    'cps:chime': 'Chime',
    'cps:bell': 'Bell',
    'cps:ding': 'Ding',
    'cps:pop': 'Pop',
    'cps:swoosh': 'Swoosh',
    'cps:alert': 'Alert',
    'cps:gentle': 'Gentle',
    'cps:knock': 'Knock',
    'cps:marimba': 'Marimba',
    'cps:crystal': 'Crystal',
    'cps:bubble': 'Bubble',
    'cps:blip': 'Blip',
    'cps:coin': 'Coin',
    'cps:harp': 'Harp',
    'cps:droplet': 'Droplet',
    'cps:telegraph': 'Telegraph',
    'cps:pulse': 'Pulse',
    'cps:trill': 'Trill',
    'cps:whistle': 'Whistle',
    'cps:tada': 'Tada',
    'cps:soft': 'Soft',
  };
  static const List<String> cpsTones = [
    'cps:default', 'cps:chime', 'cps:bell', 'cps:ding', 'cps:pop', 'cps:swoosh',
    'cps:alert', 'cps:gentle', 'cps:knock', 'cps:marimba', 'cps:crystal',
    'cps:bubble', 'cps:blip', 'cps:coin', 'cps:harp', 'cps:droplet',
    'cps:telegraph', 'cps:pulse', 'cps:trill', 'cps:whistle', 'cps:tada',
    'cps:soft', // 22 tones
  ];

  /// Human label for any tone id (MineLink or CPS).
  static String labelFor(String id) =>
      labels[id] ?? cpsLabels[id] ?? (id == 'none' ? 'Silent' : id);

  Future<void> play(String id) async {
    if (id == 'none') return;
    if (!id.startsWith('cps:') && !_tones.containsKey(id)) return;
    try {
      final path = await _ensureFile(id);
      await _player.stop();
      await _player.play(DeviceFileSource(path), volume: 0.6);
    } catch (_) {
      // Sound is best-effort; never surface playback errors.
    }
  }

  /// Plays a user-provided audio file (e.g. a sound the user downloaded from
  /// Pixabay/Mixkit under their licenses and chose as a custom tone).
  Future<void> playFile(String path) async {
    if (path.isEmpty) return;
    try {
      await _player.stop();
      await _player.play(DeviceFileSource(path), volume: 0.7);
    } catch (e) {
      _log.d('custom sound playback failed (best effort): $e');
    }
  }

  /// Dispatches to a built-in tone or the user's custom file.
  Future<void> playSelection(String id, String? customPath) async {
    if (id == 'custom') {
      if (customPath != null && customPath.isNotEmpty) await playFile(customPath);
    } else {
      await play(id);
    }
  }

  Future<String> _ensureFile(String id) async {
    final cached = _files[id];
    if (cached != null) return cached;
    final bytes = id.startsWith('cps:')
        ? _encodeSamples(_cpsSamples(id.substring(4)))
        : _buildWav(_tones[id]!);
    final dir = await getTemporaryDirectory();
    final safe = id.replaceAll(':', '_');
    final file = File('${dir.path}/ml_chat_$safe.wav');
    await file.writeAsBytes(bytes, flush: true);
    _files[id] = file.path;
    return file.path;
  }

  // ── CPS synthesis (ported verbatim from NotificationSoundPlayer) ──────────
  static const int _sr = 44100;

  List<double> _cpsSamples(String name) {
    switch (name) {
      case 'chime':
        return _cpsToneSeq([523.25, 659.25, 783.99], 140, 0.45);
      case 'bell':
        return _cpsDecayTone(880.0, 500, 0.5);
      case 'ding':
        return _cpsSimpleTone(1046.50, 150, 0.5);
      case 'pop':
        return _cpsChirp(400, 200, 100, 0.5);
      case 'swoosh':
        return _cpsChirp(200, 800, 300, 0.35);
      case 'alert':
        return _cpsAlt(600, 800, 3, 100, 0.5);
      case 'gentle':
        return _cpsDecayTone(329.63, 450, 0.35);
      case 'knock':
        return _cpsDecaySeq([180.0, 180.0], 110, 7.0, 70, 0.5);
      case 'marimba':
        return _cpsDecaySeq([523.25, 659.25, 783.99], 130, 5.0, 10, 0.45);
      case 'crystal':
        return _cpsDecaySeq([1318.51, 1567.98, 2093.0], 240, 6.0, 0, 0.32);
      case 'bubble':
        return _cpsChirp(280, 900, 130, 0.45);
      case 'blip':
        return _cpsSimpleTone(880.0, 70, 0.5);
      case 'coin':
        return _cpsDecaySeq([987.77, 1318.51], 95, 4.0, 0, 0.42);
      case 'harp':
        return _cpsDecaySeq(
            [392.0, 523.25, 659.25, 783.99, 1046.5], 95, 5.0, 0, 0.34);
      case 'droplet':
        return _cpsChirp(1300, 480, 170, 0.4);
      case 'telegraph':
        return _cpsDecaySeq([820.0, 820.0, 820.0], 70, 8.0, 55, 0.45);
      case 'pulse':
        return _cpsDecaySeq([440.0, 440.0], 170, 3.0, 120, 0.4);
      case 'trill':
        return _cpsAlt(1046.5, 1318.51, 6, 45, 0.4);
      case 'whistle':
        return _cpsChirp(600, 1500, 240, 0.4);
      case 'tada':
        return _cpsDecaySeq([659.25, 987.77], 240, 2.5, 10, 0.45);
      case 'soft':
        return _cpsDecayTone(261.63, 380, 0.3);
      case 'default':
      default:
        return _cpsToneSeq([440.0, 554.37], 180, 0.45);
    }
  }

  List<double> _cpsSimpleTone(double freq, int ms, double vol) {
    final n = (_sr * ms / 1000).round();
    return List<double>.generate(n, (i) {
      final t = i / _sr;
      return math.sin(2 * math.pi * freq * t) * vol * (1.0 - i / n);
    });
  }

  List<double> _cpsDecayTone(double freq, int ms, double vol) {
    final n = (_sr * ms / 1000).round();
    return List<double>.generate(n, (i) {
      final t = i / _sr;
      return math.sin(2 * math.pi * freq * t) * vol * math.exp(-4.0 * i / n);
    });
  }

  List<double> _cpsToneSeq(List<double> freqs, int eachMs, double vol) {
    final out = <double>[];
    for (final freq in freqs) {
      final n = (_sr * eachMs / 1000).round();
      for (var i = 0; i < n; i++) {
        final t = i / _sr;
        out.add(math.sin(2 * math.pi * freq * t) * vol * (1.0 - i / n));
      }
    }
    return out;
  }

  List<double> _cpsDecaySeq(
      List<double> freqs, int eachMs, double decay, int gapMs, double vol) {
    final out = <double>[];
    for (final freq in freqs) {
      final n = (_sr * eachMs / 1000).round();
      for (var i = 0; i < n; i++) {
        final t = i / _sr;
        out.add(math.sin(2 * math.pi * freq * t) * vol * math.exp(-decay * i / n));
      }
      final g = (_sr * gapMs / 1000).round();
      for (var i = 0; i < g; i++) {
        out.add(0);
      }
    }
    return out;
  }

  List<double> _cpsChirp(double startHz, double endHz, int ms, double vol) {
    final n = (_sr * ms / 1000).round();
    return List<double>.generate(n, (i) {
      final progress = i / n;
      final freq = startHz + (endHz - startHz) * progress;
      final t = i / _sr;
      return math.sin(2 * math.pi * freq * t) * vol * (1.0 - progress);
    });
  }

  List<double> _cpsAlt(
      double freqA, double freqB, int cycles, int eachMs, double vol) {
    final out = <double>[];
    for (var c = 0; c < cycles; c++) {
      final freq = c.isEven ? freqA : freqB;
      final n = (_sr * eachMs / 1000).round();
      for (var i = 0; i < n; i++) {
        final t = i / _sr;
        out.add(math.sin(2 * math.pi * freq * t) * vol * (1.0 - (i / n) * 0.3));
      }
    }
    return out;
  }

  Uint8List _encodeSamples(List<double> samples) {
    final dataLen = samples.length * 2;
    final out = BytesBuilder();
    void str(String s) => out.add(s.codeUnits);
    void u32(int v) =>
        out.add([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);
    void u16(int v) => out.add([v & 0xFF, (v >> 8) & 0xFF]);
    str('RIFF');
    u32(36 + dataLen);
    str('WAVE');
    str('fmt ');
    u32(16);
    u16(1);
    u16(1);
    u32(_sr);
    u32(_sr * 2);
    u16(2);
    u16(16);
    str('data');
    u32(dataLen);
    final pcm = ByteData(dataLen);
    for (var i = 0; i < samples.length; i++) {
      pcm.setInt16(
          i * 2, (samples[i] * 32767).round().clamp(-32768, 32767), Endian.little);
    }
    out.add(pcm.buffer.asUint8List());
    return out.toBytes();
  }

  Uint8List _buildWav(List<List<num>> segments) {
    const sampleRate = 44100;
    final samples = <int>[];
    for (final seg in segments) {
      final freq = seg[0].toDouble();
      final ms = seg[1].toInt();
      final n = (sampleRate * ms / 1000).round();
      for (var i = 0; i < n; i++) {
        final t = i / sampleRate;
        final p = n == 0 ? 0.0 : i / n;
        // Quick fade in/out to avoid clicks.
        final env = (p < 0.1
                ? p / 0.1
                : (p > 0.82 ? (1 - p) / 0.18 : 1.0))
            .clamp(0.0, 1.0);
        final v = math.sin(2 * math.pi * freq * t) * env * 0.5;
        samples.add((v * 32767).round().clamp(-32768, 32767));
      }
    }

    final dataLen = samples.length * 2;
    final out = BytesBuilder();
    void str(String s) => out.add(s.codeUnits);
    void u32(int v) =>
        out.add([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);
    void u16(int v) => out.add([v & 0xFF, (v >> 8) & 0xFF]);

    str('RIFF');
    u32(36 + dataLen);
    str('WAVE');
    str('fmt ');
    u32(16); // PCM chunk size
    u16(1); // audio format = PCM
    u16(1); // channels = mono
    u32(sampleRate);
    u32(sampleRate * 2); // byte rate
    u16(2); // block align
    u16(16); // bits per sample
    str('data');
    u32(dataLen);

    final pcm = ByteData(dataLen);
    for (var i = 0; i < samples.length; i++) {
      pcm.setInt16(i * 2, samples[i], Endian.little);
    }
    out.add(pcm.buffer.asUint8List());
    return out.toBytes();
  }
}
