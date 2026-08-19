import 'dart:io';
import 'package:flutter_application_1/core/utils/logger.dart';

/// A utility class for accessing the direct database connection string
/// This is useful for tools that need direct database access
/// rather than going through the Supabase API
class DirectDbConnection {
  static final _logger = LoggerFactory.getLogger('DirectDbConnection');

  /// Returns the database connection string from the environment variable
  /// Returns null if the environment variable is not set
  static String? getConnectionString() {
    return Platform.environment['DB_URL'];
  }

  /// Checks if the direct database connection is available
  static bool isAvailable() {
    return getConnectionString() != null;
  }

  /// Returns the connection string components as a map
  /// Returns null if the connection string is not available
  static Map<String, String>? getConnectionComponents() {
    final connectionString = getConnectionString();
    if (connectionString == null) return null;

    // Parse the connection string
    // Format: postgresql://username:password@host:port/database
    try {
      final uri = Uri.parse(connectionString);
      return {
        'host': uri.host,
        'port': uri.port.toString(),
        'database': uri.path.replaceAll('/', ''),
        'username': uri.userInfo.split(':')[0],
        'password': uri.userInfo.split(':')[1],
      };
    } catch (e) {
      _logger.e('Error parsing connection string', e);
      return null;
    }
  }
}
