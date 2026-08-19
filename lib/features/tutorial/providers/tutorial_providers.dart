import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/company/providers/company_provider.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';
import 'package:flutter_application_1/features/tutorial/models/showcase_item.dart';
import 'package:flutter_application_1/features/tutorial/models/tutorial_step.dart';
import 'package:flutter_application_1/features/tutorial/services/showcase_service.dart';
import 'package:flutter_application_1/features/tutorial/services/tutorial_service.dart';

final _log = LoggerFactory.getLogger('TutorialProviders');

// -- Services -----------------------------------------------------------------

final tutorialServiceProvider = Provider<TutorialService>((ref) {
  return const TutorialService();
});

final showcaseServiceProvider = Provider<ShowcaseService>((ref) {
  return ShowcaseService();
});

// -- Tutorial steps -----------------------------------------------------------

/// The guided-tour steps for the signed-in operator, derived from their org
/// type (company owner or employee's company) and employee role.
final tutorialStepsProvider = Provider.autoDispose<List<TutorialStep>>((ref) {
  final authState = ref.watch(authStateProvider);
  if (authState.user == null) return const [];

  final companyState = ref.watch(companyProvider);
  final employeeState = ref.watch(employeeProvider);

  final orgType = authState.userType?.isCompany == true
      ? companyState.company?.orgType
      : employeeState.company?.orgType;
  final role = employeeState.employee?.role;

  final service = ref.watch(tutorialServiceProvider);
  return service.getTutorialForUser(orgType, role);
});

// -- Showcase / demo data -----------------------------------------------------

/// Showcase demo data from the live `showcase_data` table, grouped by
/// category (mine / buyer / transporter / truck / driver / trip / stockpile /
/// road_request). Empty map on failure — never throws into the UI.
///
/// The 14 rows stay in production by the client's explicit ruling of
/// 2026-08-12 (P10-D8). Nothing renders them yet — `ShowcaseItem.data` has
/// never been read by a widget (P10-24) — so this provider currently has no
/// consumer. It is kept, not deleted, because the rows it reads are now a
/// client decision rather than an accident: whoever builds the tour's example
/// content is meant to read them through here.
final showcaseDataProvider =
    FutureProvider.autoDispose<Map<String, List<ShowcaseItem>>>((ref) {
  final service = ref.watch(showcaseServiceProvider);
  return service.getGroupedByCategory();
});

// `hasShowcaseDataProvider` was removed with `DemoDataIndicator` on 2026-08-12
// (P10-D8). Its only job was to answer "is showcase_data non-empty", which the
// banner treated as "this screen is showing example content" — two different
// statements. Rows existing in a table say nothing about what is on screen, and
// conflating them is what told operators their live data was a demo. Do not
// reintroduce a presence-of-rows trigger; trigger on the render instead.

// -- "Tour seen" persistence --------------------------------------------------

/// Persisted "the user has finished or skipped the tour" flag. Uses
/// [SharedPreferences], the same local-prefs mechanism as
/// `ThemeModeNotifier` / `AppSidebarPrefs`. Defaults to true (no badge)
/// until the stored value is restored, so the hint never flashes for
/// returning users.
class TutorialSeenNotifier extends StateNotifier<bool> {
  static const _prefsKey = 'tutorial_tour_seen';

  TutorialSeenNotifier() : super(true) {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool(_prefsKey);
      if (mounted) {
        state = stored ?? false;
      }
    } catch (_) {
      // Keep the default when prefs are unavailable (e.g. tests).
    }
  }

  Future<void> markSeen() async {
    state = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, true);
    } catch (_) {
      // Persistence is best-effort.
    }
  }
}

final tutorialSeenProvider =
    StateNotifierProvider<TutorialSeenNotifier, bool>((ref) {
  return TutorialSeenNotifier();
});

// -- Overlay state ------------------------------------------------------------

class TutorialOverlayData {
  final bool isVisible;
  final int currentStep;

  const TutorialOverlayData({
    this.isVisible = false,
    this.currentStep = 0,
  });

  TutorialOverlayData copyWith({bool? isVisible, int? currentStep}) {
    return TutorialOverlayData(
      isVisible: isVisible ?? this.isVisible,
      currentStep: currentStep ?? this.currentStep,
    );
  }
}

/// Visibility + current step of the tour overlay. Kept alive (no autoDispose)
/// so the tour survives in-tour navigation to a step's action route.
class TutorialOverlayNotifier extends StateNotifier<TutorialOverlayData> {
  TutorialOverlayNotifier() : super(const TutorialOverlayData());

  void show() {
    _log.i('Showing tutorial overlay');
    state = state.copyWith(isVisible: true, currentStep: 0);
  }

  void dismiss() {
    _log.i('Dismissing tutorial overlay');
    state = state.copyWith(isVisible: false);
  }

  void nextStep(int totalSteps) {
    if (state.currentStep + 1 >= totalSteps) {
      dismiss();
      return;
    }
    state = state.copyWith(currentStep: state.currentStep + 1);
  }

  void previousStep() {
    if (state.currentStep <= 0) return;
    state = state.copyWith(currentStep: state.currentStep - 1);
  }
}

final tutorialOverlayProvider =
    StateNotifierProvider<TutorialOverlayNotifier, TutorialOverlayData>((ref) {
  return TutorialOverlayNotifier();
});
