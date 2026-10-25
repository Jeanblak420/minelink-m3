import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/chat/models/chat_room_model.dart';
import 'package:flutter_application_1/features/chat/providers/communications_provider.dart';
import 'package:flutter_application_1/features/chat/screens/chat_screen.dart';
import 'package:flutter_application_1/features/chat/screens/communications_hub_screen.dart';
import 'package:flutter_application_1/features/company/providers/company_provider.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';

/// `/chat/:chatRoomId`, resolved from the URL alone.
///
/// ## The route used to render the dashboard
///
/// `ChatScreen` needs a whole `ChatScreenArgs` — the room, the signed-in user's
/// id, name and avatar, and the participant list — and the Communications hub
/// hands all of that over as `state.extra` when it pushes. The router's builder
/// was:
///
///     final chatArgs = state.extra as ChatScreenArgs?;
///     if (chatArgs == null) return const HomeTabBodyScreen();
///
/// So `:chatRoomId` was parsed and thrown away, and every arrival that did not
/// come through that one tap in the hub — a browser refresh, a bookmark, a
/// pasted link, a notification deep link — got the **workspace dashboard**
/// under a top bar that said "Chat". Driven in a browser as `roadhaul.admin` on
/// 2026-08-22: `#/chat/24f1bef3-…` showed "Dashboard · Signed in as Admin Test
/// · Quick Actions", with the bar above it reading Chat. Nothing said the
/// conversation had not opened.
///
/// A silent substitution is the worst of the three possible behaviours. Showing
/// the chat is best; saying plainly that it could not be opened is acceptable;
/// showing a different screen and calling it Chat is neither.
///
/// ## How it resolves
///
/// From the same two sources the hub itself uses, so the two cannot disagree
/// about who may see what: [CommunicationsAccess] for the signed-in identity
/// and their company, and `communicationsProvider` for the rooms and contacts.
/// A room the user is not a participant of simply is not in that list, so
/// access is enforced by the same query the hub is — and by RLS underneath it —
/// rather than by anything this widget decides.
///
/// Every state it can be in says which one it is:
///
/// * no company profile yet — the hub's own wording for the same condition
/// * still reading — a spinner, not an error (see
///   `dashboards_do_not_cry_wolf_test.dart` for why that distinction is kept)
/// * the read failed — the error, with a way back
/// * no such room, or not yours — said plainly, with a way back
class ChatRoomRoute extends ConsumerWidget {
  const ChatRoomRoute({super.key, required this.chatRoomId});

  final String chatRoomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final companyState = ref.watch(companyProvider);
    final employeeState = ref.watch(employeeProvider);

    if (authState.user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final access = CommunicationsAccess.fromState(
      authStateUserId: authState.user?.id,
      userType: authState.userType,
      company: companyState.company,
      employeeCompany: employeeState.company,
      employee: employeeState.employee,
    );

    if (access == null) {
      // Word for word the hub's, because it is the same condition.
      return const MlEmptyState(
        icon: Icons.forum_outlined,
        title: 'Communications',
        message:
            'A linked company profile is required before live '
            'announcements and chat become available.',
      );
    }

    final scope = CommunicationsScope(
      companyId: access.company.id,
      userId: access.userId,
    );
    final state = ref.watch(communicationsProvider(scope));

    if (state.isLoading && state.chatRooms.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.chatRooms.isEmpty) {
      return _back(
        context,
        icon: Icons.error_outline,
        title: 'Could not open this conversation',
        message: state.error!,
      );
    }

    final room = state.chatRooms.cast<ChatRoom?>().firstWhere(
      (r) => r?.id == chatRoomId,
      orElse: () => null,
    );

    if (room == null) {
      return _back(
        context,
        icon: Icons.forum_outlined,
        title: 'Conversation not available',
        message:
            'This chat either no longer exists or is not one you are a '
            'participant of.',
      );
    }

    return ChatScreen(
      chatRoom: room,
      currentUserId: access.userId,
      currentUserName: access.currentUserName,
      currentUserAvatarUrl: access.currentUserAvatarUrl,
      participants: chatRoomParticipants(room, access, state),
    );
  }

  /// An honest dead end always offers the way out of it.
  Widget _back(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    return MlEmptyState(
      icon: icon,
      title: title,
      message: message,
      action: MlButton.tonal(
        label: 'Open Communications',
        icon: Icons.campaign_outlined,
        onPressed: () => context.go('/communications'),
      ),
    );
  }
}
