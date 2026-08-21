// Fixtures for the SHARED screens — the ones every org type and every role
// reaches through the same route.
//
// The third file in this directory, after `portal_capture_fixtures.dart` (the
// dashboards and the working day) and `portal_tail_fixtures.dart` (the tail of
// each org type's own screens). These six are neither: messages, the chat
// thread, notifications, the notification manager, the profile, account
// security, appearance and the employee register belong to nobody in
// particular, which is exactly why nothing had ever photographed them.
//
// Same rule as everywhere else in this directory: **no list is uniform.** A
// group chat and a DM, an ended conversation and a live one, a contact who is
// blocked and one who is not, a notification at every importance, a member at
// every presence, and a KPI whose percentage is `null` because there was
// nothing to count.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/widgets/avatar_stack.dart';
import 'package:flutter_application_1/core/widgets/chat_widget.dart' as cw;
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/chat/models/chat_room_model.dart';
import 'package:flutter_application_1/features/chat/models/messaging_models.dart';
import 'package:flutter_application_1/features/chat/providers/chat_presence_provider.dart';
import 'package:flutter_application_1/features/chat/providers/messaging_providers.dart';
import 'package:flutter_application_1/features/chat/screens/chat_screen.dart';
import 'package:flutter_application_1/features/chat/services/messaging_service.dart';
import 'package:flutter_application_1/features/company/services/employee_register_service.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';
import 'package:flutter_application_1/features/notifications/models/notification_model.dart';
import 'package:flutter_application_1/features/notifications/providers/notification_provider.dart';
import 'package:flutter_application_1/features/notifications/services/notification_service.dart';
import 'package:flutter_application_1/features/company/services/company_service.dart';
import 'package:flutter_application_1/features/profile/models/account_deactivation_request.dart';
import 'package:flutter_application_1/features/profile/services/account_deactivation_service.dart';
import 'package:flutter_application_1/features/profile_setup/models/profile_setup.dart';
import 'package:flutter_application_1/features/profile_setup/providers/profile_setup_provider.dart';
import 'package:flutter_application_1/features/super_admin/data/models/serial_token.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';

import 'portal_capture_fixtures.dart';
import 'screen_fixtures.dart';

DateTime _ago(Duration d) => kCaptureNow.subtract(d);

// ---------------------------------------------------------------------------
// Chat — conversations, contacts and messages
// ---------------------------------------------------------------------------

const kFixtureUserId = 'FIXTURE-user';

/// Four rooms: a live DM, an organisation group, an ordinary group, and a DM
/// that has been ENDED. The last one is the state the composer disappears for,
/// and it had never been in a picture.
final List<ChatConversation> kConversations = [
  ChatConversation(
    id: 'room-dm-1',
    name: 'Thandi Mokoena',
    participantIds: const [kFixtureUserId, 'user-thandi'],
    createdAt: _ago(const Duration(days: 40)),
    lastMessageContent: 'The interlink is at the weighbridge now.',
    lastMessageTimestamp: _ago(const Duration(minutes: 14)),
    lastMessageSenderId: 'user-thandi',
    unreadCount: 2,
  ),
  ChatConversation(
    id: 'room-org-1',
    name: 'Roadhaul Logistics ↔ Iron Hills Mining',
    participantIds: const [kFixtureUserId, 'user-thandi', 'user-sipho'],
    type: ChatRoomType.orgGroup,
    createdAt: _ago(const Duration(days: 120)),
    lastMessageContent: 'Gate opens 05:00 tomorrow, not 06:00.',
    lastMessageTimestamp: _ago(const Duration(hours: 5)),
    lastMessageSenderId: 'user-sipho',
  ),
  ChatConversation(
    id: 'room-group-1',
    name: 'Night shift — load control',
    participantIds: const [kFixtureUserId, 'user-lungile'],
    type: ChatRoomType.group,
    createdAt: _ago(const Duration(days: 9)),
    lastMessageContent: 'Seal 4 on CK 84 RT GP would not close — swapped it.',
    lastMessageTimestamp: _ago(const Duration(days: 1, hours: 2)),
    lastMessageSenderId: kFixtureUserId,
    lastMessageDeliveredAt: _ago(const Duration(days: 1, hours: 2)),
  ),
  ChatConversation(
    id: 'room-dm-ended',
    name: 'Northvale Alloys',
    participantIds: const [kFixtureUserId, 'user-northvale'],
    createdAt: _ago(const Duration(days: 200)),
    lastMessageContent: 'Thanks — closing this off.',
    lastMessageTimestamp: _ago(const Duration(days: 31)),
    lastMessageSenderId: 'user-northvale',
    endedAt: _ago(const Duration(days: 30)),
  ),
];

