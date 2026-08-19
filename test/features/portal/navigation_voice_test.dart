import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/portal/services/navigation_voice.dart';

void main() {
  test('announces each gate once, in order, and never when muted', () {
    final spoken = <String>[];
    final v = NavVoice(speak: (t) async => spoken.add(t));

    // Approach: 1200 → 900 → 800 → 250 → 40 metres.
    for (final m in [1200.0, 900.0, 800.0, 250.0, 40.0]) {
      v.onProgress(
          stepIndex: 1, metersToManeuver: m, instruction: 'Turn left onto R59');
    }
    expect(spoken, [
      'In 1 kilometer, turn left onto R59',
      'In 300 meters, turn left onto R59',
      'Turn left onto R59',
    ]);

    spoken.clear();
    v.muted = true;
    v.onProgress(stepIndex: 2, metersToManeuver: 100, instruction: 'Turn right');
    expect(spoken, isEmpty);

    v.muted = false;
    v.reset();
    v.onProgress(
        stepIndex: 1, metersToManeuver: 900, instruction: 'Turn left onto R59');
    expect(spoken, ['In 1 kilometer, turn left onto R59']); // gates re-armed
  });

  test('rerouting/arrival announcements respect mute', () {
    final spoken = <String>[];
    final v = NavVoice(speak: (t) async => spoken.add(t));
    v.announceRerouting();
    v.announceArrived();
    expect(spoken, ['Rerouting', 'You have arrived at your destination']);
    spoken.clear();
    v.muted = true;
    v.announceRerouting();
    v.announceArrived();
    expect(spoken, isEmpty);
  });
}
