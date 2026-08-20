import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/features/operations/models/operations_models.dart';
import 'package:flutter_application_1/features/portal/providers/logistics_provider.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

/// Buyer "Waybills" (§7.4): the transactions where the buyer participates,
/// grouped per route. Tap a waybill to edit its Destination, Product and
/// Order number (persisted onto the transaction metadata).
class BuyerWaybillsScreen extends ConsumerWidget {
  const BuyerWaybillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const PortalCompanyRequired();
    }
    final mirror = portalMirrorActive(ref);
    final async = ref.watch(logisticsSnapshotProvider(companyId));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => MlLoadFailure(
          subject: 'the waybills',
          error: e,
          onRetry: () => ref.invalidate(logisticsSnapshotProvider(companyId)),
      ),
      data: (snap) {
        // Group by route ("loading → offloading") from metadata.
        final groups = <String, List<OperationTransaction>>{};
        for (final w in snap.waybills) {
          final from = (w.metadata['loading_point'] as String?) ?? '—';
          final to = (w.metadata['offloading_point'] as String?) ?? '—';
          groups.putIfAbsent('$from → $to', () => []).add(w);
        }
        final routeKeys = groups.keys.toList()..sort();

        return MlPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MlPageHeader(
                title: 'Waybills',
                meta: '${mlCount(snap.waybills.length, 'waybill')} · '
                    '${mlCount(routeKeys.length, 'route')}',
                description:
                    'Your transactions per route. Tap a waybill to edit destination, '
                    'product and order number.',
              ),
              const SizedBox(height: 16),
              if (snap.waybills.isEmpty)
                MlCard(
                  child: MlEmptyState(
                    icon: Icons.description_outlined,
                    title: 'No waybills yet.',
                    message:
                        'Waybills appear here as transactions are created for your routes.',
                  ),
                )
              else
                for (final route in routeKeys) ...[
                  MlSectionTitle(route,
                      icon: Icons.alt_route_outlined,
                      meta: mlCount(groups[route]!.length, 'waybill'),
                      margin: const EdgeInsets.only(bottom: 10)),
                  MlCard(
                    padding: const EdgeInsets.all(18),
                    child: MlDataTable(
                      onRowTap: mirror
                          ? null
                          : (i) => _editWaybill(
                              context, ref, companyId, groups[route]![i]),
                      columns: const [
                        // NOT "Waybill #". This renders
                        // `transactions.reference_number` -- the TRANSACTION
                        // reference -- and tapping a row edits the transaction,
                        // not the waybill. The waybill is a generated,
                        // non-editable PDF whose NUMBER happens to be this same
                        // reference; calling the column "Waybill #" on an
                        // editable row invited the reader to think they were
                        // editing a waybill (P8-20).
                        MlColumn('Transaction ref', flex: 2),
                        MlColumn('Product', flex: 2),
                        MlColumn('Order', flex: 2),
                        MlColumn('Status', flex: 2, align: TextAlign.right),
                        MlColumn('', width: 32, align: TextAlign.right),
                      ],
                      rows: [
                        for (final w in groups[route]!)
                          [
                            MlPlatePill(w.referenceNumber),
                            _cell(context,
                                (w.metadata['commodity'] as String?) ?? '—'),
                            _cell(context,
                                (w.metadata['order_no'] as String?) ?? '—'),
                            MlStatusBadge.forStatus(
                                w.status.replaceAll('_', ' ')),
                            mirror
                                ? const SizedBox()
                                : Icon(Icons.edit_outlined,
                                    size: 18,
                                    color: MlSemantic.of(context).textFaint),
                          ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
            ],
          ),
        );
      },
    );
  }

  Widget _cell(BuildContext context, String text) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: MlTokens.fontSans,
          fontSize: 14,
          color: MlSemantic.of(context).textBody,
        ),
      );

  Future<void> _editWaybill(
    BuildContext context,
    WidgetRef ref,
    String companyId,
    OperationTransaction w,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<_WaybillEdit>(
      context: context,
      builder: (_) => _WaybillEditDialog(waybill: w),
    );
    if (result == null) return;
    try {
      await ref.read(logisticsServiceProvider).updateWaybill(
            w.id,
            w.metadata,
            destination: result.destination,
            product: result.product,
            orderNo: result.orderNo,
          );
      ref.invalidateIfMounted(logisticsSnapshotProvider(companyId));
      messenger.showSnackBar(
          const SnackBar(content: Text('Waybill updated.')));
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text('Could not update waybill. ${friendlyError(e)}')));
    }
  }
}

class _WaybillEdit {
  final String destination;
  final String product;
  final String orderNo;
  const _WaybillEdit(this.destination, this.product, this.orderNo);
}

class _WaybillEditDialog extends StatefulWidget {
  final OperationTransaction waybill;
  const _WaybillEditDialog({required this.waybill});

  @override
  State<_WaybillEditDialog> createState() => _WaybillEditDialogState();
}

class _WaybillEditDialogState extends State<_WaybillEditDialog> {
  late final TextEditingController _destination;
  late final TextEditingController _product;
  late final TextEditingController _orderNo;

  @override
  void initState() {
    super.initState();
    final m = widget.waybill.metadata;
    _destination =
        TextEditingController(text: (m['offloading_point'] as String?) ?? '');
    _product = TextEditingController(text: (m['commodity'] as String?) ?? '');
    _orderNo = TextEditingController(text: (m['order_no'] as String?) ?? '');
  }

  @override
  void dispose() {
    _destination.dispose();
    _product.dispose();
    _orderNo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // Cold-phone audit 2026-08-18: this dialog holds input fields and did
      // not scroll, so at a large text size on a narrow phone its content
      // overflowed the viewport and the fields below the fold could not be
      // reached. Measured at 133px of clipped content on the token
      // generator, which is the same shape. `scrollable` only engages when
      // the content exceeds the space, so it is inert on a desktop.
      scrollable: true,
      title: Text('Edit waybill ${widget.waybill.referenceNumber}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _destination,
              decoration: const InputDecoration(
                labelText: 'Destination',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _product,
              decoration: const InputDecoration(
                labelText: 'Product',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _orderNo,
              decoration: const InputDecoration(
                labelText: 'Order no.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_WaybillEdit(
            _destination.text.trim(),
            _product.text.trim(),
            _orderNo.text.trim(),
          )),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
