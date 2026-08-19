import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/features/super_admin/widgets/company_name_link.dart';

void main() {
  testWidgets('tapping a CompanyNameLink navigates to the org profile route',
      (tester) async {
    String? landed;
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (c, s) => const Scaffold(
          body: CompanyNameLink(companyId: 'org-123', name: 'Acme Mine'),
        ),
      ),
      GoRoute(
        path: '/super-admin/organization/:id',
        builder: (c, s) {
          landed = s.pathParameters['id'];
          return const Scaffold(body: Text('profile'));
        },
      ),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Acme Mine'));
    await tester.pumpAndSettle();
    expect(landed, 'org-123');
  });
}