/// Three groups, because the contacts list groups by `groupLabel` and a single
/// group renders one heading and proves nothing about the rest. One contact is
/// blocked by an expired token — a WARN pill, not an error — and one is the
/// platform account, which draws its own avatar colour.
final List<ChatContact> kChatContacts = [
  ChatContact(
    userId: 'user-thandi',
    displayName: 'Thandi Mokoena',
    companyName: 'Roadhaul Logistics',
    groupKind: ContactGroupKind.myCompany,
    groupLabel: 'My company',
    role: 'admin',
    lastSeenAt: _ago(const Duration(minutes: 3)),
  ),
  ChatContact(
    userId: 'user-lungile',
    displayName: 'Lungile Mahlangu',
    companyName: 'Roadhaul Logistics',
    groupKind: ContactGroupKind.myCompany,
    groupLabel: 'My company',
    role: 'driver',
    lastSeenAt: _ago(const Duration(hours: 9)),
  ),
  ChatContact(
    userId: 'user-minelink',
    displayName: 'MineLink Support',
    groupKind: ContactGroupKind.mineLink,
    groupLabel: 'MineLink',
    isSuperAdmin: true,
    lastSeenAt: _ago(const Duration(minutes: 40)),
  ),
  ChatContact(
    userId: 'user-sipho',
    displayName: 'Sipho Radebe',
    companyName: 'Iron Hills Mining',
    groupKind: ContactGroupKind.connected,
    groupLabel: 'Connected companies',
    role: 'management',
    lastSeenAt: _ago(const Duration(days: 2)),
  ),
  ChatContact(
    userId: 'user-northvale',
    displayName: 'Refilwe Sekhukhune-Modiselle',
    companyName: 'Northvale Alloys',
    groupKind: ContactGroupKind.connected,
    groupLabel: 'Connected companies',
    isBlocked: true,
    blockReason: 'token_expired',
    role: 'admin',
  ),
];

/// The open thread. A mix of mine and theirs, one long enough to wrap, one
/// short enough not to, and a read receipt on the newest of mine.
final Map<String, List<ChatMessage>> kRoomMessages = {
  'room-dm-1': [
    ChatMessage(
      id: 'm-1',
      chatRoomId: 'room-dm-1',
      content: 'Morning — is CK 84 RT GP still booked for the 06:00 slot?',
      senderId: kFixtureUserId,
      senderName: 'Fixture Operator',
      timestamp: _ago(const Duration(hours: 3, minutes: 20)),
      deliveredAt: _ago(const Duration(hours: 3, minutes: 19)),
      readAt: _ago(const Duration(hours: 3, minutes: 10)),
    ),
    ChatMessage(
      id: 'm-2',
      chatRoomId: 'room-dm-1',
      content: 'It is. The driver signed on at 04:40 and the tare weigh is '
          'already captured, so he only needs the gross once the pile is '
          'loaded.',
      senderId: 'user-thandi',
      senderName: 'Thandi Mokoena',
      timestamp: _ago(const Duration(hours: 3)),
    ),
    ChatMessage(
      id: 'm-3',
      chatRoomId: 'room-dm-1',
      content: 'Perfect, thank you.',
      senderId: kFixtureUserId,
      senderName: 'Fixture Operator',
      timestamp: _ago(const Duration(hours: 2, minutes: 55)),
      deliveredAt: _ago(const Duration(hours: 2, minutes: 55)),
      readAt: _ago(const Duration(hours: 2, minutes: 54)),
    ),
    ChatMessage(
      id: 'm-4',
      chatRoomId: 'room-dm-1',
      content: 'The interlink is at the weighbridge now.',
      senderId: 'user-thandi',
      senderName: 'Thandi Mokoena',
      timestamp: _ago(const Duration(minutes: 14)),
    ),
  ],
  'room-org-1': [
    ChatMessage(
      id: 'm-5',
      chatRoomId: 'room-org-1',
      content: 'Gate opens 05:00 tomorrow, not 06:00.',
      senderId: 'user-sipho',
      senderName: 'Sipho Radebe',
      timestamp: _ago(const Duration(hours: 5)),
    ),
  ],
};

