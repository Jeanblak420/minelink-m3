import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/features/chat/providers/messaging_providers.dart';
import 'package:flutter_application_1/features/portal/widgets/ml/ml.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

String companyOrgTypeLabel(String? orgType) {
  switch (orgType) {
    case 'mineSupplier':
      return 'Mine / Supplier';
    case 'buyer':
      return 'Buyer';
    case 'transporter':
      return 'Transporter';
    default:
      return 'Company';
  }
}

const _orgTypeOrder = ['mineSupplier', 'buyer', 'transporter'];

/// Org-type-grouped company selector for granting chat links. Without
/// [lockedLeftCompanyId] it is two-sided: pick one company on the left and one
/// on the right. With [lockedLeftCompanyId] set (a company's profile page) the
/// left side is that company and only a single "Company to link" picker is
/// shown. The sentence reads "Connect X to Y via MineLink Messenger" and
/// Connect grants the link. [excludeIds] hides companies from the picker
/// (e.g. ones already linked).
class CompanyLinkBuilder extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> companies;
  final String? lockedLeftCompanyId;
  final Set<String> excludeIds;
  final VoidCallback? onLinked;

  const CompanyLinkBuilder({
    super.key,
    required this.companies,
    this.lockedLeftCompanyId,
    this.excludeIds = const {},
    this.onLinked,
  });

  @override
  ConsumerState<CompanyLinkBuilder> createState() => _CompanyLinkBuilderState();
}

class _CompanyLinkBuilderState extends ConsumerState<CompanyLinkBuilder> {
  String? _left;
  String? _right;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _left = widget.lockedLeftCompanyId;
  }

  String _nameOf(String id) {
    final c = widget.companies.firstWhere(
      (e) => e['id'] == id,
      orElse: () => const {'company_name': 'Company'},
    );
    final n = (c['company_name'] as String?)?.trim();
    return (n != null && n.isNotEmpty) ? n : 'Company';
  }

  Future<void> _connect() async {
    final a = _left, b = _right;
    if (a == null || b == null || a == b) return;
    setState(() => _busy = true);
    try {
      await ref.read(messagingServiceProvider).grantConnection(a, b);
      ref.invalidateIfMounted(orgConnectionsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${_nameOf(a)} and ${_nameOf(b)} are now connected in chat.')),
      );
      setState(() {
        if (widget.lockedLeftCompanyId == null) _left = null;
        _right = null;
      });
      widget.onLinked?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final lockedId = widget.lockedLeftCompanyId;
    final canConnect =
        _left != null && _right != null && _left != _right && !_busy;

    Widget pickerCard({
      required String title,
      required String? selected,
      required Set<String> exclude,
      required ValueChanged<String> onPick,
    }) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: semantic.surfaceCard,
          borderRadius: BorderRadius.circular(MlTokens.rXl),
          border: Border.all(color: semantic.borderCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: semantic.textFaint)),
            const SizedBox(height: 8),
            _GroupedCompanyList(
              companies: widget.companies,
              selectedId: selected,
              excludeIds: exclude,
              onPick: onPick,
            ),
          ],
        ),
      );
    }

    final Widget picker;
    if (lockedId != null) {
      picker = pickerCard(
        title: 'Company to link',
        selected: _right,
        exclude: {lockedId, ...widget.excludeIds},
        onPick: (id) => setState(() => _right = id),
      );
    } else {
      picker = LayoutBuilder(builder: (context, c) {
        final left = pickerCard(
          title: 'First company',
          selected: _left,
          exclude: {if (_right != null) _right!, ...widget.excludeIds},
          onPick: (id) => setState(() => _left = id),
        );
        final right = pickerCard(
          title: 'Second company',
          selected: _right,
          exclude: {if (_left != null) _left!, ...widget.excludeIds},
          onPick: (id) => setState(() => _right = id),
        );
        if (c.maxWidth < 640) {
          return Column(children: [
            left,
            const SizedBox(height: 12),
            right,
          ]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 12),
            Expanded(child: right),
          ],
        );
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        picker,
        const SizedBox(height: 14),
        RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 14, color: semantic.textStrong),
            children: [
              const TextSpan(text: 'Connect '),
              TextSpan(
                  text: _left != null ? _nameOf(_left!) : '…',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const TextSpan(text: ' to '),
              TextSpan(
                  text: _right != null ? _nameOf(_right!) : '…',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              TextSpan(
                  text: ' via MineLink Messenger',
                  style: TextStyle(color: semantic.textFaint)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MlButton.primary(
          label: 'Connect via MineLink Messenger',
          icon: Icons.hub_outlined,
          compact: true,
          onPressed: canConnect ? _connect : null,
        ),
      ],
    );
  }
}

/// A scrollable list of companies grouped under org-type headers, single-select.
class _GroupedCompanyList extends StatelessWidget {
  final List<Map<String, dynamic>> companies;
  final String? selectedId;
  final Set<String> excludeIds;
  final ValueChanged<String> onPick;

  const _GroupedCompanyList({
    required this.companies,
    required this.selectedId,
    required this.excludeIds,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final c in companies) {
      if (excludeIds.contains(c['id'])) continue;
      final t = (c['org_type'] as String?) ?? 'other';
      groups.putIfAbsent(t, () => []).add(c);
    }
    final orderedTypes = [
      ..._orgTypeOrder.where(groups.containsKey),
      ...groups.keys.where((t) => !_orgTypeOrder.contains(t)),
    ];

    return SizedBox(
      height: 220,
      child: ListView(
        children: [
          for (final t in orderedTypes) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: Text(
                companyOrgTypeLabel(t == 'other' ? null : t).toUpperCase(),
                style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w800,
                    color: semantic.textFaint),
              ),
            ),
            for (final c in groups[t]!)
              _CompanyRow(
                name: (c['company_name'] as String?)?.trim().isNotEmpty == true
                    ? c['company_name'] as String
                    : 'Company',
                selected: c['id'] == selectedId,
                onTap: () => onPick(c['id'] as String),
              ),
          ],
        ],
      ),
    );
  }
}

class _CompanyRow extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _CompanyRow({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MlTokens.rMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: selected
                ? MlTokens.accent.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(MlTokens.rMd),
            border: Border.all(
              color: selected ? MlTokens.accent : semantic.borderCard,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 16,
                color: selected ? MlTokens.accent : semantic.textFaint,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: semantic.textStrong,
                    )),
              ),
            ],
          ),
        ));
  }
}
