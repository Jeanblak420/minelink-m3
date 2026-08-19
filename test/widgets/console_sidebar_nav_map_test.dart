import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/routing/app_router.dart';
import 'package:flutter_application_1/core/widgets/minelink_logo.dart';
import 'package:flutter_application_1/core/design/tokens/ui_prefs.dart';
import 'package:flutter_application_1/features/super_admin/widgets/sidebar/console_palette_tokens.dart';
import 'package:flutter_application_1/features/super_admin/widgets/sidebar/console_sidebar_bridge.dart';
import 'package:flutter_application_1/features/super_admin/widgets/sidebar/minelink_sidebar_app.dart';
import 'package:flutter_application_1/features/super_admin/widgets/sidebar/minelink_sidebar_core.dart';
import 'package:flutter_application_1/features/super_admin/widgets/sidebar/minelink_sidebar_haul.dart';
import 'package:flutter_application_1/features/super_admin/widgets/sidebar/minelink_sidebar_weighbridge.dart';

/// The Haul/Weighbridge skins navigate by emitting a nav id, which
/// `console_sidebar_bridge.dart` turns into a route. These tests fail if a
/// destination is renamed or added without being wired, so a nav row can never
/// silently dead-end.
void main() {
  group('console sidebar nav map', () {
    test('every nav id has a route, or is a group/action', () {
      final unmapped = MlNav.allIds()
          .where((id) => !consoleNavRoutes.containsKey(id))
          .where((id) => !consoleNavActionOrGroupIds.contains(id))
          .toList();

      expect(
        unmapped,
        isEmpty,
        reason: 'Nav ids with nowhere to go: $unmapped — add them to '
            'consoleNavRoutes (or to consoleNavActionOrGroupIds if they are '
            'group parents / actions).',
      );
    });

    // Found by mistyping a request-inbox URL during the 2026-08-17 walk.
    //
    // `/super-admin/requests/:type` matches ANY string, so
    // `/super-admin/requests/buyer-requests` rendered the review screen's
    // generic fallback — "Requested routes", "Queue is clear, no requests in
    // this queue yet" — under an app bar reading "Requested buyers", while two
    // buyer requests sat waiting. A review queue that reports itself empty
    // when it is not is the worst way for a link to fail: the admin closes the
    // tab.
    group('the request inbox only serves queues that exist', () {
      test('every real queue stays put', () {
        for (final t in kSuperAdminRequestQueues) {
          expect(superAdminRequestsRedirect(t), isNull, reason: t);
        }
      });

      test('an unknown queue goes to the canonical inbox, not to an empty one',
          () {
        for (final t in ['buyer-requests', 'products', '', 'BUYER', 'nonsense']) {
          expect(superAdminRequestsRedirect(t),
              '/super-admin/requests/transportation',
              reason: 'type "$t"');
        }
        expect(superAdminRequestsRedirect(null),
            '/super-admin/requests/transportation');
      });

      test('the ML deep-link aliases keep their own destinations', () {
        // Their literal GoRoutes are declared first and win the match today,
        // but that is an ordering assumption. Resolved here too, so an alias
        // cannot quietly land on the combined inbox instead of its own.
        expect(superAdminRequestsRedirect('mine-transport'),
            '/super-admin/requests/transportation-mine');
        expect(superAdminRequestsRedirect('buyer-transport'),
            '/super-admin/requests/transportation-buyer');
      });

      test('every sidebar destination under /requests/ is a queue that exists',
          () {
        const prefix = '/super-admin/requests/';
        for (final entry in consoleNavRoutes.entries) {
          final route = entry.value;
          if (!route.startsWith(prefix)) continue;
          final type = route.substring(prefix.length);
          expect(superAdminRequestsRedirect(type), isNull,
              reason: '${entry.key} points at "$route", which the router will '
                  'bounce — add "$type" to kSuperAdminRequestQueues or fix the '
                  'destination');
        }
      });
    });

    test('no route is mapped from an id the tree no longer has', () {
      final known = MlNav.allIds().toSet();
      final orphans =
          consoleNavRoutes.keys.where((id) => !known.contains(id)).toList();

      expect(orphans, isEmpty, reason: 'Routed ids missing from MlNav: $orphans');
    });

    test('every routed id round-trips from its own location', () {
      for (final entry in consoleNavRoutes.entries) {
        expect(
          consoleNavIdForLocation(entry.value),
          entry.key,
          reason: '${entry.value} should resolve back to ${entry.key}',
        );
      }
    });

    test('sibling paths that share a prefix resolve distinctly', () {
      // `/requests/buyer` vs `/requests/buyer-transport` is the trap: a naive
      // startsWith would collapse them onto the same row.
      expect(
        consoleNavIdForLocation('/super-admin/requests/buyer'),
        'requests.buyers',
      );
      expect(
        consoleNavIdForLocation('/super-admin/requests/buyer-transport'),
        'requests.buyer-transport',
      );
      expect(
        consoleNavIdForLocation('/super-admin/insights/buyer'),
        'insights.buyers',
      );
      // Deep links below a destination keep that destination highlighted.
      expect(
        consoleNavIdForLocation('/super-admin/insights/buyer/company/abc'),
        'insights.buyers',
      );
    });

    test('console root is the dashboard; unknown routes highlight nothing', () {
      expect(consoleNavIdForLocation('/super-admin'), 'dashboard');
      expect(consoleNavIdForLocation('/portal/dashboard'), '');
    });

    test('skin ids persist and parse back, unknown falls back to the default',
        () {
      for (final skin in ConsoleSidebarSkin.values) {
        expect(ConsoleSidebarSkin.parse(skin.id), skin);
      }
      expect(
        ConsoleSidebarSkin.parse('nonsense'),
        ConsoleSidebarSkin.defaultSkin,
      );
      expect(ConsoleSidebarSkin.parse(null), ConsoleSidebarSkin.defaultSkin);
    });

    test('console defaults: App nav rail on Amber', () {
      // Both set by explicit user decision (2026-08-08); the default rail
      // moved to the app nav when that drop landed.
      expect(ConsoleSidebarSkin.defaultSkin, ConsoleSidebarSkin.app);
      expect(ConsoleAccent.defaultAccent, ConsoleAccent.amber);

      // …and they are what a fresh admin actually gets.
      const fresh = UiPrefs();
      expect(fresh.sidebar, ConsoleSidebarSkin.app);
      expect(fresh.accent, ConsoleAccent.amber);

      // Prefs written before either default existed adopt them too.
      final legacy = UiPrefs.fromJson(<String, dynamic>{'dark': true});
      expect(legacy.sidebar, ConsoleSidebarSkin.app);
      expect(legacy.accent, ConsoleAccent.amber);

      // A saved choice still wins over the default.
      final chosen = UiPrefs.fromJson(
        <String, dynamic>{'sidebar': 'classic', 'accent': 'cyan'},
      );
      expect(chosen.sidebar, ConsoleSidebarSkin.classic);
      expect(chosen.accent, ConsoleAccent.cyan);
    });

    test('the sidebar choice survives a prefs JSON round-trip', () {
      for (final skin in ConsoleSidebarSkin.values) {
        final restored = UiPrefs.fromJson(
          Map<String, dynamic>.from(UiPrefs(sidebar: skin).toJson()),
        );
        expect(restored.sidebar, skin);
      }

      // Prefs saved before this feature existed have no 'sidebar' key, so
      // they pick up whatever the current default is.
      final legacy = UiPrefs.fromJson(<String, dynamic>{'dark': false});
      expect(legacy.sidebar, ConsoleSidebarSkin.defaultSkin);
    });
  });

  group('sidebar skin families', () {
    test('every skin belongs to exactly one layout family', () {
      for (final skin in ConsoleSidebarSkin.values) {
        expect(
          skin.isHaul && skin.isWeighbridge,
          isFalse,
          reason: '${skin.id} cannot be both layouts',
        );
      }
      expect(
        ConsoleSidebarSkin.values.where((s) => s.isHaul).toSet(),
        {ConsoleSidebarSkin.haul, ConsoleSidebarSkin.haulMineLink},
      );
      expect(
        ConsoleSidebarSkin.values.where((s) => s.isWeighbridge).toSet(),
        {ConsoleSidebarSkin.weighbridge,
            ConsoleSidebarSkin.weighbridgeMineLink},
      );
      // Classic is its own thing — built by the shell, not by the bridge.
      expect(ConsoleSidebarSkin.classic.isHaul, isFalse);
      expect(ConsoleSidebarSkin.classic.isWeighbridge, isFalse);
      // …and so is the app rail, which has its own layout.
      expect(ConsoleSidebarSkin.app.isHaul, isFalse);
      expect(ConsoleSidebarSkin.app.isWeighbridge, isFalse);
      expect(ConsoleSidebarSkin.app.isApp, isTrue);
    });

    test('the app rail reports the drop\'s own rail/panel widths', () {
      expect(
        consoleSidebarWidth(ConsoleSidebarSkin.app, collapsed: true),
        MlSidebarMetrics.collapsedWidth,
      );
      expect(
        consoleSidebarWidth(ConsoleSidebarSkin.app, collapsed: false),
        MlSidebarMetrics.expandedWidth,
      );
      // It opens narrower than every other rail and widens to less than they
      // do — that contrast is the point of it.
      expect(MlSidebarMetrics.collapsedWidth, lessThan(72));
      expect(MlSidebarMetrics.expandedWidth, lessThan(274));

      // Below its compact breakpoint the rail forces itself collapsed, so the
      // width reported to the drawer has to agree or the drawer leaves dead
      // space beside a 68px rail.
      expect(
        consoleSidebarWidth(
          ConsoleSidebarSkin.app,
          collapsed: false,
          windowWidth: MlSidebarMetrics.compactBreakpoint - 1,
        ),
        MlSidebarMetrics.collapsedWidth,
      );
      expect(
        consoleSidebarWidth(
          ConsoleSidebarSkin.app,
          collapsed: false,
          windowWidth: MlSidebarMetrics.compactBreakpoint + 1,
        ),
        MlSidebarMetrics.expandedWidth,
      );
    });

    test('only the MineLink variants get an app palette', () {
      expect(
        ConsoleSidebarSkin.values.where((s) => s.usesAppPalette).toSet(),
        {ConsoleSidebarSkin.haulMineLink,
            ConsoleSidebarSkin.weighbridgeMineLink},
      );
      for (final skin in ConsoleSidebarSkin.values) {
        final tokens = MlPaletteSidebarTokens.forSkin(
          skin,
          dark: true,
          accent: ConsoleAccent.cyan,
        );
        expect(
          tokens != null,
          skin.usesAppPalette,
          reason: '${skin.id} palette override should '
              '${skin.usesAppPalette ? "exist" : "be null"}',
        );
      }
    });

    test('a MineLink variant is the drop with colours swapped — geometry '
        'and fonts are byte-identical', () {
      for (final dark in [true, false]) {
        final haul = MlPaletteSidebarTokens.haul(
          dark: dark,
          accent: ConsoleAccent.violet,
        );
        final haulBase = dark ? HaulTokens.dark : HaulTokens.light;
        expect(haul.expandedWidth, haulBase.expandedWidth);
        expect(haul.railWidth, haulBase.railWidth);
        expect(haul.radius, haulBase.radius);
        expect(haul.rowHeight, haulBase.rowHeight);
        expect(haul.display, haulBase.display);
        expect(haul.body, haulBase.body);
        expect(haul.mono, haulBase.mono);
        expect(haul.isDarkSurface, haulBase.isDarkSurface);

        final wb = MlPaletteSidebarTokens.weighbridge(
          dark: dark,
          accent: ConsoleAccent.violet,
        );
        final wbBase =
            dark ? WeighbridgeTokens.dark : WeighbridgeTokens.light;
        expect(wb.expandedWidth, wbBase.expandedWidth);
        expect(wb.railWidth, wbBase.railWidth);
        expect(wb.radius, wbBase.radius);
        expect(wb.rowHeight, wbBase.rowHeight);
        expect(wb.display, wbBase.display);
        expect(wb.body, wbBase.body);
        expect(wb.mono, wbBase.mono);
        expect(wb.isDarkSurface, wbBase.isDarkSurface);

        // …and the colours really did change (no accidental passthrough).
        expect(haul.accent, isNot(haulBase.accent));
        expect(wb.accent, isNot(wbBase.accent));
      }
    });

    test('the MineLink variants track the chosen accent', () {
      for (final accent in ConsoleAccent.values) {
        expect(
          MlPaletteSidebarTokens.haul(dark: true, accent: accent).accent,
          accent.color,
        );
        expect(
          MlPaletteSidebarTokens.weighbridge(dark: false, accent: accent)
              .accent,
          accent.color,
        );
      }
    });

    test('Weighbridge keeps a readable ink block in both palettes', () {
      // Light: dark block, light type. Dark: light block, dark type.
      final light = MlPaletteSidebarTokens.weighbridge(
        dark: false,
        accent: ConsoleAccent.cyan,
      );
      final dark = MlPaletteSidebarTokens.weighbridge(
        dark: true,
        accent: ConsoleAccent.cyan,
      );
      double lum(Color c) => c.computeLuminance();
      expect(lum(light.surfaceActive), lessThan(0.1));
      expect(lum(light.onInk!), greaterThan(0.8));
      expect(lum(dark.surfaceActive), greaterThan(0.8));
      expect(lum(dark.onInk!), lessThan(0.1));
    });

    test('every rail renders the brand at the classic size', () {
      // The classic rail uses MineLinkLogo(height: 92) expanded and
      // MineLinkMark(size: 38) collapsed; the drops default to the same, so
      // the lockup is identical whichever sidebar is on.
      const brand = MlBrand();
      expect(brand.logoHeight, MlBrand.classicLogoHeight);
      expect(brand.iconSize, MlBrand.classicIconSize);
      expect(brand.logoHeight, 92);
      expect(brand.iconSize, 38);

      // …and off the same four files the rest of the app uses.
      expect(brand.logoOnDark, MineLinkLogo.assetDark);
      expect(brand.logoOnLight, MineLinkLogo.assetLight);
      expect(brand.iconOnDark, MineLinkMark.assetDark);
      expect(brand.iconOnLight, MineLinkMark.assetLight);

      // Artwork follows the rail's own surface, matching classic's onDark.
      expect(brand.logo(onDarkSurface: true), MineLinkLogo.assetDark);
      expect(brand.logo(onDarkSurface: false), MineLinkLogo.assetLight);
      expect(brand.icon(onDarkSurface: true), MineLinkMark.assetDark);
      expect(brand.icon(onDarkSurface: false), MineLinkMark.assetLight);
    });

    test('both layouts report the same width in either palette', () {
      for (final collapsed in [true, false]) {
        expect(
          consoleSidebarWidth(ConsoleSidebarSkin.haulMineLink,
              collapsed: collapsed),
          consoleSidebarWidth(ConsoleSidebarSkin.haul, collapsed: collapsed),
        );
        expect(
          consoleSidebarWidth(ConsoleSidebarSkin.weighbridgeMineLink,
              collapsed: collapsed),
          consoleSidebarWidth(ConsoleSidebarSkin.weighbridge,
              collapsed: collapsed),
        );
      }
    });
  });
}
