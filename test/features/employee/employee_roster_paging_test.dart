// The employee grid's SECOND page used to be its first page again.
//
// `EmployeeGridScreen` is the only caller of
// `EmployeeRepository.getByCompanyId`, and it drives it through
// `InfiniteGrid`: page 0 is `offset 0, limit 20`, page 1 is `offset 20,
// limit 20`, and so on until a short page says the roster has ended.
//
// The method had two faults that only ever showed up together:
//
//   1. the CACHED path returned the cached rows verbatim — `orderBy`, `limit`
//      and `offset` were simply not applied to them — so every page after the
//      one that primed the cache came back identical, and never short;
//   2. the write into the cache sat AFTER the pagination step, so what was
//      cached under the company's key was the 20-row slice rather than the
//      roster. For the next five minutes every reader of that company's
//      employees, paginated or not, was told the company had 20 people.
//
// Fault 2 is what makes fault 1 invisible in a small fixture: with fewer
// people than one page, the slice IS the roster and nothing ever disagrees.
// The tests below therefore use a roster LONGER than the page they ask for.
//
// This test reaches the real `EmployeeRepository`, which was not possible
// until the same commit: `SupabaseRepository.supabase` was a field
// initialiser, so constructing any repository read `Supabase.instance.client`
// and threw. It is a getter now, and a warm cache answers without a client
// ever being touched.
import 'dart:io';

import 'package:flutter_application_1/core/mcp/repositories/employee_repository.dart';
import 'package:flutter_application_1/core/services/cache_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Nine people, in the order the query returns them (first name, then last).
List<Map<String, dynamic>> _roster() => [
  for (final name in const [
    'Ayanda',
    'Bongani',
    'Cebo',
    'Dineo',
    'Elias',
    'Farai',
    'Gugu',
    'Hlengiwe',
    'Itumeleng',
  ])
    <String, dynamic>{
      'id': 'emp-${name.toLowerCase()}',
      'user_id': 'u-${name.toLowerCase()}',
      'first_name': name,
      'last_name': 'Ndlovu',
      'whatsapp_number': '+27 82 000 0000',
      'company_id': 'co-1',
      'role': 'driver',
      'status': 'active',
      'created_at': '2026-08-01T06:00:00Z',
    },
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('page two of a warm roster is not page one again', () async {
    await CacheService.cacheCompanyEmployees('co-1', _roster());
    final repo = EmployeeRepository();

    final pageOne = await repo.getByCompanyId(
      'co-1',
      orderBy: 'first_name',
      limit: 4,
      offset: 0,
    );
    final pageTwo = await repo.getByCompanyId(
      'co-1',
      orderBy: 'first_name',
      limit: 4,
      offset: 4,
    );
    final pageThree = await repo.getByCompanyId(
      'co-1',
      orderBy: 'first_name',
      limit: 4,
      offset: 8,
    );

    expect(pageOne.map((e) => e.firstName), [
      'Ayanda',
      'Bongani',
      'Cebo',
      'Dineo',
    ]);
    expect(
      pageTwo.map((e) => e.firstName),
      ['Elias', 'Farai', 'Gugu', 'Hlengiwe'],
      reason:
          'the second page must be the NEXT four people, not the first four '
          'again — a cache hit is still a page of a roster',
    );

    // The short page is how `InfiniteGrid` learns the roster has ended. Under
    // the old code every page was full, so it never did.
    expect(pageThree.map((e) => e.firstName), ['Itumeleng']);
    expect(pageThree.length, lessThan(4));
  });

  test('paging a roster does not shrink the roster', () async {
    await CacheService.cacheCompanyEmployees('co-1', _roster());
    final repo = EmployeeRepository();

    // The grid asks for its first page…
    await repo.getByCompanyId('co-1', orderBy: 'first_name', limit: 4);

    // …and the header then asks the same repository how many people there are.
    final everyone = await repo.getByCompanyId('co-1');
    expect(
      everyone.length,
      9,
      reason:
          'the cache holds the ROSTER; a page is a view of it. Caching the '
          'slice made a nine-person company answer "4" to every reader for '
          'the next five minutes',
    );
  });

  test(
    'an offset past the end of the roster is an empty page, not a crash',
    () async {
      await CacheService.cacheCompanyEmployees('co-1', _roster());
      final repo = EmployeeRepository();

      final past = await repo.getByCompanyId('co-1', limit: 4, offset: 40);
      expect(past, isEmpty);
    },
  );

  // Fault 2 lives on the CACHE-MISS path, which needs a `SupabaseClient` no
  // unit test in this repo can build. It is pinned structurally instead: there
  // is exactly ONE write into the company-employees cache, and it sits ABOVE
  // the pagination step. Moving that line back under the slice is the whole of
  // the bug, and this fails the moment it happens.
  test('the cache write is above the pagination step, and there is one of it', () {
    final src = File(
      'lib/core/mcp/repositories/employee_repository.dart',
    ).readAsStringSync();

    const cacheWrite = 'CacheService.cacheCompanyEmployees(companyId,';
    expect(
      cacheWrite.allMatches(src).length,
      1,
      reason:
          'one write, of the roster. Two writes is how the slice came to be '
          'cached under the roster key',
    );

    final writeAt = src.indexOf(cacheWrite);
    final paginateAt = src.indexOf('// Apply pagination if needed');
    expect(writeAt, greaterThan(-1));
    expect(paginateAt, greaterThan(-1));
    expect(
      writeAt,
      lessThan(paginateAt),
      reason:
          'the ROSTER is cached, not a page of it — the write must sit above '
          'the slice',
    );
  });

  // The GREEN case: a roster that fits inside one page behaves exactly as it
  // always did. This is the case the old code got right, and it must not
  // change — it is most of the companies in the product.
  test('a roster shorter than a page is returned whole, in order', () async {
    await CacheService.cacheCompanyEmployees(
      'co-1',
      _roster().take(3).toList(),
    );
    final repo = EmployeeRepository();

    final only = await repo.getByCompanyId(
      'co-1',
      orderBy: 'first_name',
      limit: 20,
      offset: 0,
    );
    expect(only.map((e) => e.firstName), ['Ayanda', 'Bongani', 'Cebo']);
  });
}
