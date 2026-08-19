import 'package:flutter_tts/flutter_tts.dart';

import 'package:flutter_application_1/core/utils/logger.dart';

/// Spoken turn-by-turn guidance (spec 2026-07-16 §4). Distance gates per
/// step: far (≤1000 m), near (≤300 m), now (≤60 m) — each spoken at most
/// once per step; a reroute resets the gates.
class NavVoice {
  static final _log = LoggerFactory.getLogger('NavVoice');

  final Future<void> Function(String text) _speak;
  bool muted = false;

  // Gate memory: stepIndex -> highest gate already announced
  // (0 none, 1 far, 2 near, 3 now).
  final _announced = <int, int>{};

  NavVoice({Future<void> Function(String text)? speak})
      : _speak = speak ?? _defaultSpeak;

  static FlutterTts? _tts;
  static Future<void> _defaultSpeak(String text) async {
    try {
      final tts = _tts ??= await _init();
      await tts.speak(text);
    } catch (e) {
      _log.w('TTS unavailable: $e'); // voice is best-effort, never fatal
    }
  }

  static Future<FlutterTts> _init() async {
    final tts = FlutterTts();
    try {
      await tts.setLanguage('en-ZA');
    } catch (_) {
      await tts.setLanguage('en-US');
    }
    await tts.setSpeechRate(0.5);
    return tts;
  }

  void onProgress({
    required int stepIndex,
    required double metersToManeuver,
    required String instruction,
  }) {
    if (muted) return;
    final gate = metersToManeuver <= 60
        ? 3
        : metersToManeuver <= 300
            ? 2
            : metersToManeuver <= 1000
                ? 1
                : 0;
    if (gate == 0) return;
    final already = _announced[stepIndex] ?? 0;
    if (gate <= already) return;
    _announced[stepIndex] = gate;
    final text = switch (gate) {
      1 => 'In 1 kilometer, ${_lc(instruction)}',
      2 => 'In 300 meters, ${_lc(instruction)}',
      _ => instruction,
    };
    _speak(text);
  }

  void announceRerouting() {
    if (!muted) _speak('Rerouting');
  }

  // Hazard proximity announcements (phase-5 T7). Spoken through the same
  // best-effort TTS pipeline as turn instructions, so interrupt/queue
  // behaviour is identical to turn coaching (a newer utterance replaces a
  // stale one — never a competing second voice).
  int? _lastHazardId;

  /// Announce an approaching hazard, e.g. "Caution: blasting zone ahead".
  /// De-dupe: the same hazard id is never announced twice in a row — the
  /// driver hears each hazard once while approaching it, but a different
  /// hazard in between re-arms the previous one.
  void announceHazard({required int hazardId, required String text}) {
    if (muted || hazardId == _lastHazardId) return;
    _lastHazardId = hazardId;
    _speak(text);
  }

  void announceArrived() {
    if (!muted) _speak('You have arrived at your destination');
  }

  /// New route fetched — re-arm all gates.
  void reset() => _announced.clear();

  static String _lc(String s) =>
      s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);
}
