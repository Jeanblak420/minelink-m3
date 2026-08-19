import 'package:flutter_application_1/core/utils/logger.dart';

/// Legacy realtime setup shim.
///
/// Realtime publications and replica identity are managed by migrations, not
/// by client-side SQL.
class RealtimeSetup {
  static final _logger = LoggerFactory.getLogger('RealtimeSetup');

  static Future<void> enableRealtimeForAllTables() async {
    _logger.i(
      'Realtime setup is server-managed. No client-side publication or '
      'replica identity changes were executed.',
    );
  }

  static Future<void> enableRealtimeForTable(String tableName) async {
    _logger.i(
      'Realtime for table $tableName is managed by migrations. No client-side '
      'DDL was executed.',
    );
  }
}
