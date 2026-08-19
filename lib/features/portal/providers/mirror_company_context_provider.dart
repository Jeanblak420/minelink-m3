import 'package:flutter_riverpod/flutter_riverpod.dart';

/// When non-null, portal widgets resolve [company_id] from here first (super-admin company mirror).
final mirrorCompanyIdProvider = StateProvider<String?>((ref) => null);
