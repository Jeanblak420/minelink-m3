import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_application_1/core/services/storage_asset_service.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';

/// Opens the POD photo at [path] (private `pod_photos` bucket) via a
/// short-lived signed URL. Every party on the trip's transaction — mine,
/// buyer, transporter and the platform admin — is allowed by the storage RLS.
Future<void> openPodPhoto(
  BuildContext context,
  WidgetRef ref,
  String path,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final url =
        await ref.read(storageAssetServiceProvider).resolvePodPhotoUrl(path);
    if (url == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the POD photo.')),
      );
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not open the POD photo.')),
    );
  }
}

/// Compact "view proof of delivery" affordance: a photo icon that opens the
/// POD picture, or a muted dash when none was uploaded yet.
class PodPhotoIcon extends ConsumerWidget {
  const PodPhotoIcon({super.key, required this.path, this.size = 18});

  final String? path;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = path?.trim();
    if (p == null || p.isEmpty) {
      return Center(
        child: Text('—',
            style: TextStyle(color: MlSemantic.of(context).textFaint)),
      );
    }
    return IconButton(
      tooltip: 'View proof of delivery',
      icon: Icon(Icons.photo_outlined, size: size),
      visualDensity: VisualDensity.compact,
      onPressed: () => openPodPhoto(context, ref, p),
    );
  }
}
