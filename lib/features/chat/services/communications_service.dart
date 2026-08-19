import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/services/storage_asset_service.dart';
import 'package:flutter_application_1/features/chat/models/chat_room_model.dart';
import 'package:flutter_application_1/features/company/models/company_model.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';
import 'package:flutter_application_1/features/operations/models/operations_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunicationsService {
  final SupabaseClient _supabase = SupabaseConfig.client;
  final StorageAssetService _storageAssetService = StorageAssetService();

  Future<Company?> getCompany(String companyId) async {
    final response = await _supabase
        .from('companies')
        .select()
        .eq('id', companyId)
        .maybeSingle();
    if (response == null) {
      return null;
    }
    final resolvedRecord = await _storageAssetService.resolveCompanyRecord(
      response,
    );
    return Company.fromJson(resolvedRecord);
  }

  Future<List<Employee>> getCompanyEmployees(String companyId) async {
    final response = await _supabase.rpc(
      'list_company_chat_contacts',
      params: {'target_company_id': companyId},
    );

    final resolvedRecords = await _storageAssetService.resolveEmployeeRecords(
      (response as List).map((json) => Map<String, dynamic>.from(json as Map)),
    );

    return resolvedRecords.map(Employee.fromJson).toList();
  }

  Future<List<BroadcastUpdate>> getAnnouncements(String companyId) async {
    final response = await _supabase
        .from('broadcast_messages')
        .select()
        .contains('payload', {'company_id': companyId})
        .order('timestamp', ascending: false)
        .limit(80);

    return response.map(BroadcastUpdate.fromJson).toList();
  }

  Future<BroadcastUpdate> createAnnouncement({
    required String companyId,
    required String userId,
    required String title,
    required String message,
    required String importance,
  }) async {
    final response = await _supabase
        .from('broadcast_messages')
        .insert({
          'event': 'company_announcement',
          'created_by': userId,
          'payload': {
            'company_id': companyId,
            'title': title.trim(),
            'message': message.trim(),
            'importance': importance,
          },
        })
        .select()
        .single();

    return BroadcastUpdate.fromJson(response);
  }

  Future<List<ChatRoom>> getChatRooms(String userId) async {
    final response = await _supabase.from('chat_rooms').select().contains(
      'participant_ids',
      [userId],
    );

    final rooms = response.map(ChatRoom.fromJson).toList();
    rooms.sort((a, b) {
      final aDate = a.lastMessageTimestamp ?? a.createdAt;
      final bDate = b.lastMessageTimestamp ?? b.createdAt;
      return bDate.compareTo(aDate);
    });
    return rooms;
  }

  Future<ChatRoom> createChatRoom({
    required String currentUserId,
    required String name,
    required List<String> participantIds,
  }) async {
    final distinctParticipants = {
      currentUserId,
      ...participantIds.where((id) => id.isNotEmpty),
    }.toList();

    final response = await _supabase
        .from('chat_rooms')
        .insert({'name': name.trim(), 'participant_ids': distinctParticipants})
        .select()
        .single();

    return ChatRoom.fromJson(response);
  }
}
