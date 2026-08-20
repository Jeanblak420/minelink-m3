import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/portal/portal_colors.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

/// A compact "take picture" slot: shows a capture button, then a thumbnail of
/// the captured image with change/remove actions. Tries the camera first and
/// falls back to the gallery (e.g. on desktop where the camera is unsupported).
class PhotoCaptureField extends StatefulWidget {
  final String label;
  final ValueChanged<XFile?>? onChanged;

  const PhotoCaptureField({super.key, required this.label, this.onChanged});

  @override
  State<PhotoCaptureField> createState() => _PhotoCaptureFieldState();
}

class _PhotoCaptureFieldState extends State<PhotoCaptureField> {
  final _picker = ImagePicker();
  XFile? _file;

  Future<void> _capture() async {
    XFile? picked;
    try {
      picked = await _picker.pickImage(
          source: ImageSource.camera, maxWidth: 1600, imageQuality: 70);
    } catch (_) {
      // Camera unsupported (common on desktop) — fall back to file/gallery.
      try {
        picked = await _picker.pickImage(
            source: ImageSource.gallery, maxWidth: 1600, imageQuality: 70);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not capture image. ${friendlyError(e)}')),
          );
        }
        return;
      }
    }
    if (picked != null) {
      if (mounted) setState(() => _file = picked);
      widget.onChanged?.call(picked);
    }
  }

  void _remove() {
    setState(() => _file = null);
    widget.onChanged?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final captured = _file != null;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: MlSemantic.of(context).surfaceCard,
        borderRadius: MlShape.radiusMedium,
        border: Border.all(
          color: captured
              ? PortalColors.accent.withValues(alpha: 0.6)
              : MlSemantic.of(context).borderCard,
        ),
      ),
      child: Row(
        children: [
          _thumb(scheme),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.label,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  captured ? 'Captured' : 'No picture yet',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: captured
                            ? PortalColors.accent
                            : scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          if (captured)
            IconButton(
              tooltip: 'Remove',
              onPressed: _remove,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          TextButton.icon(
            onPressed: _capture,
            icon: Icon(captured ? Icons.refresh_rounded : Icons.camera_alt_outlined,
                size: 18),
            label: Text(captured ? 'Retake' : 'Take picture'),
          ),
        ],
      ),
    );
  }

  Widget _thumb(ColorScheme scheme) {
    const size = 44.0;
    if (_file == null) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: MlShape.radiusMedium,
          border: Border.all(color: MlSemantic.of(context).borderCard),
        ),
        child: Icon(Icons.image_outlined, size: 20, color: scheme.onSurfaceVariant),
      );
    }
    return ClipRRect(
      borderRadius: MlShape.radiusMedium,
      child: kIsWeb
          ? Image.network(_file!.path, width: size, height: size, fit: BoxFit.cover)
          : Image.file(File(_file!.path), width: size, height: size, fit: BoxFit.cover),
    );
  }
}
