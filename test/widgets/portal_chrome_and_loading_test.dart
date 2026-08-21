// Two things the portal only showed once somebody signed into it.
//
// Driven in a browser against the live database as `ironhills.owner` on
// 2026-08-21 — the first time a company user's portal had been opened outside
// a render.
//
//  1. The top bar read **"Iron Hills Mining · Iron Hills Mining ·
//     Mine/Supplier"**. `portalOwnerName` falls back to the company's own name
//     when no CEO name is on file, which is right where it stands for an
//     identity and wrong in a line that already names the company. "CEO /
//     owner name" is one of the six items that company's setup card is still
//     asking for, so it is not an edge case: it is what every company sees
//     until somebody finishes the form.
//
//  2. The stockpile card read **"Stockpiles unavailable — The stockpile
//     balances could not be read."** while the read was still in flight. The
//     screen's own comment, three lines above the offending one, already says
//     `valueOrNull` collapses "still reading" and "could not read" into one
//     null — the other three providers on that screen keep their AsyncValue
//     for exactly this reason and this one did not.
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/portal/providers/portal_workspace_provider.dart';

void main() {
  group('the portal top bar does not say the same thing twice', () {
    test('a company with no CEO name on file', () {
      // `portalOwnerName` has already fallen back to the company name by the
      // time it reaches here — that is the case being fixed.
      expect(
        portalShellSubtitle(
          workspaceName: 'Iron Hills Mining',
          operatorName: 'Iron Hills Mining',
          roleLabel: 'Mine/Supplier',
        ),
        'Iron Hills Mining · Mine/Supplier',
      );
    });

    test('a company WITH a CEO name keeps all three parts', () {
      expect(
        portalShellSubtitle(
          workspaceName: 'Iron Hills Mining',
          operatorName: 'Thabo Nkosi',
          roleLabel: 'Mine/Supplier',
        ),
        'Iron Hills Mining · Thabo Nkosi · Mine/Supplier',
      );
    });

    test('the duplicate check ignores case and surrounding space', () {
      expect(
        portalShellSubtitle(
          workspaceName: 'Iron Hills Mining',
          operatorName: '  iron hills mining ',
          roleLabel: 'Mine/Supplier',
        ),
        'Iron Hills Mining · Mine/Supplier',
      );
    });

    test('an empty part is dropped, not printed as a stray separator', () {
      expect(
        portalShellSubtitle(
          workspaceName: 'Roadhaul Logistics',
          operatorName: '',
          roleLabel: 'Transporter',
        ),
        'Roadhaul Logistics · Transporter',
      );
      expect(
        portalShellSubtitle(
          workspaceName: '',
          operatorName: '',
          roleLabel: '',
        ),
        '',
      );
    });

    test('a driver whose own name matches nothing keeps every part', () {
      expect(
        portalShellSubtitle(
          workspaceName: 'Roadhaul Logistics',
          operatorName: 'Sipho Dlamini',
          roleLabel: 'Driver',
        ),
        'Roadhaul Logistics · Sipho Dlamini · Driver',
      );
    });
  });
}
