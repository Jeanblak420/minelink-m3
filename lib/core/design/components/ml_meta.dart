/// The header meta-line counters, kept in scope wherever a header is.
///
/// [mlCount] and [mlCountText] themselves live in `core/utils/ml_count.dart`
/// and are re-exported from here, which is how the 74 header call sites that
/// take them from `MlPageHeader` / `MlSectionTitle` keep working with no import
/// of their own.
///
/// **Why they moved out of this file.** They are pure Dart string functions
/// with no Flutter dependency, and on 2026-08-21 the first non-header caller
/// turned up: `MlTime.ago` formats "N days ago", which is the same "1 days"
/// fault the counters exist to prevent. Reaching `core/design/components/`
/// from `core/time/` would have made a time utility depend on the design layer
/// to spell a plural. The definition is in `core/utils/`; this file keeps the
/// original reasoning, which still holds:
///
/// > Exists so S5-22's meta lines are phrased the same way on all 74 headers
/// > rather than 74 slightly different ways, and so the singular case is right
/// > everywhere — "1 loads" is the tell that a count was pasted in rather than
/// > written. Putting it in either widget's own file would have made the other
/// > one import across the core→feature boundary.
library;

export 'package:flutter_application_1/core/utils/ml_count.dart'
    show mlCount, mlCountText, mlDistanceText;
