import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/widgets/multi_file_drop_picker.dart';
import 'package:flutter_application_1/features/portal/models/transportation_request.dart';
import 'package:flutter_application_1/features/portal/providers/request_provider.dart';
import 'package:flutter_application_1/features/portal/services/request_service.dart';
import 'package:flutter_application_1/features/portal/widgets/location_picker.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

/// Buyer → "Request products": ask MineLink to source a mineral product.
/// Submitted as a `product` request to the super-admin review queue.
/// Pass [existing] (a sent-back request) to edit + resubmit instead (§4).
Future<void> showProductRequestDialog(
  BuildContext context,
  WidgetRef ref,
  String buyerCompanyId, {
  TransportationRequest? existing,
}) {
  return _showRequestDialog(
    context: context,
    ref: ref,
    companyId: buyerCompanyId,
    requestType: 'product',
    existing: existing,
    icon: Icons.add_shopping_cart_rounded,
    title: 'Request products',
    blurb: 'Ask MineLink to source a mineral product for you.',
    productLabel: 'Product',
    productHint: 'e.g. Chrome 38/40, Coal RB2',
    tonsLabel: 'Tons required / month',
    showDestination: true,
    showLocation: false,
    showPricing: true,
    showSpecs: false,
    showTransaction: false,
    showLabResults: false,
    showImage: false,
    onDone: () {
      ref.invalidate(companyRequestsProvider(buyerCompanyId));
      ref.invalidate(adminRequestQueueProvider('product'));
    },
  );
}

/// Mine → "Request buyers": ask the platform to connect the mine with buyers.
/// Submitted as a `buyer` request to the super-admin review queue.
/// Pass [existing] (a sent-back request) to edit + resubmit instead (§4).
Future<void> showBuyersRequestDialog(
  BuildContext context,
  WidgetRef ref,
  String mineCompanyId, {
  TransportationRequest? existing,
}) {
  return _showRequestDialog(
    context: context,
    ref: ref,
    companyId: mineCompanyId,
    requestType: 'buyer',
    existing: existing,
    icon: Icons.group_add_rounded,
    title: 'Request buyers',
    blurb:
        'Ask the platform to connect you with more buyers for your minerals.',
    productLabel: 'Mineral / product you supply',
    productHint: 'e.g. Chrome 38/40',
    tonsLabel: 'Tons available / month',
    showDestination: false,
    showLocation: true,
    showPricing: true,
    showSpecs: true,
    showTransaction: true,
    showLabResults: true,
    showImage: true,
    onDone: () {
      ref.invalidate(companyRequestsProvider(mineCompanyId));
      ref.invalidate(adminRequestQueueProvider('buyer'));
    },
  );
}

