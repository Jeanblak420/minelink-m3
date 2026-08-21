import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/widgets/avatar_stack.dart';
import 'package:flutter_application_1/core/widgets/m3_dropdown_field.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/chat/models/chat_room_model.dart';
import 'package:flutter_application_1/features/chat/providers/communications_provider.dart';
import 'package:flutter_application_1/features/company/models/company_model.dart';
import 'package:flutter_application_1/features/company/providers/company_provider.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

class CommunicationsHubScreen extends ConsumerWidget {
  const CommunicationsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final companyState = ref.watch(companyProvider);
    final employeeState = ref.watch(employeeProvider);
    final access = _CommunicationsAccess.fromState(
      authStateUserId: authState.user?.id,
      userType: authState.userType,
      company: companyState.company,
      employeeCompany: employeeState.company,
      employee: employeeState.employee,
    );

    if (authState.user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (access == null) {
      // No `Scaffold(appBar:)`. `/communications` is a leaf of the portal
      // `ShellRoute`, which has already drawn a top bar carrying the section
      // name — a second one beneath it repeats the same words.
      return const MlEmptyState(
        icon: Icons.forum_outlined,
        title: 'Communications Hub',
        message: 'A linked company profile is required before live '
            'announcements and chat become available.',
      );
    }

    final scope = CommunicationsScope(
      companyId: access.company.id,
      userId: access.userId,
    );
    final state = ref.watch(communicationsProvider(scope));
    final notifier = ref.read(communicationsProvider(scope).notifier);

    return DefaultTabController(
      length: 2,
      child: Column(
        // A Column CENTRES its children and sizes each to its own content
        // unless told otherwise, so the hero card floated in the middle of
        // the page at whatever width its chips happened to need, while the
        // tabs and the list below it — which stretch for their own reasons —
        // ran the full width. One screen, two margins.
        //
        // Nothing overflowed and no test failed. It was visible the moment
        // the screen was first photographed, on 2026-08-20, and invisible
        // until then.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: MlPageHeader(
              title: 'Communications Hub',
              description: 'Company announcements and team conversations.',
              actions: [
                MlButton.ghost(
                  label: 'Refresh',
                  icon: Icons.refresh,
                  compact: true,
                  onPressed:
                      state.isLoading ? null : () => notifier.refresh(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
            child: MlCard(
              hero: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    access.company.companyName,
                    style: context.mlText.titleLarge.copyWith(
                      color: MlSemantic.of(context).textStrong,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  MlCard.heroTitleRule(),
                  Text(
                    'Live announcements and team conversations for ${access.currentUserName}.',
                    style: context.mlText.bodyLarge.copyWith(
                      color: MlSemantic.of(context).textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // A Wrap lays every child out against UNBOUNDED width, so
                  // a chip wider than the Wrap does not wrap — it overflows.
                  // `maxWidth` hands each chip the row's real width to
                  // ellipsize its label inside.
                  LayoutBuilder(
                    builder: (context, c) => Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _CommunicationChip(
                          label: 'Contacts',
                          value: state.contacts.length.toString(),
                          icon: Icons.people_outline,
                          tone: MlTone.accent,
                          maxWidth: c.maxWidth,
                        ),
                        _CommunicationChip(
                          label: 'Announcements',
                          value: state.announcements.length.toString(),
                          icon: Icons.campaign_outlined,
                          tone: MlTone.warn,
                          maxWidth: c.maxWidth,
                        ),
                        _CommunicationChip(
                          label: 'Chat rooms',
                          value: state.chatRooms.length.toString(),
                          icon: Icons.forum_outlined,
                          tone: MlTone.transit,
                          maxWidth: c.maxWidth,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TabBar.secondary(
                tabs: const [
                  Tab(
                    icon: Icon(Icons.campaign_outlined),
                    text: 'Announcements',
                  ),
                  Tab(icon: Icon(Icons.forum_outlined), text: 'Chat Rooms'),
                ],
              ),
            ),
          ),
          if (state.error != null)
            Builder(
              builder: (context) {
                final tone = MlTone.error.colors(
                  Theme.of(context).brightness,
                );
                return Container(
                  margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tone.bg,
                    borderRadius: BorderRadius.circular(MlTokens.rMd),
                    border: Border.all(
                      color: tone.fg.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: tone.fg, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          state.error!,
                          style: context.mlText.bodyMedium.copyWith(
                            color: tone.fg,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          Expanded(
            child: TabBarView(
              children: [
                _AnnouncementsTab(
                  state: state,
                  canCreate: access.canCreateAnnouncements,
                  onCreate: () => _showAnnouncementDialog(context, notifier),
                ),
                _ChatRoomsTab(
                  access: access,
                  state: state,
                  onCreate: () =>
                      _showCreateChatRoomDialog(context, state, notifier),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunicationsAccess {
  final String userId;
  final Company company;
  final Employee? employee;
  final bool isCompanyAccount;

  const _CommunicationsAccess({
    required this.userId,
    required this.company,
    required this.employee,
    required this.isCompanyAccount,
  });

  static _CommunicationsAccess? fromState({
    required String? authStateUserId,
    required UserType? userType,
    required Company? company,
    required Company? employeeCompany,
    required Employee? employee,
  }) {
    if (authStateUserId == null) {
      return null;
    }

    if (userType?.isCompany == true && company != null) {
      return _CommunicationsAccess(
        userId: authStateUserId,
        company: company,
        employee: null,
        isCompanyAccount: true,
      );
    }

    if (userType?.isEmployee == true &&
        employeeCompany != null &&
        employee != null &&
        employee.status == 'active') {
      return _CommunicationsAccess(
        userId: authStateUserId,
        company: employeeCompany,
        employee: employee,
        isCompanyAccount: false,
      );
    }

    return null;
  }

  bool get canCreateAnnouncements {
    if (isCompanyAccount) {
      return true;
    }

    return employee?.role == UserRole.admin ||
        employee?.role == UserRole.management;
  }

  String get currentUserName {
    if (isCompanyAccount) {
      final ceoName = [
        company.ceoFirstName,
        company.ceoLastName,
      ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
      return ceoName.isEmpty ? company.companyName : ceoName;
    }

    return employee?.fullName ?? company.companyName;
  }

  String? get currentUserAvatarUrl {
    if (isCompanyAccount) {
      return company.logoUrl;
    }
    return employee?.profilePhotoUrl;
  }
}

class _CommunicationChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final MlTone tone;

  /// The width the chip must fit inside — the enclosing Wrap's own width.
  /// Required rather than optional: a Wrap gives its children unbounded width,
  /// so a chip built without this cannot know when to ellipsize and will
  /// silently overflow instead.
  final double maxWidth;

  const _CommunicationChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.maxWidth,
    this.tone = MlTone.accent,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
      decoration: BoxDecoration(
        color: semantic.surfaceCard,
        borderRadius: BorderRadius.circular(MlTokens.rPill),
        border: Border.all(color: semantic.borderCard),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MlIconWell(icon: icon, tone: tone, size: 28, radius: 9),
          const SizedBox(width: 9),
          Text(
            '$value ',
            style: context.mlText.code(
              color: semantic.textStrong,
              size: 14,
              weight: FontWeight.w700,
            ),
          ),
          // The COUNT above is never allowed to shrink; the word after it is.
          // A chip reading "12 Announcem…" is still usable, one reading
          // "1 Announcements" is wrong. These sit in a Wrap, which lays every
          // child out against UNBOUNDED width — so a chip wider than the Wrap
          // does not wrap, it overflows, and at 360px with text scale 2.0
          // "Announcements" did exactly that by 37px. The cap comes from the
          // Wrap's own width (see the LayoutBuilder at the call site).
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.mlText.titleSmall.copyWith(
                color: semantic.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementsTab extends StatelessWidget {
  final CommunicationsState state;
  final bool canCreate;
  final VoidCallback onCreate;

  const _AnnouncementsTab({
    required this.state,
    required this.canCreate,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      children: [
        MlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MlSectionTitle(
                'Announcements',
                meta: mlCount(state.announcements.length, 'announcement'),
                icon: Icons.campaign_outlined,
                margin: EdgeInsets.only(bottom: 8),
              ),
              Text(
                'Publish live updates to the team and keep everyone aligned in real time.',
                style: context.mlText.bodyMedium.copyWith(
                  color: semantic.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              MlButton.primary(
                label: 'New announcement',
                icon: Icons.add_comment_outlined,
                onPressed: canCreate ? onCreate : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (state.announcements.isEmpty)
          const _EmptyCommunicationsState(
            icon: Icons.campaign_outlined,
            title: 'No announcements yet',
            message:
                'Create the first live announcement to start broadcasting updates to the team.',
          )
        else
          ...state.announcements.map((announcement) {
            final tone = _importanceTone(announcement.importance);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MlCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MlIconWell(
                      icon: _importanceIcon(announcement.importance),
                      tone: tone,
                      size: 42,
                      radius: 12,
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  announcement.title,
                                  style: context.mlText.titleMedium.copyWith(
                                    color: semantic.textStrong,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (announcement.importance != 'normal') ...[
                                const SizedBox(width: 8),
                                MlStatusBadge(
                                  label: announcement.importance,
                                  tone: tone,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            announcement.message,
                            style: context.mlText.bodyMedium.copyWith(
                              color: semantic.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            MlTime.stamp(announcement.timestamp),
                            style: context.mlText.code(
                              color: semantic.textFaint,
                              size: 12,
                              weight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  IconData _importanceIcon(String value) {
    switch (value) {
      case 'extreme':
        return Icons.warning_amber_rounded;
      case 'high':
        return Icons.priority_high_rounded;
      default:
        return Icons.campaign_outlined;
    }
  }

  MlTone _importanceTone(String value) {
    switch (value) {
      case 'extreme':
        return MlTone.error;
      case 'high':
        return MlTone.warn;
      default:
        return MlTone.accent;
    }
  }
}

class _ChatRoomsTab extends StatelessWidget {
  final _CommunicationsAccess access;
  final CommunicationsState state;
  final VoidCallback onCreate;

  const _ChatRoomsTab({
    required this.access,
    required this.state,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      children: [
        MlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MlSectionTitle(
                'Chat Rooms',
                meta: mlCount(state.chatRooms.length, 'room'),
                icon: Icons.forum_outlined,
                margin: EdgeInsets.only(bottom: 8),
              ),
              Text(
                'Create focused rooms, collaborate live, and step straight into realtime messaging.',
                style: context.mlText.bodyMedium.copyWith(
                  color: semantic.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              MlButton.primary(
                label: 'New chat room',
                icon: Icons.add_comment_outlined,
                onPressed: onCreate,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (state.chatRooms.isEmpty)
          const _EmptyCommunicationsState(
            icon: Icons.forum_outlined,
            title: 'No chat rooms yet',
            message:
                'Create the first chat room to begin realtime conversations with your company team.',
          )
        else
          ...state.chatRooms.map((room) {
            final participants = _participantsForRoom(room, access, state);
            final hasLast =
                room.lastMessageContent?.trim().isNotEmpty == true;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MlCard(
                padding: const EdgeInsets.all(16),
                onTap: () {
                  // Push keeps chat on the shell stack so pop/back returns to this hub.
                  context.push(
                    '/chat/${room.id}',
                    extra: ChatScreenArgs(
                      chatRoom: room,
                      currentUserId: access.userId,
                      currentUserName: access.currentUserName,
                      currentUserAvatarUrl: access.currentUserAvatarUrl,
                      participants: participants,
                    ),
                  );
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MlIconWell(
                      icon: Icons.forum_outlined,
                      tone: MlTone.accent,
                      size: 42,
                      radius: 12,
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  room.name,
                                  style: context.mlText.titleMedium.copyWith(
                                    color: semantic.textStrong,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                MlTime.stamp(
                                    room.lastMessageTimestamp ?? room.createdAt),
                                style: context.mlText.code(
                                  color: semantic.textFaint,
                                  size: 11,
                                  weight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasLast
                                ? room.lastMessageContent!
                                : 'No messages yet',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.mlText.bodyMedium.copyWith(
                              color: semantic.textMuted,
                              fontStyle: hasLast ? FontStyle.normal : FontStyle.italic,
                            ),
                          ),
                          if (participants.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            AvatarStack(
                              users: participants,
                              avatarSize: 30,
                              maxDisplayed: 4,
                              showOnlineIndicator: false,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  List<AvatarUser> _participantsForRoom(
    ChatRoom room,
    _CommunicationsAccess access,
    CommunicationsState state,
  ) {
    final participants = <AvatarUser>[];

    for (final userId in room.participantIds) {
      if (userId == access.userId) {
        participants.add(
          AvatarUser(
            id: userId,
            name: access.currentUserName,
            avatarUrl: access.currentUserAvatarUrl,
            status: 'You',
          ),
        );
        continue;
      }

      final contact = state.contacts.cast<ChatContactOption?>().firstWhere(
        (entry) => entry?.userId == userId,
        orElse: () => null,
      );

      participants.add(
        AvatarUser(
          id: userId,
          name: contact?.displayName ?? 'Participant',
          avatarUrl: contact?.avatarUrl,
          status: contact?.subtitle,
        ),
      );
    }

    return participants;
  }
}

class _EmptyCommunicationsState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyCommunicationsState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return MlCard(
      padding: const EdgeInsets.all(12),
      child: MlEmptyState(icon: icon, title: title, message: message),
    );
  }
}

Future<void> _showAnnouncementDialog(
  BuildContext context,
  CommunicationsNotifier notifier,
) async {
  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final messageController = TextEditingController();
  String importance = 'normal';

  final didSubmit = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: const Text('New Announcement'),
            content: Form(
              key: formKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Title'),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Title is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: messageController,
                        decoration: const InputDecoration(labelText: 'Message'),
                        minLines: 4,
                        maxLines: 6,
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Message is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      M3DropdownField<String>(
                        initialValue: importance,
                        label: 'Importance',
                        entries: const [
                          DropdownMenuEntry(
                            value: 'normal',
                            label: 'Normal',
                          ),
                          DropdownMenuEntry(value: 'high', label: 'High'),
                          DropdownMenuEntry(
                            value: 'extreme',
                            label: 'Extreme',
                          ),
                        ],
                        onSelected: (value) =>
                            setState(() => importance = value ?? importance),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) {
                    return;
                  }
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Publish'),
              ),
            ],
          );
        },
      );
    },
  );

  if (didSubmit != true || !context.mounted) {
    return;
  }

  try {
    await notifier.createAnnouncement(
      title: titleController.text,
      message: messageController.text,
      importance: importance,
    );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Announcement published')));
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not publish announcement. ${friendlyError(error)}')),
    );
  }
}

Future<void> _showCreateChatRoomDialog(
  BuildContext context,
  CommunicationsState state,
  CommunicationsNotifier notifier,
) async {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final selectedIds = <String>{};

  final didSubmit = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: const Text('New Chat Room'),
            content: Form(
              key: formKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Room name',
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Room name is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Participants',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...state.contacts.map((contact) {
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: selectedIds.contains(contact.userId),
                          title: Text(contact.displayName),
                          subtitle: contact.subtitle == null
                              ? null
                              : Text(contact.subtitle!),
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                selectedIds.add(contact.userId);
                              } else {
                                selectedIds.remove(contact.userId);
                              }
                            });
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) {
                    return;
                  }
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Create room'),
              ),
            ],
          );
        },
      );
    },
  );

  if (didSubmit != true || !context.mounted) {
    return;
  }

  try {
    final room = await notifier.createChatRoom(
      name: nameController.text,
      participantIds: selectedIds.toList(),
    );

    if (!context.mounted || room == null) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Chat room created')));
  } catch (error) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not create chat room. ${friendlyError(error)}')),
    );
  }
}
