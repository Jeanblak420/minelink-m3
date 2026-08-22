// The sidebar starts collapsed, everywhere, for anybody who has not said
// otherwise.
//
// Ruled by jean, 2026-08-22: *"the sidebar menu nav should always be collapsed
// by default and each of the parents in it should also be collapsed by default
// on all devices and platforms please, windows, mobile, where ever and what
// ever"*.
//
// There are FOUR places that answer this question, and they have to agree or
// the rail flashes the wrong width on start:
//
//   1. `AppSidebarPrefs.readPortalExpanded()`      — the stored answer
//   2. `AppSidebarPrefs.readSuperAdminExpanded()`  — the same, for the console
//   3. `_PortalShellLayoutState._portalSidebarExpanded` — the frames BEFORE
//      that read resolves
//   4. `_SuperAdminShellLayoutState._railExpanded`  — likewise
//
// (3) and (4) are read from source here rather than pumped, because reaching
// them through a widget means standing up the whole portal shell — auth,
// company, employee and workspace providers — to assert one boolean. The
// source read is stripped of comments first: a `contains` check that matches
// the prose ABOVE the line it is checking is a green test over nothing, which
// is exactly how a chat test passed on 2026-08-22 by matching the comment
// describing the bug it was written for.
//
// The GROUPS-closed half is `ml_nav_rail_test.dart`'s "groups start CLOSED".
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/core/navigation/app_sidebar_prefs.dart';

/// [path] with `//` line comments and `///` doc comments removed.
String _codeOnly(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path has moved');
  return file
      .readAsLinesSync()
      .map((l) {
        final i = l.indexOf('//');
        return i == -1 ? l : l.substring(0, i);
      })
      .join('\n');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the stored preference', () {
    test('a user who has never touched it gets a COLLAPSED portal rail', () {
      SharedPreferences.setMockInitialValues({});
      expect(AppSidebarPrefs.readPortalExpanded(), completion(isFalse));
    });

    test('a user who has never touched it gets a COLLAPSED console rail', () {
      SharedPreferences.setMockInitialValues({});
      expect(AppSidebarPrefs.readSuperAdminExpanded(), completion(isFalse));
    });

    test('an explicit choice is still honoured, both ways', () async {
      // The default changed; the preference did not stop working. Without
      // this, "return false" would pass the two tests above.
      SharedPreferences.setMockInitialValues({});
      await AppSidebarPrefs.writePortalExpanded(true);
      expect(await AppSidebarPrefs.readPortalExpanded(), isTrue);

      await AppSidebarPrefs.writePortalExpanded(false);
      expect(await AppSidebarPrefs.readPortalExpanded(), isFalse);

      await AppSidebarPrefs.writeSuperAdminExpanded(true);
      expect(await AppSidebarPrefs.readSuperAdminExpanded(), isTrue);
    });
  });

  group('the value used before the preference has been read', () {
    test('the portal shell starts collapsed', () {
      final src = _codeOnly(
        'lib/features/portal/widgets/portal_shell_layout.dart',
      );
      expect(
        src,
        contains('bool _portalSidebarExpanded = false;'),
        reason: 'this is the width for the frames before readPortalExpanded '
            'resolves. If it disagrees with that read, the rail opens at '
            '280px and snaps shut a frame later — a flash of the wrong '
            'layout on every app start.',
      );
    });

    test('the console shell starts collapsed', () {
      final src = _codeOnly(
        'lib/features/super_admin/widgets/super_admin_shell_layout.dart',
      );
      expect(
        src,
        contains('bool _railExpanded = false;'),
        reason: 'same reason as the portal shell above',
      );
    });
  });
}
