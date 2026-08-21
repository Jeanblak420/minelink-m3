import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';
import 'package:flutter_application_1/features/chat/models/messaging_models.dart';
import 'package:flutter_application_1/features/chat/providers/messaging_providers.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/chat/widgets/org_group_dialog.dart';

/// Full MineLink Messages surface (desktop two-pane): a scoped contacts /
/// conversations sidebar on the left and the active conversation on the right.
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  int _sidebarTab = 0; // 0 = Chats, 1 = People

  /// Who may start an organisation group (S8-3 / P10-08).
  ///
  /// `create_org_group` refuses anyone who is not an owner, management or
  /// admin, so the action is shown to exactly those roles rather than offered
  /// and then refused — this repo has a guard against dead CTAs for a reason.
  /// Hiding it is presentation; the database is the boundary.
  bool _canStartGroup(WidgetRef ref) {
    final role = ref.watch(myChatRoleProvider).valueOrNull;
    return role == 'owner' || role == 'management' || role == 'admin';
  }

  /// Below this the two panes cannot both fit and the screen becomes one pane
  /// at a time — the list, or the open conversation with a back arrow.
  ///
  /// 340 (sidebar) + 1 (divider) leaves 71px of a 412px phone for the whole
  /// conversation, and 71px is not a narrow thread: it is one CHARACTER per
  /// line. Photographed 2026-08-21 — "The interlink is at the weighbridge now"
  /// rendered as a vertical column of single letters beside a 20px composer.
  /// The doc comment above this class has said "desktop two-pane" since it was
  /// written; nothing ever told the screen what to do when it was not on one.
  ///
  /// 760 rather than [AppBreakpoints.sidebarBreakpoint] (900): the panes need
  /// 340 + a thread wide enough for the 460px bubble cap, and at 760 the thread
  /// gets 419. Above the shell's own 900 the rail is also on screen, so the
  /// figure that matters is the workspace width this screen is handed, not the
  /// window's.
  static const double _twoPaneFrom = 760;

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final room = ref.watch(activeRoomProvider);

    // NO `Scaffold(appBar:)`. Every route that mounts this screen is a leaf of
    // the portal `ShellRoute`, which has already drawn a top bar reading
    // "Messages" — so its own bar put the same word on the screen a second
    // time, directly underneath. Same fault as the tons-out register and the
    // company profile before it.
    final header = MlPageHeader(
      title: 'Messages',
      description: 'Conversations with your own team, with MineLink, and with '
          'the companies you are connected to.',
      actions: [
        // S8-3 / P10-08. Only an owner, management or admin may commit their
        // company to a group, and `create_org_group` refuses anyone else —
        // so the action is shown to exactly those roles rather than offered
        // and then refused.
        if (_canStartGroup(ref))
          MlButton.outline(
            label: 'New group',
            icon: Icons.groups_2_outlined,
            compact: true,
            onPressed: () => showOrgGroupDialog(context),
          ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoPane = constraints.maxWidth >= _twoPaneFrom;
        final sidebar = _Sidebar(
          tab: _sidebarTab,
          onTab: (t) => setState(() => _sidebarTab = t),
        );

        return ColoredBox(
          color: semantic.surfaceApp,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                    twoPane ? MlTokens.contentPadding : 16, 20, 16, 0),
                child: header,
              ),
              Expanded(
                child: twoPane
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(width: 340, child: sidebar),
                          Container(width: 1, color: semantic.divider),
                          const Expanded(child: _ConversationPane()),
                        ],
                      )
                    // One pane at a time. The list until something is picked,
                    // then the thread — with a back arrow, because on a phone
                    // there is nothing else on screen to return to it.
                    : room == null
                        ? sidebar
                        : _ConversationPane(
                            onBack: () => ref
                                .read(activeRoomProvider.notifier)
                                .state = null,
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ===========================================================================
// SIDEBAR
// ===========================================================================
class _Sidebar extends ConsumerWidget {
  final int tab;
  final ValueChanged<int> onTab;
  const _Sidebar({required this.tab, required this.onTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantic = MlSemantic.of(context);
    return Container(
      color: semantic.surfaceCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _SegTabs(
              tab: tab,
              onTab: onTab,
            ),
          ),
          Expanded(
            child: tab == 0 ? const _ConversationsList() : const _ContactsList(),
          ),
        ],
      ),
    );
  }
}

