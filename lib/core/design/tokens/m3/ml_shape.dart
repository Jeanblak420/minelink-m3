import 'package:flutter/material.dart';

/// The Material 3 **shape scale**, and the single place a corner radius is
/// decided in this app.
///
/// The shipping app carried its own seven-step scale (`MlTokens.rXs … rPill`)
/// that predates M3's. The two are close but not the same, and where they
/// disagreed the app used whichever one the author reached for first — so a
/// dialog and a bottom sheet, which M3 puts on the same step, ended up 16 and
/// 24. This is the M3 scale, and `MlTokens`' radii are kept only as aliases
/// pointing here (see the bottom of this file) so existing screens compile
/// unchanged while they migrate.
///
/// M3's steps, and what each one is *for* — the "for" is the part that stops
/// this becoming seven interchangeable numbers again:
///
/// | step | dp | used by |
/// |---|---|---|
/// | none | 0 | full-bleed surfaces, table cells, dividers |
/// | extraSmall | 4 | menu items, snackbar, tooltip |
/// | small | 8 | chips, badges, small text fields |
/// | medium | 12 | buttons, inputs, nav tiles, list tiles |
/// | large | 16 | **cards** — the app's most common surface |
/// | largeIncreased | 20 | hero tiles, prominent stat cards |
/// | extraLarge | 28 | **dialogs, bottom sheets, FABs, side sheets** |
/// | extraLargeIncreased | 32 | full-screen sheet tops |
/// | full | stadium | pills, avatars, nav indicators, toggles |
abstract final class MlShape {
  const MlShape._();

  // ---- The scale, in dp ----
  static const double none = 0;
  static const double extraSmall = 4;
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double largeIncreased = 20;
  static const double extraLarge = 28;
  static const double extraLargeIncreased = 32;

  /// Not a radius — a request for a stadium. Kept as a number only so the
  /// legacy `MlTokens.rPill` alias can point at something; prefer
  /// [stadiumBorder] / [pill] over `BorderRadius.circular(MlShape.full)`,
  /// which rounds a tall box into a lozenge rather than a stadium.
  static const double full = 999;

  // ---- BorderRadius ----
  static const BorderRadius radiusExtraSmall =
      BorderRadius.all(Radius.circular(extraSmall));
  static const BorderRadius radiusSmall =
      BorderRadius.all(Radius.circular(small));
  static const BorderRadius radiusMedium =
      BorderRadius.all(Radius.circular(medium));
  static const BorderRadius radiusLarge =
      BorderRadius.all(Radius.circular(large));
  static const BorderRadius radiusLargeIncreased =
      BorderRadius.all(Radius.circular(largeIncreased));
  static const BorderRadius radiusExtraLarge =
      BorderRadius.all(Radius.circular(extraLarge));
  static const BorderRadius pill =
      BorderRadius.all(Radius.circular(full));

  /// The top-rounded radius a bottom sheet or a docked panel wants. M3 rounds
  /// only the leading edge of a surface that is anchored to a screen edge —
  /// rounding all four corners on a sheet flush with the bottom of the window
  /// leaves two visible notches against the frame.
  static const BorderRadius radiusTopExtraLarge = BorderRadius.only(
    topLeft: Radius.circular(extraLarge),
    topRight: Radius.circular(extraLarge),
  );

  static const BorderRadius radiusTopExtraLargeIncreased = BorderRadius.only(
    topLeft: Radius.circular(extraLargeIncreased),
    topRight: Radius.circular(extraLargeIncreased),
  );

  /// Leading-edge rounding for a **side** sheet (a slide-over from the right).
  static const BorderRadius radiusStartExtraLarge = BorderRadius.only(
    topLeft: Radius.circular(extraLarge),
    bottomLeft: Radius.circular(extraLarge),
  );

  // ---- ShapeBorder, for the component themes ----
  static const RoundedRectangleBorder shapeExtraSmall =
      RoundedRectangleBorder(borderRadius: radiusExtraSmall);
  static const RoundedRectangleBorder shapeSmall =
      RoundedRectangleBorder(borderRadius: radiusSmall);
  static const RoundedRectangleBorder shapeMedium =
      RoundedRectangleBorder(borderRadius: radiusMedium);
  static const RoundedRectangleBorder shapeLarge =
      RoundedRectangleBorder(borderRadius: radiusLarge);
  static const RoundedRectangleBorder shapeLargeIncreased =
      RoundedRectangleBorder(borderRadius: radiusLargeIncreased);
  static const RoundedRectangleBorder shapeExtraLarge =
      RoundedRectangleBorder(borderRadius: radiusExtraLarge);
  static const RoundedRectangleBorder shapeTopExtraLarge =
      RoundedRectangleBorder(borderRadius: radiusTopExtraLarge);

  /// A true stadium — both ends fully round whatever the box's height.
  static const StadiumBorder stadiumBorder = StadiumBorder();

  // ---- Named roles ----
  //
  // These exist so a screen asks for "a card" rather than for "16", which is
  // what lets the scale move later without a 500-file find-and-replace.

  /// The standard content card. The app's most common surface by a wide margin.
  static const RoundedRectangleBorder card = shapeLarge;

  /// A stat / hero tile — one step up from a card so it reads as raised even
  /// when it is flat.
  static const RoundedRectangleBorder heroTile = shapeLargeIncreased;

  /// Dialogs, bottom sheets, side sheets, FABs, and menus that float.
  static const RoundedRectangleBorder dialog = shapeExtraLarge;

  /// Buttons, text fields, dropdowns, and navigation tiles.
  static const RoundedRectangleBorder control = shapeMedium;

  /// Chips, badges, and small tags that are not stadium-shaped.
  static const RoundedRectangleBorder chip = shapeSmall;

  /// Status pills, avatars, navigation indicators, toggles.
  static const StadiumBorder pillShape = stadiumBorder;
}
