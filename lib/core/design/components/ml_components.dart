/// MineLink's component layer — one import for every shared surface,
/// control and status motif in the product.
///
/// ## Why this moved out of the portal feature
///
/// This set used to live at `lib/features/portal/widgets/ml/`. It was never
/// portal code: **118 files across 10 of the app's 15 features** imported it,
/// including super_admin (23), employee (8), profile (5), notifications (5)
/// and auth (4). A layout primitive owned by one feature is one the other
/// features either hand-copy or reach across a boundary for, and both had
/// already happened here.
///
/// It is the same reasoning that moved `MlPageBody` — recorded in that file —
/// applied to the rest of the set rather than one widget at a time.
///
/// ## What the layer is for
///
/// A census of `lib/features/` before this pass found **515 hand-rolled
/// `BoxDecoration`s**. Their shapes cluster hard:
///
/// | count | shape | what it actually is |
/// |---|---|---|
/// | 320 | rounded rect ± hairline border | a card — [MlCard] |
/// | 60 | circle | an icon well or avatar — [MlIconWell] |
/// | 43 | radius 999 | a status pill — [MlStatusBadge] |
///
/// Those 515 were drawn with **thirteen distinct corner radii** (2, 6, 7, 8,
/// 9, 10, 11, 12, 13, 14, 16, 18, 20) and coloured from **eight different
/// palette roots**. That is not a design system; it is 515 independent
/// guesses at one. Every component here exists so a screen can stop guessing.
///
/// ## The rule for anything added here
///
/// A component in this file draws from the four M3 primitives and nothing
/// else:
///
///  * **colour** — `Theme.of(context).colorScheme` for surface and ink,
///    [MlChrome] for the navy brand chrome, `MlTone` for a *domain* hue
///    (lifecycle status). Never a raw `Color(0x…)`; the
///    `no-raw-color-hex` release guard enforces this.
///  * **shape** — `MlShape`. Not `BorderRadius.circular(11)`.
///  * **type** — `Theme.of(context).textTheme`. Not a hand-built `TextStyle`
///    naming a font family and a pixel size.
///  * **motion** — `MlMotion.of(context, …)`, which collapses to 1ms under
///    reduce-motion. Not a bare `Duration` and `Curves.easeOut`, which
///    ignores the accessibility setting entirely.
///
/// If a component needs something none of those four supply, the primitive is
/// missing — add it there, not a literal here.
library;

export 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

// ---- Surfaces ----
export 'ml_card.dart';
export 'ml_feature_card.dart';
export 'ml_stat_card.dart';
export 'ml_tile_grid.dart';

// ---- Page structure ----
export 'ml_page_body.dart';
export 'ml_header_layout.dart';
export 'ml_page_header.dart';
export 'ml_section_title.dart';
export 'ml_meta.dart';

// ---- Status & identity ----
export 'ml_status_badge.dart';
export 'ml_plate_pill.dart';
export 'ml_icon_well.dart';
export 'ml_icon_3d.dart';

// ---- Controls ----
export 'ml_buttons.dart';
export 'ml_locked_action.dart';

// ---- States ----
export 'ml_empty_state.dart';
export 'ml_load_failure.dart';
export 'ml_expiry_notice.dart';

// ---- Data & media ----
export 'ml_data_table.dart';
export 'ml_wide_table.dart';
export 'ml_map_canvas.dart';
export 'ml_map_controls.dart';
export 'ml_dropped_pin.dart';
export 'ml_overlays.dart';
export 'ml_field_pair.dart';
