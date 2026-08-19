/// A document attached to a stockpile — a lab-result PDF or a picture. Files
/// live in the private `request_docs` bucket; [storagePath] is the
/// bucket-relative object path, resolved to a short-lived signed URL for
/// viewing (see `StorageAssetService.resolveRequestDocUrl`).
class StockpileDoc {
  final String id;
  final String stockpileId;
  final String kind; // 'lab_result' | 'picture'
  final String storagePath;
  final String fileName;
  final DateTime createdAt;

  const StockpileDoc({
    required this.id,
    required this.stockpileId,
    required this.kind,
    required this.storagePath,
    required this.fileName,
    required this.createdAt,
  });

  factory StockpileDoc.fromJson(Map<String, dynamic> m) => StockpileDoc(
        id: m['id'] as String,
        stockpileId: m['stockpile_id'] as String,
        kind: (m['kind'] as String?) ?? 'lab_result',
        storagePath: (m['storage_path'] as String?) ?? '',
        fileName: (m['file_name'] as String?) ?? '',
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  bool get isPicture => kind == 'picture';
}
