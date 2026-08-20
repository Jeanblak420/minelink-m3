import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_motion.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// MineLink modal: navy scrim (~45%), 16px card, fade+pop entrance,
/// title row with close button, optional footer action row.
Future<T?> showMlModal<T>(
  BuildContext context, {
  required String title,
  required Widget child,
  List<Widget>? footer,
  double width = 460,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: title,
    barrierColor: MlTokens.barrierStrong,
    transitionDuration: MlMotion.of(context, MlMotion.enter),
    pageBuilder: (context, _, __) {
      final semantic = MlSemantic.of(context);
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: width,
                maxHeight: MediaQuery.sizeOf(context).height * 0.86,
              ),
              child: Material(
                color: semantic.surfaceCard,
                borderRadius: BorderRadius.circular(MlTokens.rLg),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(22, 18, 14, 18),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: semantic.divider),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontFamily: MlTokens.fontSans,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: semantic.textStrong,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            icon: Icon(
                              Icons.close_rounded,
                              color: semantic.textMuted,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(22),
                        child: child,
                      ),
                    ),
                    if (footer != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: semantic.surfaceApp,
                          border: Border(
                            top: BorderSide(color: semantic.divider),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            for (var i = 0; i < footer.length; i++) ...[
                              if (i > 0) const SizedBox(width: 10),
                              footer[i],
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: MlMotion.curveOf(context, MlMotion.decelerate),
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween(begin: 0.98, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

/// MineLink slide-over record panel: right-anchored, drawer shadow,
/// 280ms ease-out-cubic translate, ~32% navy scrim.
Future<T?> showMlSlideOver<T>(
  BuildContext context, {
  required String title,
  required Widget child,
  double width = 380,
  List<Widget>? footer,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: MlTokens.barrierSoft,
    transitionDuration: MlMotion.of(context, MlMotion.page),
    pageBuilder: (context, _, __) {
      final semantic = MlSemantic.of(context);
      final maxW = MediaQuery.sizeOf(context).width * 0.92;
      return Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: width > maxW ? maxW : width,
          height: double.infinity,
          // A slide-over needs its OWN messenger and Scaffold, or every message
          // it raises is thrown away.
          //
          // `showGeneralDialog` pushes onto the root navigator, and this panel
          // used to be a bare `Material` — no `Scaffold` anywhere inside it. A
          // `ScaffoldMessenger.of(context)` call from a sheet therefore resolved
          // to the app-level messenger, whose only registered Scaffold is the
          // page *behind* the dialog barrier, so the SnackBar was never seen.
          //
          // Found 2026-08-17 at the weighbridge: recording a load on a
          // seal-required route without seals returned **HTTP 400** from
          // `record_truck_load`, the sheet's catch block called its `_snack`
          // with "Could not record load. …", and nothing appeared. Polled the
          // semantics tree for 9.6 s: no message of any kind. The Load
          // Controller pressed Confirm, watched the button flicker "Saving…",
          // and was told nothing at all about why the load would not save.
          child: ScaffoldMessenger(
            child: Scaffold(
              backgroundColor: semantic.surfaceCard,
              body: Material(
                color: semantic.surfaceCard,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(22, 16, 12, 16),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: semantic.divider),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: MlTokens.fontSans,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: semantic.textStrong,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close',
                              icon: Icon(
                                Icons.close_rounded,
                                color: semantic.textMuted,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(22),
                          child: child,
                        ),
                      ),
                      if (footer != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: semantic.divider),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < footer.length; i++) ...[
                                if (i > 0) const SizedBox(height: 10),
                                footer[i],
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: MlMotion.curveOf(context, MlMotion.decelerate),
      );
      return SlideTransition(
        position: Tween(
          begin: const Offset(1.05, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}
