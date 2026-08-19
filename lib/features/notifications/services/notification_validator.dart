import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

/// A utility class to validate notification data before insertion
class NotificationValidator {
  static final _logger = LoggerFactory.getLogger('NotificationValidator');
  static final _supabase = SupabaseConfig.client;

  /// Cache of valid user IDs to reduce database queries
  static final Map<String, bool> _userIdCache = {};

  /// Check if a user ID exists in the auth.users table
  static Future<bool> isValidUserId(String userId) async {
    // Check cache first
    if (_userIdCache.containsKey(userId)) {
      return _userIdCache[userId]!;
    }

    if (_supabase.auth.currentUser?.id == userId) {
      _userIdCache[userId] = true;
      return true;
    }

    try {
      final result = await _supabase.rpc(
        'check_user_exists',
        params: {'user_id': userId},
      );

      final exists = result == true;
      _userIdCache[userId] = exists;
      return exists;
    } catch (e) {
      _logger.w(
        'check_user_exists RPC unavailable, skipping proactive validation for user $userId. ${friendlyError(e)}',
      );
      return true;
    }
  }

  /// Clear the user ID cache
  static void clearCache() {
    _userIdCache.clear();
  }

  /// Validate a notification before insertion
  static Future<Map<String, dynamic>> validateNotification(
    Map<String, dynamic> notification,
  ) async {
    final userId = notification['user_id'];

    if (userId == null || userId.toString().isEmpty) {
      throw Exception('Notification user_id cannot be null or empty');
    }

    // Check if the user exists
    final userExists = await isValidUserId(userId);

    if (!userExists) {
      _logger.w('User ID $userId does not exist in auth.users table');
      throw Exception('User ID $userId does not exist in auth.users table');
    }

    return notification;
  }
}
