/// Formats the counted half of a header meta line: `1 load`, `14 loads`.
///
/// Exists so S5-22's meta lines are phrased the same way on all 74 headers
/// rather than 74 slightly different ways, and so the singular case is right
/// everywhere — "1 loads" is the tell that a count was pasted in rather than
/// written. Pass [plural] when it is not the singular plus an s.
///
/// Lives in `core/design/components/` and is re-exported by **both**
/// `MlPageHeader` and `MlSectionTitle`, so it is in scope wherever a header is,
/// with no extra import at the call site. Putting it in either widget's own
/// file would have made the other one import across the core→feature boundary.
String mlCount(int n, String singular, [String? plural]) =>
    '$n ${n == 1 ? singular : (plural ?? '${singular}s')}';

/// [mlCount] for a figure that is **not an `int`** — free text, or already
/// formatted.
///
/// ## Why a second one was needed
///
/// [mlCount] was written for header meta lines, where the count is a
/// `List.length`. It could not be used on the request queues, and that is
/// exactly where the fault it describes was found: driving the console in a
/// browser on 2026-08-21, the mine transport inbox read **"1 trucks"** on two
/// of its three requests.
///
/// `TransportationRequest.numSlots`, `.tons`, `.tonsAvailable` and
/// `.distance` are all `String?` — free text a requester typed into a form —
/// and other sites hold a figure that has already been through
/// `NumberFormat`. Twenty-five call sites across sixteen files interpolated
/// one of those straight in front of a hard-coded plural noun, so all of them
/// printed "1 trucks", "1 drivers", "1 tons", "1 loads", "1 days" or
/// "1 companies" whenever the figure was one.
///
/// That whole family survived the earlier `thing(s)` sweep because it does not
/// contain the tell: `(s)` is greppable and `${n} trucks` is ordinary string
/// interpolation. The `count-without-plural-agreement` guard is what greps for
/// it now.
///
/// **An unparseable value takes the PLURAL.** `'— days'` reads as a missing
/// figure; `'— day'` reads as a typo. `' 1'` and `'01'` are one.
String mlCountText(Object? value, String singular, [String? plural]) {
  final text = value?.toString().trim() ?? '';
  final word =
      num.tryParse(text) == 1 ? singular : (plural ?? '${singular}s');
  return text.isEmpty ? word : '$text $word';
}
