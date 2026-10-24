// The dashboard's figures stay current while it is open (admin phone audit,
// 2026-10-24): they were read once per app session, under a registry that
// said "updated live" and an "Active users right now" tile with a Live pill.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/features/super_admin/data/repositories/super_admin_repository.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';

class _CountingRepo extends SuperAdminRepository {
  _CountingRepo() : super(SupabaseClient('http://stats.test', 'anon',
            authOptions: const AuthClientOptions(autoRefreshToken: false)));
  int reads = 0;

  @override
  Future<Map<String, dynamic>> getDashboardStats() async {
    reads++;
    return {'activeUsersNow': reads};
  }
}

void main() {
  testWidgets('re-read every minute while shown, not after it closes', (tester) async {
    final repo = _CountingRepo();
    final show = ValueNotifier(true);
    await tester.pumpWidget(ProviderScope(
      overrides: [superAdminRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: show,
          builder: (_, on, __) => on
              ? Consumer(builder: (_, ref, __) {
                  final v = ref.watch(dashboardStatsProvider).valueOrNull;
                  return Text('active ${v?['activeUsersNow'] ?? '-'}');
                })
              : const Text('elsewhere'),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('active 1'), findsOneWidget);

    await tester.pump(const Duration(seconds: 59));
    expect(repo.reads, 1, reason: 'not before the minute is up');
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(repo.reads, 2);
    expect(find.text('active 2'), findsOneWidget, reason: 'the new figure is shown');

    show.value = false;
    await tester.pump();
    await tester.pump(const Duration(minutes: 3));
    expect(repo.reads, 2, reason: 'no reading once nobody is looking');

    show.value = true;
    await tester.pump();
    await tester.pump();
    expect(repo.reads, 3, reason: 'opening the dashboard again reads fresh');
    expect(find.text('active 3'), findsOneWidget);

    show.value = false; // leave no timer behind
    await tester.pump();
  });
}
