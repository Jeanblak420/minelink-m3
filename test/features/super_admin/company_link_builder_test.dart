import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/super_admin/widgets/company_link_builder.dart';

void main() {
  test('companyOrgTypeLabel maps org types to display labels', () {
    expect(companyOrgTypeLabel('mineSupplier'), 'Mine/Supplier');
    expect(companyOrgTypeLabel('buyer'), 'Buyer');
    expect(companyOrgTypeLabel('transporter'), 'Transporter');
    expect(companyOrgTypeLabel('weird'), 'Company');
    expect(companyOrgTypeLabel(null), 'Company');
  });

  final companies = <Map<String, dynamic>>[
    {'id': 'a', 'company_name': 'Alpha Mine', 'org_type': 'mineSupplier'},
    {'id': 'b', 'company_name': 'Bravo Buyer', 'org_type': 'buyer'},
    {'id': 't', 'company_name': 'Tango Trucks', 'org_type': 'transporter'},
  ];

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );

  testWidgets('locked mode shows a single picker without the locked company', (
    tester,
  ) async {
    await pump(
      tester,
      CompanyLinkBuilder(companies: companies, lockedLeftCompanyId: 't'),
    );

    expect(find.text('Company to link'), findsOneWidget);
    expect(find.text('First company'), findsNothing);
    expect(find.text('Second company'), findsNothing);
    expect(find.text('Tango Trucks'), findsNothing);
    expect(find.text('Alpha Mine'), findsOneWidget);
    expect(find.text('Bravo Buyer'), findsOneWidget);
  });

  testWidgets('locked mode hides already-linked companies via excludeIds', (
    tester,
  ) async {
    await pump(
      tester,
      CompanyLinkBuilder(
        companies: companies,
        lockedLeftCompanyId: 't',
        excludeIds: const {'b'},
      ),
    );

    expect(find.text('Bravo Buyer'), findsNothing);
    expect(find.text('Alpha Mine'), findsOneWidget);
  });

  testWidgets('unlocked mode keeps the two-sided picker', (tester) async {
    await pump(tester, CompanyLinkBuilder(companies: companies));

    expect(find.text('First company'), findsOneWidget);
    expect(find.text('Second company'), findsOneWidget);
    expect(find.text('Company to link'), findsNothing);
  });
}
