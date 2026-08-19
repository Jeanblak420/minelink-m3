import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_application_1/core/services/storage_asset_service.dart';
import 'package:flutter_application_1/features/portal/models/transportation_request.dart';

/// Lab-result PDFs + the optional product picture attached to a request.
/// Each chip resolves a short-lived signed URL from the private
/// `request_docs` bucket and opens it externally. Shared by the super-admin
/// review panel and the requester's own request cards (§4).
class RequestAttachmentChips extends ConsumerWidget {
  final TransportationRequest request;
  const RequestAttachmentChips({super.key, required this.request});

  static String _displayName(String path) {
    final base = path.split('/').last;
    return base.replaceFirst(RegExp(r'^[0-9a-fA-F-]{36}_'), '');
  }

  Future<void> _open(BuildContext context, WidgetRef ref, String path) async {
    final url = await ref
        .read(storageAssetServiceProvider)
        .resolveRequestDocUrl(path);
    if (url == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the attachment.')),
        );
      }
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attachments',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in request.labResultPaths)
              ActionChip(
                avatar: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: Text(
                  _displayName(p),
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: () => _open(context, ref, p),
              ),
            if (request.productImagePath != null)
              ActionChip(
                avatar: const Icon(Icons.image_outlined, size: 16),
                label: Text(
                  _displayName(request.productImagePath!),
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: () => _open(context, ref, request.productImagePath!),
              ),
          ],
        ),
      ],
    );
  }
}