/// A [MessagingService] that answers from memory and never dials out.
///
/// The seam is [MessagingService.currentUserId] — a getter over
/// `Supabase.auth.currentUser`, which against the render harness's dummy
/// instance is null. Every bubble in the thread is then "not mine", so the
/// screen photographs one alignment and one colour and the whole right-hand
/// treatment is absent from the picture. [markRoomRead] is overridden for the
/// other reason: the conversation pane calls it during BUILD, so an
/// un-faked service issues a write on every render.
class FixtureMessagingService extends MessagingService {
  FixtureMessagingService({this.userId = kFixtureUserId});

  final String? userId;

  @override
  String? get currentUserId => userId;

  @override
  Future<void> markRoomRead(String roomId) async {}

  @override
  Future<void> markAllDelivered() async {}

  @override
  Future<List<ChatContact>> getContacts() async => kChatContacts;

  @override
  Future<List<ChatConversation>> getConversations() async => kConversations;

  @override
  Future<({String name, String? avatarUrl})> getMyIdentity() async =>
      (name: 'Fixture Operator', avatarUrl: null);
}

/// The legacy per-room thread screen (`/chat/:id`), which takes its room and
/// participants as constructor arguments rather than from a provider.
ChatScreenArgs fixtureChatScreenArgs() => ChatScreenArgs(
      chatRoom: ChatRoom(
        id: 'room-org-1',
        name: 'Roadhaul Logistics ↔ Iron Hills Mining',
        participantIds: const [kFixtureUserId, 'user-thandi', 'user-sipho'],
        createdAt: _ago(const Duration(days: 120)),
        lastMessageContent: 'Gate opens 05:00 tomorrow, not 06:00.',
        lastMessageTimestamp: _ago(const Duration(hours: 5)),
        lastMessageSenderId: 'user-sipho',
      ),
      currentUserId: kFixtureUserId,
      currentUserName: 'Fixture Operator',
      participants: [
        AvatarUser(id: kFixtureUserId, name: 'Fixture Operator', isOnline: true),
        AvatarUser(id: 'user-thandi', name: 'Thandi Mokoena', isOnline: true),
        AvatarUser(id: 'user-sipho', name: 'Sipho Radebe'),
      ],
    );

/// The same thread, in the shape the legacy `ChatWidget` reads.
List<cw.ChatMessage> kLegacyChatMessages = [
  cw.ChatMessage(
    id: 'm-5',
    content: 'Gate opens 05:00 tomorrow, not 06:00. Please tell your night '
        'shift before they set off — the queue at 06:00 will be an hour deep.',
    senderId: 'user-sipho',
    senderName: 'Sipho Radebe',
    timestamp: _ago(const Duration(hours: 5)),
  ),
  cw.ChatMessage(
    id: 'm-6',
    content: 'Understood. Two trucks moved to 05:00.',
    senderId: kFixtureUserId,
    senderName: 'Fixture Operator',
    timestamp: _ago(const Duration(hours: 4, minutes: 40)),
    isRead: true,
  ),
  cw.ChatMessage(
    id: 'm-7',
    content: 'Loading plan attached.',
    senderId: 'user-thandi',
    senderName: 'Thandi Mokoena',
    timestamp: _ago(const Duration(hours: 4)),
    fileUrl: 'https://example.invalid/loading-plan.pdf',
    fileType: 'pdf',
    fileName: 'loading-plan-2026-08.pdf',
  ),
];

/// A [ChatMessagesNotifier] that holds the fixture thread and never dials out.
///
/// `start()` is the seam; overriding it to nothing is what keeps the
/// constructor's query and realtime channel — and the connect timer they leave
/// behind — out of a render.
class FixtureChatMessagesNotifier extends ChatMessagesNotifier {
  FixtureChatMessagesNotifier(super.chatRoomId, List<cw.ChatMessage> seed) {
    state = seed;
  }

  @override
  void start() {}
}

/// A [TypingUsersNotifier] with nobody typing, and no presence channel.
class FixtureTypingUsersNotifier extends TypingUsersNotifier {
  FixtureTypingUsersNotifier(super.chatRoomId);

  @override
  void start() {}
}

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

