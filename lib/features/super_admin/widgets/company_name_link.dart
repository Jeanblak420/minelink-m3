import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/features/portal/widgets/ml/ml.dart';

/// A company name rendered as a link. Tapping navigates the super-admin to that
/// company's profile (`/super-admin/organization/:id`).
class CompanyNameLink extends StatelessWidget {
  final String companyId;
  final String name;
  final TextStyle? style;

  const CompanyNameLink({
    super.key,
    required this.companyId,
    required this.name,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final base = (style ?? const TextStyle()).copyWith(
      color: MlTokens.accent,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: MlTokens.accent,
    );
    return InkWell(
      onTap: () => context.go('/super-admin/organization/$companyId'),
      child: Text(name, overflow: TextOverflow.ellipsis, style: base),
    );
  }
}
