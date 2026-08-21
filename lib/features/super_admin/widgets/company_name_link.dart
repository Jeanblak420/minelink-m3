import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';

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
      // TWO lines. This is a company's NAME and it is the link's own label —
      // "Consolidated Mineral Offtake & Logistics Holdings" is 333px and the
      // cards that carry these give it 157px on a phone, so at one line the
      // reader could not tell which company they were about to open.
      child: Text(
        name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: base,
      ),
    );
  }
}