/// One notification at every importance and every read state, including the
/// two types the model still resolves to `general` because no enum member
/// exists for them yet — the row a tidy fixture would leave out and the one
/// most likely to render an empty icon well.
final List<AppNotification> kNotifications = [
  AppNotification(
    id: 'n-1',
    userId: kFixtureUserId,
    title: 'Weight variance on TRP-004182',
    message: 'Mine net 36.22 t against 34.90 t delivered — a 1.32 t shortfall '
        'on the Richards Bay leg. Open the reconciliation to dispute or accept.',
    type: NotificationType.reconDispute,
    createdAt: _ago(const Duration(minutes: 26)),
    importance: NotificationImportance.extreme,
    actionedBy: 'Sipho Radebe',
  ),
  AppNotification(
    id: 'n-2',
    userId: kFixtureUserId,
    title: 'Stockpile ready to collect',
    message: '2 full load(s) ready at Iron Hills Mining for Atlas Buyer Group.',
    type: NotificationType.general,
    createdAt: _ago(const Duration(hours: 2)),
    importance: NotificationImportance.high,
  ),
  AppNotification(
    id: 'n-3',
    userId: kFixtureUserId,
    title: 'Driver Assigned',
    message: 'Lungile Mahlangu is assigned to CK 84 RT GP to collect Chrome '
        'from Iron Hills Mining → Richards Bay.',
    type: NotificationType.fleetDriverAssigned,
    createdAt: _ago(const Duration(hours: 7)),
    isRead: true,
    actionedBy: 'Thandi Mokoena',
  ),
  AppNotification(
    id: 'n-4',
    userId: kFixtureUserId,
    title: 'Token expiring soon',
    message: 'Your company serial token expires in 12 days. Renew it before it '
        'lapses or messaging outside your own company will stop.',
    type: NotificationType.tokenExpiringSoon,
    createdAt: _ago(const Duration(days: 1, hours: 4)),
    importance: NotificationImportance.high,
    isRead: true,
  ),
  AppNotification(
    id: 'n-5',
    userId: kFixtureUserId,
    title: 'Profile updated',
    message: 'Your signature was replaced.',
    type: NotificationType.profileUpdate,
    createdAt: _ago(const Duration(days: 6)),
    isRead: true,
  ),
  AppNotification(
    id: 'n-6',
    userId: kFixtureUserId,
    title: 'Truck checked in',
    message: 'JD 22 PL MP arrived at Iron Hills Mining and is in the loading '
        'queue.',
    // `truck_checked_in` has no enum member — the model resolves it to
    // `general`, which is a documented gap (see NotificationType.fromString).
    // It belongs in the picture precisely because it is the row that renders
    // with the fallback icon.
    type: NotificationType.general,
    createdAt: _ago(const Duration(days: 12)),
    isRead: true,
  ),
];

/// A [NotificationNotifier] holding a fixed list, with nothing behind it.
///
/// Two things had to be true at once. The state has to be PINNED, for the
/// reason `FixtureCompanyNotifier` records — the constructor registers an auth
/// listener with `fireImmediately: true` and the callback would overwrite the
/// fixture a microtask later. And the notifier must not open a realtime
/// channel: `_setupRealtime` is private and unconditional, reached whenever the
/// listener sees a signed-in user, and a channel opened against the harness's
/// dummy Supabase instance leaves a connect timer that outlives the tree and
/// fails the golden AFTER it has been written.
///
/// So it is handed an auth notifier of its OWN with no session. That is the
/// one branch of `_handleAuthStateChanged` that returns before it loads or
/// subscribes, and the state it would have loaded is supplied directly.
/// A [NotificationService] that answers from memory.
///
/// The pinned notifier below covers the state, but not the CALLS:
/// `NotificationManagementScreen.initState` fires
/// `loadNotificationsForManagementScreen` in a microtask, which reaches the
/// service directly. Against the harness's dummy instance that is a real HTTP
/// attempt from inside a render.
class FixtureNotificationService extends NotificationService {
  @override
  Future<List<AppNotification>> getNotificationsForUser(String userId) async =>
      kNotifications;

  @override
  Future<List<AppNotification>> getNotificationsForManagementScreen(
    String userId,
    UserRole? role,
    OrgType? orgType,
  ) async =>
      kNotifications;

  @override
  Future<void> markNotificationReadStatus(
          String notificationId, bool isRead) async {}

  @override
  Future<void> markAllNotificationsAsRead(String userId) async {}

  @override
  Future<void> deleteNotification(String notificationId) async {}
}

class FixtureNotificationNotifier extends NotificationNotifier {
  FixtureNotificationNotifier(
    super.notificationService,
    super.authStateNotifier, {
    required NotificationState fixture,
  }) {
    state = fixture;
    _pinned = true;
  }

