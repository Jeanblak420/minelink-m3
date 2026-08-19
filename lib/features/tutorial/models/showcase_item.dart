/// One row of the live `showcase_data` table — seeded demo/example content
/// (mines, buyers, transporters, trucks, drivers, trips, stockpiles,
/// road requests) surfaced during the guided tour.
class ShowcaseItem {
  final String id;

  /// Category key, e.g. `mine`, `buyer`, `transporter`, `truck`, `driver`,
  /// `trip`, `stockpile`, `road_request`.
  final String category;

  /// The seeded demo payload (`json_data` column).
  final Map<String, dynamic> data;

  final DateTime? createdAt;

  const ShowcaseItem({
    required this.id,
    required this.category,
    required this.data,
    this.createdAt,
  });

  factory ShowcaseItem.fromJson(Map<String, dynamic> json) {
    return ShowcaseItem(
      id: json['id']?.toString() ?? '',
      category: json['category'] as String? ?? 'misc',
      data: (json['json_data'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}
