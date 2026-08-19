// Which place-index failures are worth repeating.
//
// The extras project's `search_place_index` sits close to that project's ~3s
// `anon` statement timeout. Measured against it on 2026-08-17, warm:
//
//     Rosebank     1.07s  200
//     Emalahleni   2.36s  200
//     Durban       3.26s  500  57014
//     Polokwane    3.75s  500  57014
//
// A repeat of a failed query usually lands, because the first attempt warms the
// pages the second needs (3.77s fail -> 2.13s success). So a timeout is worth
// retrying once — and nothing else is: a paused project, a missing grant or a
// dropped function fails again identically, and retrying only makes the user
// wait twice before the search falls through to Nominatim.
//
// The predicate is what decides that, so the predicate is what gets pinned.
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:flutter_application_1/features/portal/services/place_search_service.dart';

void main() {
  group('a statement timeout is worth one more try', () {
    test('the typed Postgrest error', () {
      expect(
        PlaceSearchService.isStatementTimeout(
          const PostgrestException(
            message: 'canceling statement due to statement timeout',
            code: '57014',
          ),
        ),
        isTrue,
      );
    });

    test('the same thing arriving untyped', () {
      // The transport does not guarantee a typed exception — matching the
      // stringified form as well is why this is not just `is PostgrestException`.
      expect(
        PlaceSearchService.isStatementTimeout(
          Exception('canceling statement due to statement timeout'),
        ),
        isTrue,
      );
      expect(PlaceSearchService.isStatementTimeout('… code: 57014 …'), isTrue);
    });
  });

  group('everything else fails the same way twice', () {
    test('a paused or unreachable project', () {
      expect(
        PlaceSearchService.isStatementTimeout(
          Exception('Failed host lookup: qbydiuplqhmkaxarnuza.supabase.co'),
        ),
        isFalse,
      );
    });

    test('a missing grant — the failure mode CLAUDE.md §6 warns about', () {
      expect(
        PlaceSearchService.isStatementTimeout(
          const PostgrestException(
            message: 'permission denied for function search_place_index',
            code: '42501',
          ),
        ),
        isFalse,
      );
    });

    test('the function dropped from under us', () {
      expect(
        PlaceSearchService.isStatementTimeout(
          const PostgrestException(
            message: 'Could not find the function public.search_place_index',
            code: 'PGRST202',
          ),
        ),
        isFalse,
      );
    });

    test('a plain empty result is not an error at all', () {
      // Guards against anyone widening the predicate to "anything falsy".
      expect(PlaceSearchService.isStatementTimeout(Exception('')), isFalse);
    });
  });
}