  bool _pinned = false;

  @override
  set state(NotificationState value) {
    if (_pinned) return;
    super.state = value;
  }
}

// ---------------------------------------------------------------------------
// The employee register
// ---------------------------------------------------------------------------

Employee _member({
  required String id,
  required String userId,
  required String first,
  required String last,
  UserRole? role,
  String status = 'active',
}) =>
    Employee(
      id: id,
      userId: userId,
      firstName: first,
      lastName: last,
      whatsappNumber: '+27 82 555 0101',
      companyId: 'FIXTURE-company',
      role: role,
      status: status,
      createdAt: _ago(const Duration(days: 400)),
    );

/// One member per role bucket, plus the three the design has to survive: a name
/// long enough to need the row's whole width, a member whose presence never
/// resolved at all (neither "signature on file" nor "missing"), and one with no
/// role, who falls through to "Other".
final List<RegisterMember> kRegisterMembers = [
  RegisterMember(
    _member(
      id: 'reg-1',
      userId: 'user-thandi',
      first: 'Thandi',
      last: 'Mokoena',
      role: UserRole.admin,
    ),
    MemberPresence(
      userId: 'user-thandi',
      lastSeenAt: _ago(const Duration(minutes: 3)),
      hasSignature: true,
    ),
  ),
  RegisterMember(
    _member(
      id: 'reg-2',
      userId: 'user-nomvula',
      first: 'Nomvula',
      last: 'Mthembu-Vandenberghe',
      role: UserRole.management,
    ),
    MemberPresence(
      userId: 'user-nomvula',
      lastSeenAt: _ago(const Duration(minutes: 11)),
      hasSignature: true,
    ),
  ),
  RegisterMember(
    _member(
      id: 'reg-3',
      userId: 'user-johannes',
      first: 'Johannes',
      last: 'van der Merwe',
      role: UserRole.supervisorForeman,
    ),
    MemberPresence(
      userId: 'user-johannes',
      lastSeenAt: _ago(const Duration(hours: 20)),
      hasSignature: false,
    ),
  ),
  RegisterMember(
    _member(
      id: 'reg-4',
      userId: 'user-thandeka',
      first: 'Thandeka',
      last: 'Nkosi',
      role: UserRole.controllerWB,
    ),
    null,
  ),
  RegisterMember(
    _member(
      id: 'reg-5',
      userId: 'user-pieter',
      first: 'Pieter',
      last: 'Botha',
      role: UserRole.security,
      status: 'pending',
    ),
    MemberPresence(
      userId: 'user-pieter',
      lastSeenAt: _ago(const Duration(days: 4)),
      hasSignature: true,
    ),
  ),
  RegisterMember(
    _member(
      id: 'reg-6',
      userId: 'user-lungile',
      first: 'Lungile',
      last: 'Mahlangu',
      role: UserRole.driver,
    ),
    MemberPresence(
      userId: 'user-lungile',
      lastSeenAt: _ago(const Duration(hours: 9)),
      hasSignature: false,
    ),
  ),
  RegisterMember(
    _member(
      id: 'reg-7',
      userId: 'user-unassigned',
      first: 'Unassigned',
      last: 'Employee',
    ),
    null,
  ),
];

/// The percentages the section headers carry. One is `null` — nothing to count
/// — and must render as a muted dash rather than 0%.
final RegisterKpiBundle kRegisterKpis = RegisterKpiBundle(
  const {
    RegisterRoleGroups.admins:
        RegisterKpi('RECONS CLOSED', 42, '3 reconciliation disputes open'),
    RegisterRoleGroups.supervisors: RegisterKpi(
        'STOCKPILES UPDATED', null, 'no stockpiles with product'),
    RegisterRoleGroups.loadControllers: RegisterKpi(
        'LOADS RECORDED', 88, '1 truck arrived, load not recorded'),
    RegisterRoleGroups.security:
        RegisterKpi('ARRIVALS CLOSED OUT', 61, '4 trucks arrived, not marked left'),
    RegisterRoleGroups.drivers:
        RegisterKpi('PODS UPLOADED', 100, '0 trips missing POD'),
  },
  [
    RegisterComplianceDoc(
      ownerType: 'employee',
      ownerId: 'reg-6',
      docType: 'drivers_licence',
      expiresAt: _ago(const Duration(days: -12)),
    ),
    RegisterComplianceDoc(
      ownerType: 'company',
      ownerId: null,
      docType: 'mining_right',
      expiresAt: _ago(const Duration(days: 5)),
    ),
  ],
);

