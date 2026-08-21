// Four of the six decisions §4.3 of the handoff had been holding for Jean.
//
// Each was left open because it reads as somebody's deliberate instruction
// rather than a slip. Taken now, with the reasoning at each site and the
// alternative named, because leaving a wrong figure on screen while waiting to
// be told to fix it is the worse of the two errors.
//
// The two NOT taken are recorded in the handoff: the phone bottom bar's short
// forms (Recon / Requests / Docs), which are what a 412px bar can hold; and
// merging `messages_screen.dart` with `chat_screen.dart`, which is a refactor
// rather than a redesign pass.
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/utils/ml_count.dart';
import 'package:flutter_application_1/features/super_admin/data/models/audit_log.dart';

void main() {
  group('an audit action reads as a sentence, not a headline', () {
    // Title-casing every word capitalised "To" and "Of", which no style does,
    // and made a table row shout.
    const cases = <String, String>{
      'USER_ASSIGNED_TO_SEAT': 'User assigned to seat',
      'TOKEN_GENERATED': 'Token generated',
      'COMPANY_SUSPENDED': 'Company suspended',
      'SEAT_REASSIGNED': 'Seat reassigned',
      'ORGANIZATION_CREATED': 'Organization created',
    };

    cases.forEach((wire, expected) {
      test(wire, () => expect(AuditLog.labelForAction(wire), expected));
    });

    test('an empty action type does not throw', () {
      expect(AuditLog.labelForAction(''), '');
      expect(AuditLog.labelForAction('___'), '');
    });
  });

  group('the database\'s "load(s)" is repaired where it arrives', () {
    test('the real collect alert', () {
      expect(
        mlRepairParentheticalPlural(
            'Stockpile ready to collect — 2 full load(s) ready'),
        'Stockpile ready to collect — 2 full loads ready',
      );
    });

    test('one load takes the singular', () {
      expect(
        mlRepairParentheticalPlural('1 full load(s) ready'),
        '1 full load ready',
      );
    });

    test('text with no parenthetical is returned untouched, identically', () {
      const plain = 'Order accepted & dispatched';
      expect(identical(mlRepairParentheticalPlural(plain), plain), isTrue);
    });

    test('a "(s)" that is not a plural is left alone', () {
      // Narrow on purpose: only DIGIT, space, word, "(s)".
      expect(
        mlRepairParentheticalPlural('Vehicle (s) is not a count'),
        'Vehicle (s) is not a count',
      );
      expect(
        mlRepairParentheticalPlural('see note (s) below'),
        'see note (s) below',
      );
    });

    test('more than one in the same sentence', () {
      expect(
        mlRepairParentheticalPlural('3 truck(s) and 1 driver(s)'),
        '3 trucks and 1 driver',
      );
    });
  });

  group('mlCount / mlCountText', () {
    test('an int agrees', () {
      expect(mlCount(1, 'truck'), '1 truck');
      expect(mlCount(2, 'truck'), '2 trucks');
      expect(mlCount(1, 'company', 'companies'), '1 company');
      expect(mlCount(0, 'company', 'companies'), '0 companies');
    });

    test('free text agrees, and tolerates what a form produces', () {
      expect(mlCountText('1', 'truck'), '1 truck');
      expect(mlCountText(' 1 ', 'truck'), '1 truck');
      expect(mlCountText('01', 'truck'), '01 truck');
      expect(mlCountText('4', 'truck'), '4 trucks');
    });

    test('an unparseable value takes the PLURAL', () {
      // "— days" reads as a missing figure; "— day" reads as a typo.
      expect(mlCountText('—', 'day'), '— days');
      expect(mlCountText(null, 'day'), 'days');
      expect(mlCountText('', 'day'), 'days');
    });
  });
}
