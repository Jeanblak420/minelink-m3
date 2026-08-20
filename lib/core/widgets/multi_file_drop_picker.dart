import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';

import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/services/file_selection_service.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

/// A file selected into a [MultiFileDropPicker], held in memory until the
/// owning form is submitted (nothing is uploaded by this control itself).
class PickedRequestFile {
  final String name;
  final Uint8List bytes;

  const PickedRequestFile({required this.name, required this.bytes});
}

/// Unified attachment control (CLAUDE.md §4 "Request Buyer"): a single
/// drag-and-drop zone that is also click-to-browse, so one-by-one adds,
/// multi-select, and multi-file drops all land in the same list.
///
/// Purely a selection control — the parent owns the file list and uploads on
/// submit. Files failing the extension or size rules are rejected with an
/// inline message, never silently dropped.
class MultiFileDropPicker extends StatefulWidget {
  /// Title above the drop zone, e.g. "Lab results / reports (PDF)".
  final String label;

  /// Helper line inside the drop zone.
  final String hint;

  final bool allowMultiple;

  /// Lower-case extensions without dots, e.g. `['pdf']`. Empty = any.
  final List<String> allowedExtensions;

  final int maxSizeBytes;
  final IconData icon;
  final List<PickedRequestFile> files;
  final ValueChanged<List<PickedRequestFile>> onChanged;
  final bool enabled;

  /// Injectable for tests.
  final FileSelectionService? fileSelectionService;

  const MultiFileDropPicker({
    super.key,
    required this.label,
    required this.hint,
    required this.files,
    required this.onChanged,
    this.allowMultiple = true,
    this.allowedExtensions = const [],
    this.maxSizeBytes = 20 * 1024 * 1024,
    this.icon = Icons.upload_file_outlined,
    this.enabled = true,
    this.fileSelectionService,
  });

  @override
  State<MultiFileDropPicker> createState() => _MultiFileDropPickerState();
}

class _MultiFileDropPickerState extends State<MultiFileDropPicker> {
  late final FileSelectionService _files =
      widget.fileSelectionService ?? FileSelectionService();

  bool _dragging = false;
  String? _error;

  bool _extensionAllowed(String name) {
    if (widget.allowedExtensions.isEmpty) return true;
    final dot = name.lastIndexOf('.');
    if (dot == -1 || dot == name.length - 1) return false;
    return widget.allowedExtensions.contains(
      name.substring(dot + 1).toLowerCase(),
    );
  }

  void _addAll(List<PickedRequestFile> incoming) {
    final rejected = <String>[];
    final accepted = <PickedRequestFile>[];
    for (final f in incoming) {
      if (!_extensionAllowed(f.name)) {
        rejected.add('${f.name} — not a ${_extensionLabel()} file');
      } else if (f.bytes.lengthInBytes > widget.maxSizeBytes) {
        rejected.add(
          '${f.name} — larger than ${widget.maxSizeBytes ~/ (1024 * 1024)} MB',
        );
      } else {
        accepted.add(f);
      }
    }

    if (accepted.isNotEmpty) {
      final next = widget.allowMultiple
          ? [...widget.files, ...accepted]
          : [accepted.last];
      widget.onChanged(next);
    }
    setState(() => _error = rejected.isEmpty ? null : rejected.join('\n'));
  }

  String _extensionLabel() => widget.allowedExtensions.isEmpty
      ? 'supported'
      : widget.allowedExtensions.map((e) => e.toUpperCase()).join('/');

  Future<void> _browse() async {
    try {
      final picked = await _files.pickFiles(
        imagesOnly: false,
        allowMultiple: widget.allowMultiple,
        allowedExtensions: widget.allowedExtensions.isEmpty
            ? null
            : widget.allowedExtensions,
      );
      if (picked.isEmpty) return;
      final loaded = <PickedRequestFile>[];
      for (final p in picked) {
        loaded.add(
          PickedRequestFile(name: p.name, bytes: await p.readAsBytes()),
        );
      }
      _addAll(loaded);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not select files. ${friendlyError(e)}');
    }
  }

  Future<void> _onDrop(DropDoneDetails detail) async {
    final loaded = <PickedRequestFile>[];
    for (final f in detail.files) {
      loaded.add(PickedRequestFile(name: f.name, bytes: await f.readAsBytes()));
    }
    if (loaded.isNotEmpty) _addAll(loaded);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = _dragging ? scheme.primary : scheme.outlineVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: context.mlText.titleSmall.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        DropTarget(
          enable: widget.enabled,
          onDragEntered: (_) => setState(() => _dragging = true),
          onDragExited: (_) => setState(() => _dragging = false),
          onDragDone: (detail) {
            setState(() => _dragging = false);
            _onDrop(detail);
          },
          child: InkWell(
            onTap: widget.enabled ? _browse : null,
            borderRadius: MlShape.radiusMedium,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
              decoration: BoxDecoration(
                color: _dragging
                    ? scheme.primary.withValues(alpha: 0.08)
                    : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: MlShape.radiusMedium,
                border: Border.all(
                  color: borderColor,
                  width: _dragging ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    widget.icon,
                    color: _dragging ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.hint,
                    textAlign: TextAlign.center,
                    style: context.mlText.bodyMedium.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _error!,
              style: context.mlText.bodySmall.copyWith(color: scheme.error),
            ),
          ),
        if (widget.files.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < widget.files.length; i++)
                  InputChip(
                    avatar: Icon(
                      _isPdf(widget.files[i].name)
                          ? Icons.picture_as_pdf_outlined
                          : Icons.image_outlined,
                      size: 16,
                    ),
                    label: Text(
                      widget.files[i].name,
                      overflow: TextOverflow.ellipsis,
                    ),
                    labelStyle: const TextStyle(fontSize: 12),
                    onDeleted: widget.enabled
                        ? () {
                            final next = [...widget.files]..removeAt(i);
                            widget.onChanged(next);
                          }
                        : null,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  bool _isPdf(String name) => name.toLowerCase().endsWith('.pdf');
}
