import 'package:flutter_application_1/core/services/database_service.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_model.dart';

/// Service for debugging document URL issues in the fleet management system
class FleetDocumentDebugService {
  final DatabaseService _databaseService;
  final Logger _logger = LoggerFactory.getLogger('FleetDocumentDebugService');

  FleetDocumentDebugService(this._databaseService);

  /// Verify document URLs for a specific vehicle
  Future<Map<String, dynamic>> verifyVehicleDocumentUrls(
    String vehicleId,
  ) async {
    try {
      // Get the vehicle details
      final vehicle = await _databaseService.getRecord(
        'fleet_vehicles',
        'id',
        vehicleId,
      );

      if (vehicle == null) {
        throw Exception('Vehicle not found');
      }

      final assignedDriverEmployeeId =
          vehicle['assigned_driver_employee_id'] ??
          vehicle['assigned_driver_id'];

      // If no driver is assigned, return early
      if (assignedDriverEmployeeId == null) {
        return {
          'status': 'no_driver',
          'message': 'No driver assigned to this vehicle',
          'vehicle_id': vehicleId,
        };
      }

      // Get the assigned driver details
      final driver = await _databaseService.getRecord(
        'employees',
        'id',
        assignedDriverEmployeeId,
      );

      if (driver == null) {
        return {
          'status': 'driver_not_found',
          'message': 'Assigned driver not found in employees table',
          'vehicle_id': vehicleId,
          'driver_id': assignedDriverEmployeeId,
        };
      }

      // Compare document URLs between driver and vehicle
      final documentStatus = {
        'id_document': {
          'driver_has_url': driver['id_document_url'] != null,
          'vehicle_has_url': vehicle['driver_id_document_url'] != null,
          'driver_url': driver['id_document_url'],
          'vehicle_url': vehicle['driver_id_document_url'],
          'match':
              driver['id_document_url'] == vehicle['driver_id_document_url'],
        },
        'passport_document': {
          'driver_has_url': driver['passport_document_url'] != null,
          'vehicle_has_url': vehicle['driver_passport_document_url'] != null,
          'driver_url': driver['passport_document_url'],
          'vehicle_url': vehicle['driver_passport_document_url'],
          'match':
              driver['passport_document_url'] ==
              vehicle['driver_passport_document_url'],
        },
        'work_visa_document': {
          'driver_has_url': driver['work_visa_document_url'] != null,
          'vehicle_has_url': vehicle['driver_work_visa_document_url'] != null,
          'driver_url': driver['work_visa_document_url'],
          'vehicle_url': vehicle['driver_work_visa_document_url'],
          'match':
              driver['work_visa_document_url'] ==
              vehicle['driver_work_visa_document_url'],
        },
        'license_document': {
          'driver_has_url': driver['license_document_url'] != null,
          'vehicle_has_url': vehicle['driver_license_document_url'] != null,
          'driver_url': driver['license_document_url'],
          'vehicle_url': vehicle['driver_license_document_url'],
          'match':
              driver['license_document_url'] ==
              vehicle['driver_license_document_url'],
        },
      };

      return {
        'status': 'success',
        'vehicle_id': vehicleId,
        'driver_id': assignedDriverEmployeeId,
        'driver_user_id': driver['user_id'],
        'driver_name': '${driver['first_name']} ${driver['last_name']}',
        'document_status': documentStatus,
      };
    } catch (e) {
      _logger.e('Error verifying vehicle document URLs', e);
      return {
        'status': 'error',
        'message': e.toString(),
        'vehicle_id': vehicleId,
      };
    }
  }

  /// Fix document URLs for a specific vehicle by manually copying them from the driver
  Future<FleetVehicle> fixVehicleDocumentUrls(String vehicleId) async {
    try {
      final vehicle = await _databaseService.getRecord(
        'fleet_vehicles',
        'id',
        vehicleId,
      );

      if (vehicle == null) {
        throw Exception('Vehicle not found');
      }

      final assignedDriverEmployeeId =
          vehicle['assigned_driver_employee_id'] ??
          vehicle['assigned_driver_id'];

      // If no driver is assigned, return early
      if (assignedDriverEmployeeId == null) {
        throw Exception('No driver assigned to this vehicle');
      }

      // Get the assigned driver details
      final driver = await _databaseService.getRecord(
        'employees',
        'id',
        assignedDriverEmployeeId,
      );

      if (driver == null) {
        throw Exception('Assigned driver not found in employees table');
      }

      final supabase = _databaseService.getSupabaseClient();

      await supabase.rpc(
        'unassign_fleet_driver',
        params: {'target_vehicle_id': vehicleId},
      );
      final response = await supabase.rpc(
        'assign_fleet_driver',
        params: {
          'target_vehicle_id': vehicleId,
          'target_driver_employee_id': assignedDriverEmployeeId,
        },
      );

      return FleetVehicle.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      _logger.e('Error fixing vehicle document URLs', e);
      throw Exception('Failed to fix document URLs: ${e.toString()}');
    }
  }
}