Future<void> _showRequestDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String companyId,
  required String requestType,
  required IconData icon,
  required String title,
  required String blurb,
  required String productLabel,
  required String productHint,
  required String tonsLabel,
  required bool showDestination,
  required bool showLocation,
  required bool showPricing,
  required bool showSpecs,
  required bool showTransaction,
  required bool showLabResults,
  required bool showImage,
  required VoidCallback onDone,
  TransportationRequest? existing,
}) async {
  final editing = existing != null;
  final product = TextEditingController(text: existing?.commodity ?? '');
  final tons = TextEditingController(text: existing?.tonsAvailable ?? '');
  final destination =
      TextEditingController(text: existing?.offloadingPoint ?? '');
  final location = TextEditingController(text: existing?.loadingPoint ?? '');
  final specs =
      TextEditingController(text: existing?.productSpecifications ?? '');
  final price = TextEditingController(
      text: existing?.pricePerTon?.toStringAsFixed(2) ?? '');
  final notes = TextEditingController(text: existing?.routeNotes ?? '');
  final formKey = GlobalKey<FormState>();
  // Dropdowns only prefill values that are still valid options.
  String? paymentTerms =
      RequestOptions.paymentTerms.contains(existing?.paymentTerms)
          ? existing?.paymentTerms
          : null;
  String? transactionKind =
      const ['FOB', 'FOT'].contains(existing?.transactionKind)
          ? existing?.transactionKind
          : null;
  var labFiles = <PickedRequestFile>[];
  var imageFiles = <PickedRequestFile>[];
  // Attachments already on the sent-back request; kept on resubmit unless
  // removed here. New uploads are appended (image: replaces).
  var keptLabPaths = List<String>.of(existing?.labResultPaths ?? const []);
  String? keptImagePath = existing?.productImagePath;
  var submitting = false;

  String attachmentName(String path) {
    final base = path.split('/').last;
    return base.replaceFirst(RegExp(r'^[0-9a-fA-F-]{36}_'), '');
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (ctx, setState) {
        final scheme = Theme.of(ctx).colorScheme;

        Future<void> submit() async {
          if (!(formKey.currentState?.validate() ?? false)) return;
          setState(() => submitting = true);
          try {
            final service = ref.read(requestServiceProvider);

            // Upload attachments first so the row write carries their paths;
            // when editing, kept originals ride along with the new uploads.
            var labPaths = List<String>.of(keptLabPaths);
            String? imagePath = keptImagePath;
            if (labFiles.isNotEmpty) {
              labPaths.addAll(await service.uploadRequestDocs(companyId, [
                for (final f in labFiles) (name: f.name, bytes: f.bytes),
              ]));
            }
            if (imageFiles.isNotEmpty) {
              final uploaded = await service.uploadRequestDocs(companyId, [
                (name: imageFiles.first.name, bytes: imageFiles.first.bytes),
              ]);
              imagePath = uploaded.first;
            }

            final draft = RequestDraft(
              requestType: requestType,
              commodity: _clean(product.text),
              tonsAvailable: _clean(tons.text),
              offloadingPoint: showDestination
                  ? _clean(destination.text)
                  : null,
              loadingPoint: showLocation ? _clean(location.text) : null,
              paymentTerms: showPricing ? paymentTerms : null,
              pricePerTon: showPricing
                  ? double.tryParse(price.text.trim())
                  : null,
              transactionKind: showTransaction ? transactionKind : null,
              productSpecifications: showSpecs ? _clean(specs.text) : null,
              labResultPaths: labPaths,
              productImagePath: imagePath,
              routeNotes: _clean(notes.text),
            );
            if (editing) {
              await service.resubmit(existing.id, draft);
            } else {
              await service.submit(companyId, draft);
            }
            onDone();
            if (ctx.mounted) Navigator.of(ctx).pop();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(editing
                      ? 'Request resubmitted to MineLink for review.'
                      : 'Request sent to MineLink for approval.'),
                ),
              );
            }
          } catch (e) {
            if (ctx.mounted) {
              setState(() => submitting = false);
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text('Could not send request. ${friendlyError(e)}')),
              );
            }
          }
        }

        return AlertDialog(
          title: Row(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(title)),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      editing
                          ? 'MineLink sent this request back — update the '
                              'details below and resubmit.'
                          : blurb,
                      style: context.mlText.bodyMedium.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (editing && existing.adminNotes != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: scheme.tertiaryContainer.withValues(
                            alpha: 0.4,
                          ),
                          borderRadius: MlShape.radiusMedium,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.assignment_return_outlined,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(existing.adminNotes!)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: product,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: productLabel,
                        hintText: productHint,
                        prefixIcon: const Icon(Icons.diamond_outlined),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: tons,
                      keyboardType: TextInputType.number,
                      // `keyboardType` only chooses a soft keyboard; on
                      // web and desktop it stops nothing, and the spec
                      // says numeric input only. Commas and a point are
                      // allowed because the hint offers "4,000" and the
                      // value is cleaned before it is sent.
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
                      ],
                      decoration: InputDecoration(
                        labelText: tonsLabel,
                        hintText: 'e.g. 4,000',
                        prefixIcon: const Icon(Icons.scale_outlined),
                        // CLAUDE.md §4 Request 2: "numeric input only; app
                        // auto-appends a visible `t` suffix (e.g. 200t,
                        // 4000t)". The unit was missing entirely, so a figure
                        // typed here read as a bare number on a form that also
                        // asks for a price and a percentage.
                        suffixText: 't',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    if (showSpecs) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: specs,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Product specifications',
                          hintText: 'Grade, size, moisture, lab values…',
                          prefixIcon: Icon(Icons.science_outlined),
                        ),
                      ),
                    ],
                    if (showPricing) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: paymentTerms,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Payment terms',
                          prefixIcon: Icon(Icons.payments_outlined),
                        ),
                        items: [
                          for (final t in RequestOptions.paymentTerms)
                            DropdownMenuItem(value: t, child: Text(t)),
                        ],
                        onChanged: (v) => setState(() => paymentTerms = v),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: price,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Price per ton',
                          prefixText: 'R ',
                          prefixIcon: Icon(Icons.sell_outlined),
                        ),
                      ),
                    ],
                    if (showTransaction) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        // A DropdownButtonFormField lays its selected item out at its NATURAL
                        // width and sizes to the WIDEST item in the list, so one long option
                        // decides the control's width whatever is selected (CLAUDE.md §10.4).
                        isExpanded: true,
                        initialValue: transactionKind,
                        decoration: const InputDecoration(
                          labelText: 'Transaction',
                          prefixIcon: Icon(Icons.swap_horiz_rounded),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'FOB',
                            child: Text('FOB — Free on board'),
                          ),
                          DropdownMenuItem(
                            value: 'FOT',
                            child: Text('FOT — Free on truck'),
                          ),
                        ],
                        onChanged: (v) => setState(() => transactionKind = v),
                      ),
                    ],
                    if (showDestination) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: destination,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Preferred destination',
                          hintText: 'e.g. Vanderbijlpark',
                          prefixIcon: Icon(Icons.warehouse_outlined),
                        ),
                      ),
                    ],
                    if (showLocation) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: location,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Product location',
                          hintText: 'Type an address, or pick it on the map →',
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.map_outlined),
                            tooltip: 'Pick on map',
                            onPressed: () async {
                              final link = await showLocationPickerDialog(
                                ctx,
                                initial: _clean(location.text),
                              );
                              if (link != null && ctx.mounted) {
                                setState(() => location.text = link);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                    if (editing &&
                        (keptLabPaths.isNotEmpty ||
                            keptImagePath != null)) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Current attachments (kept on resubmit)',
                        style: context.mlText.bodySmall.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final p in keptLabPaths)
                            InputChip(
                              avatar: const Icon(
                                Icons.picture_as_pdf_outlined,
                                size: 16,
                              ),
                              label: Text(
                                attachmentName(p),
                                style: const TextStyle(fontSize: 12),
                              ),
                              onDeleted: submitting
                                  ? null
                                  : () => setState(
                                      () => keptLabPaths.remove(p)),
                            ),
                          if (keptImagePath != null)
                            InputChip(
                              avatar: const Icon(
                                Icons.image_outlined,
                                size: 16,
                              ),
                              label: Text(
                                attachmentName(keptImagePath!),
                                style: const TextStyle(fontSize: 12),
                              ),
                              onDeleted: submitting
                                  ? null
                                  : () =>
                                      setState(() => keptImagePath = null),
                            ),
                        ],
                      ),
                    ],
                    if (showLabResults) ...[
                      const SizedBox(height: 16),
                      MultiFileDropPicker(
                        label: 'Lab results / reports (PDF)',
                        hint:
                            'Drag & drop PDFs here, or click to browse.\nMultiple files allowed — add them together or one by one.',
                        icon: Icons.picture_as_pdf_outlined,
                        allowMultiple: true,
                        allowedExtensions: const ['pdf'],
                        files: labFiles,
                        enabled: !submitting,
                        onChanged: (next) => setState(() => labFiles = next),
                      ),
                    ],
                    if (showImage) ...[
                      const SizedBox(height: 16),
                      MultiFileDropPicker(
                        label: 'Picture / image / photo (optional)',
                        hint: 'Drag & drop an image here, or click to browse.',
                        icon: Icons.add_photo_alternate_outlined,
                        allowMultiple: false,
                        allowedExtensions: const [
                          'png',
                          'jpg',
                          'jpeg',
                          'webp',
                          'heic',
                        ],
                        files: imageFiles,
                        enabled: !submitting,
                        onChanged: (next) => setState(() => imageFiles = next),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notes,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: submitting ? null : submit,
              icon: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(submitting
                  ? 'Sending…'
                  : editing
                      ? 'Resubmit'
                      : 'Send request'),
            ),
          ],
        );
      },
    ),
  );

  product.dispose();
  tons.dispose();
  destination.dispose();
  location.dispose();
  specs.dispose();
  price.dispose();
  notes.dispose();
}

String? _clean(String v) => v.trim().isEmpty ? null : v.trim();
