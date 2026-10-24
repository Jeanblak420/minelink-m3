// Number + password sign-in (login methods, 2026-10-24).
//
// A WhatsApp number names the account through its PHONE first — Supabase's
// password grant takes `phone` — so it works for an account whose email is a
// real address, which number sign-in used to miss. Only when the phone attempt
// is refused as invalid credentials does it fall back to the older placeholder
// `wa-<digits>@wa.mineralguide.com`. Any other refusal (rate limit, server
// fault) is the real answer and must not be retried away.
//
// Driven against a fake auth server, so the exact requests are asserted.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/features/auth/services/auth_service.dart';

Map<String, dynamic> _session(String id) => {
      'access_token': 'access-$id',
      'token_type': 'bearer',
      'expires_in': 3600,
      'expires_at': 4102444800,
      'refresh_token': 'refresh-$id',
      'user': {
        'id': id,
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': 'someone@example.com',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'created_at': '2026-10-24T00:00:00Z',
      },
    };

void main() {
  late List<Map<String, dynamic>> grants;

  AuthService serviceAnswering(http.Response Function(Map<String, dynamic> body) answer) {
    grants = [];
    final client = SupabaseClient(
      'http://auth.test',
      'anon-key',
      httpClient: MockClient((req) async {
        if (req.url.path.endsWith('/token')) {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          grants.add(body);
          return answer(body);
        }
        return http.Response('{}', 200);
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    return AuthService(client: client);
  }

  http.Response invalid() => http.Response(
      jsonEncode({'code': 400, 'error_code': 'invalid_credentials', 'msg': 'Invalid login credentials'}),
      400,
      headers: {'content-type': 'application/json'});

  test('a number signs in through the phone, not the placeholder', () async {
    final service = serviceAnswering((b) => http.Response(jsonEncode(_session('u1')), 200,
        headers: {'content-type': 'application/json'}));
    final res = await service.signInWithWhatsappNumber(
        whatsappNumber: '083 306 7846', password: 'secret');
    expect(res.user?.id, 'u1');
    expect(grants, hasLength(1));
    expect(grants.single['phone'], '+27833067846',
        reason: 'local 0… numbers must go out in E.164');
    expect(grants.single.containsKey('email'), isFalse);
  });

  test('refused on the phone → tries the placeholder email once', () async {
    final service = serviceAnswering((b) => b.containsKey('phone')
        ? invalid()
        : http.Response(jsonEncode(_session('legacy')), 200,
            headers: {'content-type': 'application/json'}));
    final res = await service.signInWithWhatsappNumber(
        whatsappNumber: '0833067846', password: 'secret');
    expect(res.user?.id, 'legacy');
    expect(grants.map((g) => g.keys.contains('phone') ? 'phone' : 'email'), ['phone', 'email']);
    expect(grants.last['email'], 'wa-0833067846@wa.mineralguide.com');
  });

  test('a wrong password is reported, after both tries', () async {
    final service = serviceAnswering((_) => invalid());
    await expectLater(
      service.signInWithWhatsappNumber(whatsappNumber: '0833067846', password: 'nope'),
      throwsA(anything),
    );
    expect(grants, hasLength(2));
  });

  test('a rate limit is NOT retried on the placeholder', () async {
    final service = serviceAnswering((_) => http.Response(
        jsonEncode({'code': 429, 'error_code': 'over_request_rate_limit', 'msg': 'Too many requests'}),
        429,
        headers: {'content-type': 'application/json'}));
    await expectLater(
      service.signInWithWhatsappNumber(whatsappNumber: '0833067846', password: 'x'),
      throwsA(anything),
    );
    expect(grants, hasLength(1),
        reason: 'retrying would hide the real answer and burn a second attempt');
  });

  test('a number with no digits is refused before any request', () async {
    final service = serviceAnswering((_) => invalid());
    await expectLater(
      service.signInWithWhatsappNumber(whatsappNumber: 'abc', password: 'x'),
      throwsA(anything),
    );
    expect(grants, isEmpty);
  });
}
