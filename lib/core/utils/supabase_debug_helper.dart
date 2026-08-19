import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/features/employee/models/employee_status_model.dart';
import 'package:flutter_application_1/features/notifications/models/notification_model.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

/// Helper class for debugging and fixing Supabase issues
class SupabaseDebugHelper {
  static final _supabase = SupabaseConfig.client;
  static final _uuid = const Uuid();
  static final _logger = LoggerFactory.getLogger('SupabaseDebugHelper');

  /// Test employee_status_history insertion with error handling
  static Future<Map<String, dynamic>> testEmployeeStatusHistoryInsertion({
    required String employeeId,
    required String companyId,
  }) async {
    try {
      // Create a test status entry
      final status = EmployeeStatusHistory(
        id: _uuid.v4(),
        employeeId: employeeId,
        companyId: companyId,
        status: EmployeeApprovalStatus.requestSent,
        timestamp: DateTime.now(),
      );

      // Convert to JSON and print for debugging
      final json = status.toJson();
      _logger.d(
        'Attempting to insert employee_status_history with data: $json',
      );

      // Try to insert the record
      final response = await _supabase
          .from('employee_status_history')
          .insert(json)
          .select()
          .single();

      return {
        'success': true,
        'message': 'Successfully inserted employee_status_history record',
        'data': response,
      };
    } catch (e) {
      _logger.e('Error inserting employee_status_history', e);
      return {
        'success': false,
        'message': 'Error inserting employee_status_history. ${friendlyError(e)}',
        'error': e.toString(),
      };
    }
  }

  /// Test notifications insertion with error handling
  static Future<Map<String, dynamic>> testNotificationInsertion({
    required String userId,
  }) async {
    try {
      // Create a test notification
      final notification = AppNotification(
        id: _uuid.v4(),
        userId: userId,
        title: 'Test Notification',
        message: 'This is a test notification for debugging',
        type: NotificationType.general,
        createdAt: DateTime.now(),
      );

      // Convert to JSON and print for debugging
      final json = notification.toJson();
      _logger.d('Attempting to insert notification with data: $json');

      // Try to insert the record
      final response = await _supabase
          .from('notifications')
          .insert(json)
          .select()
          .single();

      return {
        'success': true,
        'message': 'Successfully inserted notification record',
        'data': response,
      };
    } catch (e) {
      _logger.e('Error inserting notification', e);
      return {
        'success': false,
        'message': 'Error inserting notification. ${friendlyError(e)}',
        'error': e.toString(),
      };
    }
  }

  /// Show a debug dialog with test results
  static void showDebugDialog(
    BuildContext context,
    Map<String, dynamic> results,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(results['success'] ? 'Success' : 'Error'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(results['message']),
              const SizedBox(height: 16),
              if (results['success'])
                Text('Data: ${results['data']}')
              else
                Text('Error: ${results['error']}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
