import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/chat/models/support_models.dart';
import 'package:flutter_application_1/features/chat/services/support_service.dart';

final supportServiceProvider = Provider<SupportService>((ref) {
  return SupportService();
});

/// Is the current user a Super Global Admin? Drives the role-aware support UI.
final supportIsAdminProvider = FutureProvider<bool>((ref) async {
  return ref.watch(supportServiceProvider).isSuperAdmin();
});

/// Tickets the current (non-admin) user has logged.
final myTicketsProvider = FutureProvider<List<SupportTicket>>((ref) async {
  return ref.watch(supportServiceProvider).myTickets();
});

/// All tickets (admin inbox).
final allTicketsProvider = FutureProvider<List<SupportTicket>>((ref) async {
  return ref.watch(supportServiceProvider).allTickets();
});

/// The logger's in-app support notifications ("UPDATES").
final supportNotificationsProvider =
    FutureProvider<List<SupportNotification>>((ref) async {
  return ref.watch(supportServiceProvider).notifications();
});

/// Super admins + their receiving preference (inbox toggle list).
final inboxAdminsProvider = FutureProvider<List<SupportAdmin>>((ref) async {
  return ref.watch(supportServiceProvider).inboxAdmins();
});

/// Live ticket row (status changes).
final ticketStreamProvider =
    StreamProvider.family<SupportTicket?, String>((ref, ticketId) {
  return ref.watch(supportServiceProvider).ticketStream(ticketId);
});

/// Live conversation for a ticket.
final ticketMessagesProvider =
    StreamProvider.family<List<SupportMessage>, String>((ref, ticketId) {
  return ref.watch(supportServiceProvider).messagesStream(ticketId);
});

/// Live timeline events for a ticket.
final ticketEventsProvider =
    StreamProvider.family<List<SupportEvent>, String>((ref, ticketId) {
  return ref.watch(supportServiceProvider).eventsStream(ticketId);
});