/// The compliance items this product actually asks a company for — the same
/// vocabulary `compliance_documents.label` holds.
const List<String> _missingLabels = [
  'Tax clearance certificate',
  'Public liability insurance',
  'BEE certificate',
  'Company registration (CIPC)',
  'Proof of banking details',
];

ProfileSetup _setup({
  required int percent,
  int missing = 0,
  int expiring = 0,
  int expired = 0,
  String? audience = 'employee',
}) =>
    ProfileSetup(
      audience: audience,
      items: const [],
      summary: ProfileSetupSummary(
        totalItems: 10,
        completeItems: percent ~/ 10,
        requiredTotal: 5,
        requiredComplete: 5 - missing,
        completionPercent: percent,
        // REAL LABELS, because that is what the server sends. The RPC builds
        // `missing_required` from `v_r.label` — the human name of the
        // compliance item — and the setup dialog prints each entry verbatim.
        // This fixture used to emit `item_0`, so the one picture ever taken of
        // that dialog showed a reader "Item_0" and invited a fix to a fault
        // that does not exist.
        missingRequired: [
          for (var i = 0; i < missing; i++) _missingLabels[i % _missingLabels.length],
        ],
        missingCount: missing,
        expiringCount: expiring,
        expiredCount: expired,
      ),
    );

/// One setup state per member, so the register's whole chip vocabulary is on
/// screen at once — finished, part-finished, expired, renewals-due, and the two
/// that must print NOTHING rather than guess: an account with no setup to
/// complete, and a read the server refused.
final List<Override> _registerSetupOverrides = [
  employeeProfileSetupProvider('reg-1')
      .overrideWith((ref) async => _setup(percent: 100)),
  employeeProfileSetupProvider('reg-2')
      .overrideWith((ref) async => _setup(percent: 40, missing: 3)),
  employeeProfileSetupProvider('reg-3')
      .overrideWith((ref) async => _setup(percent: 80, expired: 1)),
  employeeProfileSetupProvider('reg-4')
      .overrideWith((ref) async => _setup(percent: 90, expiring: 2)),
  employeeProfileSetupProvider('reg-5')
      .overrideWith((ref) async => _setup(percent: 0, missing: 5)),
  employeeProfileSetupProvider('reg-6')
      .overrideWith((ref) async => _setup(percent: 60, missing: 2)),
  employeeProfileSetupProvider('reg-7')
      .overrideWith((ref) async => _setup(percent: 100, audience: null)),
];

// ---------------------------------------------------------------------------
// The profile screen
// ---------------------------------------------------------------------------

/// The signed-in account's own setup state. Deliberately incomplete: the card
/// on the profile screen is a progress summary, and a fixture at 100% renders
/// the shortest, least informative version of it.
final ProfileSetup kMyProfileSetup =
    _setup(percent: 70, missing: 1, expiring: 1, audience: 'company');

/// The same state for a DRIVER, whose setup is their own — licence, PrDP,
/// medical — not the company's paperwork.
///
/// `kMyProfileSetup` above is `audience: 'company'`, which is right for the
/// profile screen of a company admin and wrong under any driver render: the
/// prompt dialog keys its title off exactly that field, so it told a driver to
/// "Complete your **company** account setup".
final ProfileSetup kDriverProfileSetup =
    _setup(percent: 70, missing: 1, expiring: 1, audience: 'employee');

/// Install over [sharedTailOverrides] for a driver-side render.
List<Override> driverProfileSetupOverride() => [
      myProfileSetupProvider.overrideWith((ref) async => kDriverProfileSetup),
    ];

/// The company's serial tokens, read by the profile screen's expiry notice.
final List<SerialToken> kProfileTokens = [
  SerialToken(
    id: 'tok-fixture-1',
    organizationId: 'FIXTURE-company',
    organizationName: 'Fixture Haulage (Pty) Ltd',
    organizationType: 'transporter',
    tokenHash: 'hash-fixture-1',
    tokenPreview: 'MLK-9C40',
    validDays: 365,
    issuedAt: _ago(const Duration(days: 300)),
    // Sixty-five days out — inside the expiry notice's warning window, so the
    // card renders its countdown rather than its quiet state.
    expiresAt: _ago(const Duration(days: -65)),
    seatLimit: 5,
    status: 'active',
    generatedByUserId: 'admin-1',
    generatedByEmail: 'jean@cyberhouse.co.za',
    generatedByPlatformRole: 'super_global_serial_admin_main',
    createdAt: _ago(const Duration(days: 300)),
    updatedAt: _ago(const Duration(days: 300)),
  ),
];

