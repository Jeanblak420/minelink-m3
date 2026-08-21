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

/// Rewrites `N thing(s)` into `N thing` or `N things`, in text this app did
/// not write.
///
/// ## Why the client repairs a server string
///
/// Every parenthesised plural in this product's own copy is gone. One is left,
/// and the app does not own it: `stockpile_add_tons` composes the collect
/// alert in Postgres and stores the finished sentence on the row —
///
///     Stockpile ready to collect — 2 full load(s) ready
///
/// — so the fix that reaches the source is a migration, and `supabase/` is
/// frozen in this fork (`docs/redesign/DESIGN.md`). The choice is between
/// shipping "load(s)" to a reader and repairing it where it arrives.
///
/// It is applied at the model boundary, in `NotificationModel.fromJson`, so
/// every surface that shows a notification gets the same sentence: the inbox,
/// the bell, the management screen, and any future one. Repairing it at each
/// render site is how a product ends up with three of them.
///
/// **This is a patch over a defect that still exists in the database.** When
/// the shipping app takes a migration for it, delete this and the call in
/// `fromJson`; `notification_plural_test.dart` pins the behaviour until then.
///
/// Deliberately narrow: a DIGIT, then **at most two** intervening words, then
/// the word carrying a literal `(s)`. Two, because the real string is
/// "2 full load(s)" — the figure is not adjacent to the noun it counts — and
/// bounded, so a match cannot reach across a sentence to a digit that has
/// nothing to do with it.
///
/// It will not touch "(s)" with no figure in front of it, and it does not try
/// to guess an irregular plural; the only cases the database produces are
/// regular.
String mlRepairParentheticalPlural(String text) {
  if (!text.contains('(s)')) return text;
  return text.replaceAllMapped(
    RegExp(r'(\d+)((?:\s+[A-Za-z]+){0,2}\s+)([A-Za-z]+)\(s\)'),
    (m) {
      final n = num.tryParse(m[1]!);
      final word = m[3]!;
      return '${m[1]}${m[2]}$word${n == 1 ? '' : 's'}';
    },
  );
}
