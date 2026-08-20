import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/features/chat/models/chat_room_model.dart';
import 'package:flutter_application_1/features/chat/services/communications_service.dart';
import 'package:flutter_application_1/features/company/models/company_model.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';
import 'package:flutter_application_1/features/operations/models/operations_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunicationsScope {
  final String companyId;
  final String userId;

  const CommunicationsScope({required this.companyId, required this.userId});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CommunicationsScope &&
        other.companyId == companyId &&
        other.userId == userId;
  }

  @override
  int get hashCode => Object.hash(companyId, userId);
}

class CommunicationsState {
  final Company? company;
  final List<Employee> employees;
  final List<ChatContactOption> contacts;
  final List<BroadcastUpdate> announcements;
  final List<ChatRoom> chatRooms;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  const CommunicationsState({
    this.company,
    this.employees = const [],
    this.contacts = const [],
    this.announcements = const [],
    this.chatRooms = const [],
    this.isLoading = true,
    this.isSaving = false,
    this.error,
  });

  CommunicationsState copyWith({
    Company? company,
    List<Employee>? employees,
    List<ChatContactOption>? contacts,
    List<BroadcastUpdate>? announcements,
    List<ChatRoom>? chatRooms,
    bool? isLoading,
    bool? isSaving,
    String? error,
  }) {
    return CommunicationsState(
      company: company ?? this.company,
      employees: employees ?? this.employees,
      contacts: contacts ?? this.contacts,
      announcements: announcements ?? this.announcements,
      chatRooms: chatRooms ?? this.chatRooms,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: error,
    );
  }
}

class CommunicationsNotifier extends StateNotifier<CommunicationsState> {
  final CommunicationsService _service;
  final CommunicationsScope scope;
  final List<RealtimeChannel> _channels = [];

  CommunicationsNotifier(this._service, this.scope)
    : super(const CommunicationsState());

  /// Begins the first read and subscribes to changes.
  ///
  /// **Deliberately not the constructor** — the third notifier in this tree
  /// with the same seam, after `FleetNotifier` and `OperationsNotifier`, and
  /// for the same reason: a constructor that dials out cannot be run without a
  /// network, so the communications hub could not be photographed. `refresh()`
  /// issues a query and `_setupRealtime()` opens channels; against an
  /// unreachable host both leave a connect timer that outlives the widget tree.
  ///
  /// [communicationsProvider] calls this immediately, so the running app is
  /// unchanged.
  void start() {
    _initialize();
  }

  Future<void> _initialize() async {
    await refresh();
    _setupRealtime();
  }

  Future<void> refresh({bool withLoading = true}) async {
    try {
      state = state.copyWith(
        isLoading: withLoading ? true : state.isLoading,
        error: null,
      );

      final company = await _service.getCompany(scope.companyId);
      final employees = await _service.getCompanyEmployees(scope.companyId);
      final announcements = await _service.getAnnouncements(scope.companyId);
      final chatRooms = await _service.getChatRooms(scope.userId);

      final contacts = <ChatContactOption>[
        if (company != null && company.userId != scope.userId)
          ChatContactOption(
            userId: company.userId,
            displayName: _companyOwnerName(company),
            subtitle: 'Company owner',
          ),
        ...employees
            .where((employee) => employee.userId != scope.userId)
            .map(
              (employee) => ChatContactOption(
                userId: employee.userId,
                displayName: employee.fullName,
                subtitle: employee.role?.label ?? 'Team member',
                avatarUrl: employee.profilePhotoUrl,
              ),
            ),
      ];

      state = state.copyWith(
        company: company,
        employees: employees,
        contacts: contacts,
        announcements: announcements,
        chatRooms: chatRooms,
        isLoading: false,
        isSaving: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isSaving: false,
        error: e.toString(),
      );
    }
  }

  Future<void> createAnnouncement({
    required String title,
    required String message,
    required String importance,
  }) async {
    try {
      state = state.copyWith(isSaving: true, error: null);
      await _service.createAnnouncement(
        companyId: scope.companyId,
        userId: scope.userId,
        title: title,
        message: message,
        importance: importance,
      );
      await refresh(withLoading: false);
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      rethrow;
    }
  }

  Future<ChatRoom?> createChatRoom({
    required String name,
    required List<String> participantIds,
  }) async {
    try {
      state = state.copyWith(isSaving: true, error: null);
      final room = await _service.createChatRoom(
        currentUserId: scope.userId,
        name: name,
        participantIds: participantIds,
      );
      await refresh(withLoading: false);
      return room;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      rethrow;
    }
  }

  void _setupRealtime() {
    _disposeChannels();

    _listen(
      SupabaseConfig.client.channel(
        'communications-broadcasts-${scope.companyId}',
      )..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'broadcast_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'company_id',
          value: scope.companyId,
        ),
        callback: (_) => refresh(withLoading: false),
      ),
    );

    _listen(
      SupabaseConfig.client.channel('communications-chat-rooms-${scope.userId}')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_rooms',
          callback: (_) => refresh(withLoading: false),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          callback: (_) => refresh(withLoading: false),
        ),
    );
  }

  void _listen(RealtimeChannel channel) {
    _channels.add(channel);
    channel.subscribe();
  }

  String _companyOwnerName(Company company) {
    final ceoName = [
      company.ceoFirstName,
      company.ceoLastName,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
    return ceoName.isEmpty ? company.companyName : ceoName;
  }

  void _disposeChannels() {
    for (final channel in _channels) {
      channel.unsubscribe();
    }
    _channels.clear();
  }

  @override
  void dispose() {
    _disposeChannels();
    super.dispose();
  }
}

final communicationsServiceProvider = Provider<CommunicationsService>((ref) {
  return CommunicationsService();
});

final communicationsProvider = StateNotifierProvider.autoDispose
    .family<CommunicationsNotifier, CommunicationsState, CommunicationsScope>((
      ref,
      scope,
    ) {
      // `..start()` rather than the constructor doing it — see
      // CommunicationsNotifier. The running app is unchanged.
      return CommunicationsNotifier(
        ref.watch(communicationsServiceProvider),
        scope,
      )..start();
    });