// ---------------------------------------------------------------------------
// Account deactivation
// ---------------------------------------------------------------------------

/// Nobody has asked, which is the state every reader of the card is in until
/// they do — and the one that renders the offer rather than a status.
///
/// Faked at all because the card used to CONSTRUCT its Supabase service, so
/// both screens carrying it photographed a red "Could not load your
/// deactivation status" where the design was supposed to be.
class FixtureAccountDeactivationService implements AccountDeactivationService {
  FixtureAccountDeactivationService({this.existing});

  final AccountDeactivationRequest? existing;

  @override
  Future<AccountDeactivationRequest?> current() async => existing;

  @override
  Future<void> reauthenticate(String password) async {}

  @override
  Future<void> request(String? reason) async {}

  @override
  Future<void> cancel() async {}
}

// ---------------------------------------------------------------------------
// The override list
// ---------------------------------------------------------------------------

/// Install alongside [companyScopeOverrides] — this list adds to it.
List<Override> sharedTailOverrides({
  String? activeRoomId = 'room-dm-1',
}) =>
    [
      // --- chat ---
      messagingServiceProvider
          .overrideWithValue(FixtureMessagingService()),
      myChatRoleProvider.overrideWith((ref) async => 'admin'),
      chatConversationsProvider
          .overrideWith((ref) => Stream.value(kConversations)),
      chatContactsProvider.overrideWith((ref) async => kChatContacts),
      roomMessagesProvider.overrideWith(
          (ref, roomId) => Stream.value(kRoomMessages[roomId] ?? const [])),
      activeRoomProvider.overrideWith((ref) => activeRoomId == null
          ? null
          : kConversations.firstWhere((c) => c.id == activeRoomId)),
      chatMessagesProvider.overrideWith((ref, roomId) =>
          FixtureChatMessagesNotifier(roomId, kLegacyChatMessages)),
      typingUsersProvider
          .overrideWith((ref, roomId) => FixtureTypingUsersNotifier(roomId)),

      // --- presence ---
      //
      // Overridden as VALUES so `presenceProvider` — a StateNotifier that opens
      // a realtime channel from its constructor — is never watched, and
      // therefore never built.
      onlineUsersProvider.overrideWithValue(const {'user-thandi'}),
      presenceLastSeenProvider.overrideWithValue({
        'user-nomvula': _ago(const Duration(minutes: 11)),
      }),

      // --- notifications ---
      notificationServiceProvider.overrideWithValue(FixtureNotificationService()),
      notificationProvider.overrideWith((ref) => FixtureNotificationNotifier(
            ref.watch(notificationServiceProvider),
            signedOutAuthNotifier(ref),
            fixture: NotificationState(
              notifications: kNotifications,
              managementNotifications: kNotifications,
              unreadCount: kNotifications.where((n) => !n.isRead).length,
            ),
          )),

      // --- the org-group dialog ---
      //
      // `New group` on the Messages header opens a dialog whose whole content
      // is a picker over `companyDirectoryProvider`. Un-overridden it renders
      // "Could not load the company list" — an error card where the design
      // is, which CLAUDE.md §10.5 says is not the dialog photographed at all.
      companyDirectoryProvider.overrideWith((ref) async => kJoinableCompanies),

      // --- the employee register ---
      companyRegisterProvider.overrideWith((ref, _) async => kRegisterMembers),
      companyDriverTrucksProvider.overrideWith(
          (ref, _) async => const {'user-lungile': 'CK 84 RT GP'}),
      companyRegisterKpisProvider.overrideWith((ref, _) async => kRegisterKpis),
      registerCompanyProvider
          .overrideWith((ref, _) async => fixtureCompany()),
      ..._registerSetupOverrides,

      // --- the profile screen ---
      myProfileSetupProvider.overrideWith((ref) async => kMyProfileSetup),
      organizationTokensProvider
          .overrideWith((ref, _) async => kProfileTokens),
      accountDeactivationServiceProvider
          .overrideWithValue(FixtureAccountDeactivationService()),
      accountEmailOverride(),
    ];
