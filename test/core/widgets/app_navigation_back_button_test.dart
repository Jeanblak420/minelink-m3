import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/navigation/nav_history_provider.dart';
import 'package:flutter_application_1/core/widgets/app_navigation_back_button.dart';

void main() {
  testWidgets('hidden when there is nothing to go back to', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(56),
            child: AppNavigationBackButton(),
          ),
        ),
      ),
    ));

    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
  });

  testWidgets('shown once a non-root screen is on the stack', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(56),
            child: AppNavigationBackButton(),
          ),
        ),
      ),
    ));

    container
        .read(navHistoryProvider.notifier)
        .visit(const NavLocation(path: '/home', homeTabIndex: 0), isRoot: true);
    container
        .read(navHistoryProvider.notifier)
        .visit(const NavLocation(path: '/home', homeTabIndex: 1), isRoot: false);
    await tester.pump();

    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
  });
}
