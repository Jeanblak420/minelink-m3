import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_application_1/features/super_admin/data/models/target_scope.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/features/super_admin/providers/targets_provider.dart';
import 'package:flutter_application_1/features/super_admin/screens/targets_org_type_screen.dart';
import 'package:flutter_application_1/features/super_admin/widgets/targets/targets_chrome.dart';
import 'package:flutter_application_1/features/super_admin/widgets/targets/targets_workspace.dart';
import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';

/// Targets for one company.
///
/// A company's tonnage is every trip it was a party to — as the mine, the
/// buyer or the transporter. Since a company has exactly one org type, that
/// resolves to its own side of the job without needing to be told which.
class TargetsCompanyScreen extends ConsumerStatefulWidget {
  const TargetsCompanyScreen({super.key, this.companyId});

  final String? companyId;

  static const String basePath = '/super-admin/targets/company';

  @override
  ConsumerState<TargetsCompanyScreen> createState() =>
      _TargetsCompanyScreenState();
}

class _TargetsCompanyScreenState extends ConsumerState<TargetsCompanyScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  static const int _maxPills = 12;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = MlGlass.of(context);
    final orgs = ref.watch(organizationsProvider);
    final companies = orgs.valueOrNull ?? const <Map<String, dynamic>>[];

    final selected = widget.companyId == null
        ? null
        : companies.cast<Map<String, dynamic>?>().firstWhere(
              (c) => c?['id'] == widget.companyId,
              orElse: () => null,
            );

    final scope =
        widget.companyId == null ? null : TargetScope.company(widget.companyId!);
    final data =
        scope == null ? null : ref.watch(targetsProvider(scope)).valueOrNull;

    final name = (selected?['company_name'] as String?) ??
        (widget.companyId == null ? null : 'Selected company');

    return Container(
      color: t.bg0,
      child: Column(
        children: [
          TargetsBand(
            title: name == null ? 'Company targets' : '$name targets',
            subtitle: name == null
                ? 'Pick a company to set its monthly targets and its 12-month '
                    'cycle. Each company carries its own commitment, separate '
                    'from its org type and from the platform.'
                : 'Every load this company was a party to — as the mine, the '
                    'buyer or the transporter. Its own commitment, independent '
                    'of the org-type and platform targets.',
            icon: Icons.apartment_rounded,
            scopeLabel: 'BY COMPANY',
            headline: data == null ? null : TargetsHeadline.of(data),
            selector: _picker(t, companies, orgs.isLoading),
          ),
          Expanded(
            child: scope == null
                ? _empty(t, orgs.isLoading)
                : TargetsWorkspace(key: ValueKey(scope), scope: scope),
          ),
        ],
      ),
    );
  }

  Widget _picker(
    MlGlass t,
    List<Map<String, dynamic>> companies,
    bool loading,
  ) {
    final q = _query.trim().toLowerCase();
    final matches = companies.where((c) {
      if (q.isEmpty) return true;
      final n = (c['company_name'] as String? ?? '').toLowerCase();
      final o = (c['org_type'] as String? ?? '').toLowerCase();
      return n.contains(q) || o.contains(q);
    }).toList();

    final shown = matches.take(_maxPills).toList();
    final hidden = matches.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              'COMPANY',
              style: TextStyle(
                fontFamily: MlGlass.sans,
                fontSize: 8.5,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
                color: t.inkLo,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SizedBox(
                height: 32,
                child: TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  style: TextStyle(
                    fontFamily: MlGlass.sans,
                    fontSize: 12,
                    color: t.inkHi,
                  ),
                  cursorColor: t.accent,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: loading
                        ? 'Loading organizations…'
                        : 'Search ${companies.length} organizations',
                    hintStyle: TextStyle(
                      fontFamily: MlGlass.sans,
                      fontSize: 11.5,
                      color: t.inkLo,
                    ),
                    prefixIcon:
                        Icon(Icons.search_rounded, size: 15, color: t.inkLo),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    filled: true,
                    fillColor: t.inkHi.withValues(alpha: 0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: t.line2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: t.line2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: t.accent.withValues(alpha: 0.65)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (shown.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in shown)
                TargetsScopePill(
                  label: c['company_name'] as String? ?? 'Unnamed',
                  sublabel: TargetOrgType.parse(c['org_type'] as String?)
                      .label
                      .toUpperCase(),
                  icon: TargetOrgType.parse(c['org_type'] as String?).icon,
                  selected: c['id'] == widget.companyId,
                  onTap: () => context
                      .go('${TargetsCompanyScreen.basePath}/${c['id']}'),
                ),
            ],
          ),
        ],
        if (hidden > 0) ...[
          const SizedBox(height: 9),
          Text(
            '$hidden more — narrow the search to see them',
            style: TextStyle(
              fontFamily: MlGlass.sans,
              fontSize: 10,
              color: t.inkXlo,
            ),
          ),
        ],
        if (!loading && matches.isEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'No organization matches "$_query".',
            style: TextStyle(
              fontFamily: MlGlass.sans,
              fontSize: 11.5,
              color: t.inkMid,
            ),
          ),
        ],
      ],
    );
  }

  Widget _empty(MlGlass t, bool loading) => Container(
        color: t.bg0,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              loading ? Icons.hourglass_empty_rounded : Icons.touch_app_outlined,
              size: 30,
              color: t.inkXlo,
            ),
            const SizedBox(height: 14),
            Text(
              loading ? 'Loading organizations…' : 'Choose a company',
              style: TextStyle(
                fontFamily: MlGlass.sans,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: t.inkMid,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Targets are set per company. Nothing is created until one is '
              'picked, so browsing here changes nothing.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: MlGlass.sans,
                fontSize: 11.5,
                height: 1.55,
                color: t.inkXlo,
              ),
            ),
          ],
        ),
      );
}
