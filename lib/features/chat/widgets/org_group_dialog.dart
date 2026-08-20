import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/features/chat/providers/messaging_providers.dart';
import 'package:flutter_application_1/features/company/services/company_service.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';

/// Create an organisation group chat (S8-3 / P10-08).
///
/// The rules — at most three companies, at most one of each org type — are
/// enforced by `create_org_group` in Postgres. They are *also* reflected here,
/// not to enforce them, but so the user finds out while choosing rather than
/// after submitting. If the two ever disagree, the database wins and the error
/// is surfaced verbatim through [friendlyError].
///
/// The caller's own company is always in the group and is not listed: you do
/// not invite yourself, and showing it as a tickable row invites the question
/// of what happens when you untick it.
Future<void> showOrgGroupDialog(BuildContext context) => showDialog<void>(
      context: context,
      builder: (_) => const _OrgGroupDialog(),
    );

class _OrgGroupDialog extends ConsumerStatefulWidget {
  const _OrgGroupDialog();

  @override
  ConsumerState<_OrgGroupDialog> createState() => _OrgGroupDialogState();
}

class _OrgGroupDialogState extends ConsumerState<_OrgGroupDialog> {
  final _name = TextEditingController();
  final _selected = <String, OrgType>{}; // companyId -> orgType
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// At most two others, because the caller's own company is the third.
  static const _maxOthers = 2;

  bool _orgTypeTaken(OrgType orgType) => _selected.containsValue(orgType);

  Future<void> _create() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(messagingServiceProvider).createOrgGroup(
            name: _name.text.trim().isEmpty
                ? 'Organisation group'
                : _name.text.trim(),
            companyIds: _selected.keys.toList(),
          );
      ref.invalidateIfMounted(chatConversationsProvider);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(
        content: Text(
            'Group created. The other companies have been invited and will '
            'appear once they accept.'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final directory = ref.watch(companyDirectoryProvider);

    return AlertDialog(
      title: const Text('New organisation group'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Group name',
                hintText: 'e.g. Chrome corridor',
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Add up to two other companies — one mine, one buyer, one '
              'transporter at most. Your own company is always included.',
              style: TextStyle(fontSize: 13, color: semantic.textMuted),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: directory.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => MlLoadFailure(
                  subject: 'the company list',
                  error: e,
                  onRetry: () => ref.invalidate(companyDirectoryProvider),
                ),
                data: (companies) {
                  if (companies.isEmpty) {
                    return const MlEmptyState(
                      icon: Icons.domain_outlined,
                      title: 'No other companies to add yet.',
                      message: 'Companies appear here once MineLink has '
                          'connected you to them.',
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: companies.length,
                    itemBuilder: (context, i) {
                      final c = companies[i];
                      final picked = _selected.containsKey(c.id);
                      // Unavailable for one of two different reasons, and the
                      // subtitle says which — "greyed out with no explanation"
                      // is the thing that generates support tickets.
                      final typeTaken = !picked && _orgTypeTaken(c.orgType);
                      final full = !picked && _selected.length >= _maxOthers;
                      final disabled = typeTaken || full;
                      return CheckboxListTile(
                        value: picked,
                        onChanged: disabled
                            ? null
                            : (v) => setState(() {
                                  if (v == true) {
                                    _selected[c.id] = c.orgType;
                                  } else {
                                    _selected.remove(c.id);
                                  }
                                }),
                        title: Text(c.companyName),
                        subtitle: Text(
                          typeTaken
                              ? 'Already have a ${c.orgType.name} in this group'
                              : full
                                  ? 'Group is full — three companies maximum'
                                  : c.orgType.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: disabled
                                ? semantic.textFaint
                                : semantic.textMuted,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          // At least one other company: a "group" of one is a note to self.
          onPressed: _saving || _selected.isEmpty ? null : _create,
          child: Text(_saving ? 'Creating…' : 'Create and invite'),
        ),
      ],
    );
  }
}
