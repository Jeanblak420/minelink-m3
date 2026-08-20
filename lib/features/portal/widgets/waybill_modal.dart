import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import 'package:flutter_application_1/core/routing/waybill_link.dart';
import 'package:flutter_application_1/features/portal/models/waybill_data.dart';
import 'package:flutter_application_1/features/portal/services/trip_waybill_builder.dart';
import 'package:flutter_application_1/features/portal/services/waybill_pdf.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';

/// Pops up the **real, linked waybill** for a trip as an in-app modal — the same
/// server-authoritative copy the Load Controller / Driver see (built from
/// `get_trip_waybill` via [buildTripWaybill]). Renders the non-editable Manual
/// Waybill PDF inside the dialog with print/share still available.
///
/// Used to turn a recon-table WAYBILL NUMBER into a clickable hyperlink that
/// opens the actual document (CLAUDE.md §4 recon tables + waybill).
Future<void> showWaybillModal(
  BuildContext context,
  WidgetRef ref, {
  required String tripId,
  String? waybillNumber,

  /// Fetches the document. Defaults to [buildTripWaybill] — the real,
  /// server-authoritative path — and exists only so a test can render this
  /// modal at all.
  ///
  /// Without the seam it cannot be pumped: `buildTripWaybill` reads
  /// `lifecycleServiceProvider`, whose `LifecycleService` assigns
  /// `SupabaseConfig.client` in a **field initializer**, so it throws on
  /// construction with no session — and a provider override cannot help,
  /// because even a subclass runs the parent's initializers. The alternative
  /// was leaving the modal untestable, which is how the copy control this
  /// seam was added for would have shipped unproven.
  @visibleForTesting
  Future<WaybillData?> Function(WidgetRef, String)? fetch,
}) {
  // Read the location HERE, from the caller's context, not inside the dialog.
  // `showDialog` pushes onto the root navigator, so the dialog's context sits
  // outside the route subtree that `GoRouterState.of` resolves against — it
  // throws there. Every call site is inside a route builder, so this is the
  // one place the question can be asked reliably.
  final currentPath = _currentPath(context);

  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _WaybillModal(
      ref: ref,
      tripId: tripId,
      waybillNumber: waybillNumber,
      currentPath: currentPath,
      fetch: fetch ?? buildTripWaybill,
    ),
  );
}

/// The router's current path, or '' when it cannot be determined.
///
/// Never throws: a modal that fails to open because a link button could not
/// work out its own URL would be a poor trade.
String _currentPath(BuildContext context) {
  try {
    return GoRouter.of(context)
        .routeInformationProvider
        .value
        .uri
        .path;
  } catch (_) {
    return '';
  }
}

class _WaybillModal extends StatefulWidget {
  const _WaybillModal({
    required this.ref,
    required this.tripId,
    required this.waybillNumber,
    required this.currentPath,
    required this.fetch,
  });

  final WidgetRef ref;
  final String tripId;
  final String? waybillNumber;

  /// Where the viewer was when they opened this — decides which org's waybill
  /// route the copied link points at. See `core/routing/waybill_link.dart`.
  final String currentPath;

  final Future<WaybillData?> Function(WidgetRef, String) fetch;

  @override
  State<_WaybillModal> createState() => _WaybillModalState();
}

class _WaybillModalState extends State<_WaybillModal> {
  late Future<WaybillData?> _future;

  /// Set for a moment after a successful copy so the control can confirm
  /// itself. A `SnackBar` was the obvious choice and the wrong one: the
  /// `ScaffoldMessenger` sits below the navigator overlay, so the bar appears
  /// *behind* the dialog's barrier — dimmed, at the bottom, under the thing
  /// you are looking at. Confirming on the button you just pressed needs no
  /// overlay at all.
  bool _copied = false;

  /// Held so [dispose] can cancel it. An uncancelled `Future.delayed` keeps
  /// running after the dialog is closed — harmless in the app, because the
  /// `mounted` check swallows it, but it leaves a pending timer that fails
  /// any widget test which taps the control and finishes inside the window.
  Timer? _copiedReset;

  @override
  void initState() {
    super.initState();
    _future = widget.fetch(widget.ref, widget.tripId);
  }

  @override
  void dispose() {
    _copiedReset?.cancel();
    super.dispose();
  }

  String? get _route =>
      waybillRouteFor(currentPath: widget.currentPath, tripId: widget.tripId);

  Future<void> _copyLink() async {
    final route = _route;
    if (route == null) return;
    await Clipboard.setData(ClipboardData(
      text: waybillLinkToCopy(base: Uri.base, route: route, isWeb: kIsWeb),
    ));
    if (!mounted) return;
    setState(() => _copied = true);
    // Long enough to read, short enough that the control does not stay in a
    // state that no longer describes the clipboard.
    _copiedReset?.cancel();
    _copiedReset = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final number = widget.waybillNumber?.trim();
    final title =
        (number == null || number.isEmpty) ? 'Waybill' : 'Waybill $number';

    return Dialog(
      backgroundColor: semantic.surfaceCard,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MlTokens.rLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
              child: Row(
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 20, color: semantic.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontFamily: MlTokens.fontSans,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: semantic.textStrong,
                      ),
                    ),
                  ),
                  // Only where a waybill route actually exists for this shell
                  // — null on the super-admin console, which can open this
                  // modal but has no `/super-admin/**/waybill` route to link
                  // to. Offering a button that copies a URL the presser
                  // cannot open is worse than offering none.
                  if (_route != null)
                    IconButton(
                      tooltip: _copied
                          ? 'Link copied'
                          : 'Copy a link to this waybill',
                      icon: Icon(
                        _copied ? Icons.check_rounded : Icons.link_rounded,
                        size: 20,
                        color: _copied
                            ? MlTone.done.colors(Theme.of(context).brightness).fg
                            : null,
                      ),
                      onPressed: _copied ? null : _copyLink,
                    ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: semantic.borderCard),
            Expanded(
              child: FutureBuilder<WaybillData?>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return _Message(
                      icon: Icons.error_outline_rounded,
                      text: 'Could not load waybill: ${snap.error}',
                    );
                  }
                  final data = snap.data;
                  if (data == null) {
                    return const _Message(
                      icon: Icons.description_outlined,
                      text: 'No waybill is available for this trip yet.',
                    );
                  }
                  final fileLabel = data.waybillNumber.trim().isEmpty
                      ? data.fleetReg
                      : data.waybillNumber.trim();
                  return PdfPreview(
                    build: (format) => WaybillPdfBuilder.build(data),
                    useActions: true,
                    allowPrinting: true,
                    allowSharing: true,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    pdfFileName: 'Waybill $fileLabel.pdf',
                    loadingWidget: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: semantic.textFaint),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: semantic.textMuted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
