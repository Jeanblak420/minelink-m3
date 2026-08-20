import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/navigation/nav_history_provider.dart';
import 'package:flutter_application_1/core/widgets/nav_history_recorder.dart';

void main() {
  testWidgets('records visits as location changes', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    Widget host(NavLocation loc, bool isRoot) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: NavHistoryRecorder(
          location: loc,
          isRoot: isRoot,
          child: const SizedBox.shrink(),
        ),
      ),
    );

    await tester.pumpWidget(
      host(const NavLocation(path: '/home', homeTabIndex: 0), true),
    );
    await tester.pump(); // run post-frame callback
    expect(container.read(navHistoryProvider).length, 1);

    await tester.pumpWidget(
      host(const NavLocation(path: '/home', homeTabIndex: 1), false),
    );
    await tester.pump();
    expect(container.read(navHistoryProvider).length, 2);
    expect(container.read(navHistoryProvider.notifier).canGoBack, isTrue);
  });
}
