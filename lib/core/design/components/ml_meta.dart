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