class _SegTabs extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTab;
  const _SegTabs({required this.tab, required this.onTab});

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    Widget seg(String label, int i) {
      final active = tab == i;
      return Expanded(
        child: GestureDetector(
          onTap: () => onTab(i),
          child: AnimatedContainer(
            duration: MlTokens.durFast,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? MlTokens.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(MlTokens.rMd),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: context.mlText.titleSmall.copyWith(
                color: active ? MlTokens.inkOnFill : semantic.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: semantic.surfaceSunken,
        borderRadius: BorderRadius.circular(MlTokens.rMd),
      ),
      child: Row(children: [seg('Chats', 0), seg('People', 1)]),
    );
  }
}

class _ConversationsList extends ConsumerWidget {
  const _ConversationsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convos = ref.watch(chatConversationsProvider);
    final active = ref.watch(activeRoomProvider);
    return convos.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _errorBox(context, '$e'),
      data: (list) {
        if (list.isEmpty) {
          return const MlEmptyState(
            icon: Icons.forum_outlined,
            title: 'No conversations yet',
            message: 'Open the People tab to start a chat.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final c = list[i];
            return _ConversationTile(
              conversation: c,
              selected: active?.id == c.id,
              onTap: () =>
                  ref.read(activeRoomProvider.notifier).state = c,
            );
          },
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ChatConversation conversation;
  final bool selected;
  final VoidCallback onTap;
  const _ConversationTile({
    required this.conversation,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final time = conversation.lastMessageTimestamp;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        color: selected ? MlTokens.accent.withValues(alpha: 0.10) : null,
        child: Row(
          children: [
            _Avatar(name: conversation.name, isGroup: conversation.type != ChatRoomType.dm),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.mlText.titleSmall.copyWith(
                            color: semantic.textStrong,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (time != null)
                        Text(
                          // `agoTag`, not a bare clock. Four rows whose
                          // last messages were 14 minutes, 5 hours, a day and
                          // a MONTH old all printed a plain `HH:mm`, so a
                          // conversation nobody had touched since July read
                          // "09:30" — the same fault the truck-location list
                          // had, one screen over.
                          MlTime.agoTag(time),
                          style: context.mlText.code(
                            color: semantic.textFaint,
                            size: 11,
                            weight: FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    conversation.lastMessageContent ?? 'No messages yet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.mlText.bodyMedium.copyWith(
                      color: semantic.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactsList extends ConsumerWidget {
  const _ContactsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(chatContactsProvider);
    return contacts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _errorBox(context, '$e'),
      data: (list) {
        if (list.isEmpty) {
          return const MlEmptyState(
            icon: Icons.group_outlined,
            title: 'No contacts',
            message: 'Contacts appear as your company and connections are set up.',
          );
        }
        // Group by label, preserving order (my company, mine-link, connected...).
        final groups = <String, List<ChatContact>>{};
        for (final c in list) {
          groups.putIfAbsent(c.groupLabel, () => []).add(c);
        }
        final widgets = <Widget>[];
        groups.forEach((label, members) {
          widgets.add(Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Text(
              label.toUpperCase(),
              style: context.mlText.overline.copyWith(
                color: MlSemantic.of(context).textFaint,
              ),
            ),
          ));
          widgets.addAll(members.map((c) => _ContactTile(contact: c)));
        });
        return ListView(padding: const EdgeInsets.only(bottom: 8), children: widgets);
      },
    );
  }
}

class _ContactTile extends ConsumerWidget {
  final ChatContact contact;
  const _ContactTile({required this.contact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantic = MlSemantic.of(context);
    return InkWell(
      onTap: () async {
        final svc = ref.read(messagingServiceProvider);
        final room = await svc.getOrCreateDm(
          otherUserId: contact.userId,
          otherDisplayName: contact.displayName,
        );
        // The room exists server-side now; opening it locally only makes sense
        // while this tile is still on screen, and `ref` throws if it is not.
        if (!ref.context.mounted) return;
        ref.read(activeRoomProvider.notifier).state = room;
        ref.invalidateIfMounted(chatConversationsProvider);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            _Avatar(name: contact.displayName, isSuperAdmin: contact.isSuperAdmin),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.mlText.titleSmall.copyWith(
                      color: semantic.textStrong,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (contact.companyName != null)
                    Text(
                      contact.companyName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.mlText.bodySmall.copyWith(
                        color: semantic.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            if (contact.isBlocked)
              // Warn, not error, when the cause is an expired token: that is a
              // billing state the user can fix, and the label says how.
              Tooltip(
                message: contact.blockedTooltip,
                child: MlStatusBadge(
                  label: contact.blockedLabel,
                  tone: contact.isBlockedByExpiry ? MlTone.warn : MlTone.error,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// CONVERSATION PANE
// ===========================================================================
class _ConversationPane extends ConsumerStatefulWidget {
  const _ConversationPane({this.onBack});

  /// Non-null only in the one-pane (phone) layout, where the conversation list
  /// is not on screen beside the thread.
  final VoidCallback? onBack;

  @override
  ConsumerState<_ConversationPane> createState() => _ConversationPaneState();
}

class _ConversationPaneState extends ConsumerState<_ConversationPane> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  String? _markedRoomId;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool _isBlocked(ChatConversation room, List<ChatContact> contacts) {
    if (room.type != ChatRoomType.dm) return false;
    final myId = ref.read(messagingServiceProvider).currentUserId;
    final otherId = room.participantIds.firstWhere(
      (p) => p != myId,
      orElse: () => '',
    );
    for (final c in contacts) {
      if (c.userId == otherId) return c.isBlocked;
    }
    return false;
  }

  Future<void> _send(ChatConversation room) async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final svc = ref.read(messagingServiceProvider);
      final id = await ref.read(myChatIdentityProvider.future);
      await svc.sendMessage(
        roomId: room.id,
        content: text,
        senderName: id.name,
        senderAvatarUrl: id.avatarUrl,
      );
      _controller.clear();
      ref.invalidateIfMounted(chatConversationsProvider);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send. ${friendlyError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: MlTokens.durBase,
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final room = ref.watch(activeRoomProvider);
    if (room == null) {
      return const Center(
        child: MlEmptyState(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Select a conversation',
          message: 'Pick a chat on the left, or start a new one from People.',
        ),
      );
    }

    // Mark read once per opened room.
    if (_markedRoomId != room.id) {
      _markedRoomId = room.id;
      ref.read(messagingServiceProvider).markRoomRead(room.id);
    }

    final contacts = ref.watch(chatContactsProvider).valueOrNull ?? const [];
    final blocked = _isBlocked(room, contacts);
    final myId = ref.read(messagingServiceProvider).currentUserId;
    final messages = ref.watch(roomMessagesProvider(room.id));

    return Column(
      children: [
        _ConvHeader(room: room, onBack: widget.onBack),
        Container(height: 1, color: semantic.divider),
        Expanded(
          child: messages.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _errorBox(context, '$e'),
            data: (list) {
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _scrollToBottom());
              if (list.isEmpty) {
                return const MlEmptyState(
                  icon: Icons.waving_hand_outlined,
                  title: 'Say hello',
                  message: 'No messages yet — send the first one.',
                );
              }
              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final m = list[i];
                  final mine = m.senderId == myId;
                  final showName = room.type != ChatRoomType.dm && !mine;
                  return _MessageBubble(message: m, mine: mine, showName: showName);
                },
              );
            },
          ),
        ),
        // An ended conversation is checked BEFORE `blocked`, because the two
        // have different causes and different remedies: blocked is about the
        // relationship, ended is a decision somebody made about this thread.
        // `can_send_in_chat_room()` refuses either way — this is only so the
        // user is told which, instead of watching a send fail.
        if (room.isEnded)
          const _EndedBanner()
        else if (blocked)
          _BlockedBanner(companyName: room.name)
        else
          _Composer(
            controller: _controller,
            sending: _sending,
            onSend: () => _send(room),
          ),
      ],
    );
  }
}

class _ConvHeader extends ConsumerWidget {
  final ChatConversation room;
  final VoidCallback? onBack;
  const _ConvHeader({required this.room, this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantic = MlSemantic.of(context);
    // S8-4 / P10-09: company-ONLY. Not admin, not management — the company
    // account. Shown only to them, because a control that always refuses is
    // the dead-CTA problem this repo already guards against; `end_chat` still
    // enforces it server-side, so hiding the button is presentation, not the
    // boundary.
    final isCompanyAccount =
        ref.watch(authStateProvider).userType == UserType.company;

    return Container(
      padding: EdgeInsets.fromLTRB(onBack == null ? 24 : 4, 14, 16, 14),
      color: semantic.surfaceCard,
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              tooltip: 'Back to conversations',
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          _Avatar(name: room.name, isGroup: room.type != ChatRoomType.dm),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  room.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.mlText.titleMedium.copyWith(
                    color: semantic.textStrong,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  room.type == ChatRoomType.dm
                      ? 'Direct message'
                      : room.type == ChatRoomType.orgGroup
                          ? 'Organisation group'
                          : 'Group',
                  style: context.mlText.bodySmall.copyWith(
                    color: semantic.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (room.isEnded)
            Tooltip(
              message: 'This conversation was ended. It stays readable — '
                  'ending a chat does not delete the record of it — but no new '
                  'messages can be sent.',
              child: MlStatusBadge(
                label: 'Ended',
                tone: MlTone.neutral,
              ),
            )
          else if (isCompanyAccount)
            TextButton.icon(
              onPressed: () => _confirmEnd(context, ref),
              icon: const Icon(Icons.do_not_disturb_on_outlined, size: 16),
              label: const Text('End chat'),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmEnd(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End this conversation?'),
        // Says what ending does AND what it does not, because "end" reads like
        // "delete" and this is the moment somebody decides whether to keep a
        // record they may need later.
        content: const Text(
          'No further messages can be sent, by either side.\n\n'
          'The conversation stays readable — ending it does not delete what '
          'was said. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep it open'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('End conversation'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(messagingServiceProvider).endChat(room.id);
      ref.invalidateIfMounted(chatConversationsProvider);
      // `messenger` was captured before the await on purpose, so the snackbar
      // still lands; only the `ref` read needs the header to be alive.
      if (ref.context.mounted) {
        ref.read(activeRoomProvider.notifier).state = null;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Conversation ended.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final bool showName;
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.showName,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final bg = mine ? MlTokens.accent : semantic.surfaceCard;
    // Dark ink on the accent bubble — white measures 1.81:1 on it.
    final fg = mine ? MlTokens.navy950 : semantic.textStrong;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(MlTokens.rLg),
            topRight: const Radius.circular(MlTokens.rLg),
            bottomLeft: Radius.circular(mine ? MlTokens.rLg : 4),
            bottomRight: Radius.circular(mine ? 4 : MlTokens.rLg),
          ),
          border: mine ? null : Border.all(color: semantic.borderCard),
          boxShadow: MlTokens.shadowXs,
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (showName)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  message.senderName,
                  style: context.mlText.labelMedium.copyWith(
                    color: mine ? MlTokens.navy950.withValues(alpha: 0.7) : MlTokens.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Text(message.content, style: context.mlText.bodyMedium.copyWith(
              color: fg,
            )),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  MlTime.clock(message.timestamp),
                  style: context.mlText.code(
                    color: mine ? MlTokens.inkOnFill70 : semantic.textFaint,
                    size: 10,
                    weight: FontWeight.w400,
                  ),
                ),
                if (mine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.readAt != null
                        ? Icons.done_all_rounded
                        : (message.deliveredAt != null
                            ? Icons.done_all_rounded
                            : Icons.done_rounded),
                    size: 14,
                    color: message.readAt != null
                        ? MlTokens.inkOnFill
                        : MlTokens.inkOnFill70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: semantic.surfaceCard,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                hintText: 'Write a message…',
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 48,
            child: MlButton.primary(
              label: sending ? 'Sending…' : 'Send',
              onPressed: sending ? null : onSend,
              icon: Icons.send_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockedBanner extends StatelessWidget {
  final String companyName;
  const _BlockedBanner({required this.companyName});

  @override
  Widget build(BuildContext context) {
    final tone = MlTone.error.colors(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: tone.bg,
      child: Row(
        children: [
          Icon(Icons.block_rounded, color: tone.fg, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You can no longer send or receive messages with $companyName. '
              'Contact Mine-Link to request permission to chat again.',
              style: context.mlText.titleSmall.copyWith(color: tone.fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown in place of the composer once a conversation has been ended (S8-4).
///
/// Neutral-toned on purpose. `_BlockedBanner` is red because being blocked is
/// a fault in the relationship; a chat that was deliberately closed is not a
/// fault, and painting it the same colour would make an ordinary decision look
/// like a problem.
class _EndedBanner extends StatelessWidget {
  const _EndedBanner();

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: semantic.surfaceSunken,
      child: Row(
        children: [
          Icon(Icons.do_not_disturb_on_outlined,
              color: semantic.textMuted, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This conversation has been ended. Everything said is still here '
              'to read, but no new messages can be sent.',
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

// ===========================================================================
// Shared bits
// ===========================================================================
class _Avatar extends StatelessWidget {
  final String name;
  final bool isGroup;
  final bool isSuperAdmin;
  const _Avatar({required this.name, this.isGroup = false, this.isSuperAdmin = false});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((e) => e[0]).join().toUpperCase();
    // THE PLATFORM ACCOUNT'S AVATAR WAS INVISIBLE IN THE DARK THEME.
    //
    // It drew `MlTokens.navy800` initials on a `navy800` well at 14% opacity —
    // the sidebar navy, on a navy surface. Photographed 2026-08-21: the
    // MineLink Support row in the People list has a name, a company line, and
    // a circle with nothing readable in it. The theme's default IS dark
    // (CLAUDE.md 2), so this was the normal case, not the edge one.
    //
    // `MlTone.neutral` instead: a slate that resolves per brightness, so the
    // platform account still reads as a different KIND of contact from a
    // colleague without picking a colour that only works in one theme.
    final color = isSuperAdmin
        ? MlTone.neutral.colors(Theme.of(context).brightness).fg
        : MlTokens.accent;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: isGroup
          ? Icon(Icons.groups_rounded, color: color, size: 20)
          : Text(
              initials,
              style: context.mlText.titleSmall.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

Widget _errorBox(BuildContext context, String message) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: MlSemantic.of(context).textMuted),
      ),
    ),
  );
}
