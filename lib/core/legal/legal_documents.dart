/// The legal documents the app asks people to agree to, and a way to read them.
///
/// The sign-in screen has always said "By signing in you agree to the Terms of
/// Use and Privacy Policy." Until 2026-08-17 that sentence was plain text, and
/// the documents themselves lived in `docs/legal/` — not bundled, not routed,
/// not reachable from anywhere in the running app. The product asserted
/// agreement to two documents no user could open.
///
/// Jean's ruling (2026-08-17): wire it up to the placeholders, clearly headed
/// as drafts, so a person can at least read what is being asserted while the
/// attorney's text is outstanding.
///
/// **The draft banner is shown, not stripped.** Each file opens with a heading
/// saying it has not been reviewed by an attorney, and this viewer surfaces
/// that as the first thing you see. Hiding it would leave the app presenting
/// engineer-drafted text as terms, which is worse than the gap it replaces —
/// and it would leave the `unreplaced-legal-placeholder` guard reading green
/// while placeholder text was live in front of customers.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// One legal document: what to call it, and where it is in the bundle.
class LegalDocument {
  final String title;
  final String assetPath;

  const LegalDocument({required this.title, required this.assetPath});

  static const terms = LegalDocument(
    title: 'Terms of Use',
    assetPath: 'assets/legal/TERMS-OF-USE.placeholder.md',
  );
  static const privacy = LegalDocument(
    title: 'Privacy Policy',
    assetPath: 'assets/legal/PRIVACY-POLICY.placeholder.md',
  );
  static const dataRetention = LegalDocument(
    title: 'Data Retention',
    assetPath: 'assets/legal/DATA-RETENTION.placeholder.md',
  );

  static const all = [terms, privacy, dataRetention];

  Future<String> load() => rootBundle.loadString(assetPath);
}

/// Opens [doc] in a scrollable reader.
///
/// Deliberately a dialog rather than a route: it is opened from the sign-in
/// screen, which is outside the authenticated router, and from a settings entry
/// inside it. One presentation, both places.
Future<void> showLegalDocument(BuildContext context, LegalDocument doc) {
  return showDialog<void>(
    context: context,
    // The close handler is built from the DIALOG's context and handed in, so
    // the pop can never reach the screen underneath. The portal and console are
    // both `ShellRoute`s, where popping with a screen's context removes the page
    // and the app goes white with no exception at all — see
    // `tool/dialog_context_check.py` and
    // `test/widgets/dialog_pops_the_dialog_test.dart`.
    builder: (dialogContext) => _LegalDialog(
      doc: doc,
      onClose: () => Navigator.pop(dialogContext),
    ),
  );
}

class _LegalDialog extends StatelessWidget {
  final LegalDocument doc;
  final VoidCallback onClose;
  const _LegalDialog({required this.doc, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      doc.title,
                      style: const TextStyle(
                        fontFamily: MlTokens.fontSans,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: FutureBuilder<String>(
                future: doc.load(),
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snap.hasError || (snap.data ?? '').trim().isEmpty) {
                    // Say so rather than showing an empty sheet that reads like
                    // a document with nothing in it.
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'This document could not be opened on this device. '
                        'Ask MineLink for a copy before you rely on it.',
                        style: TextStyle(color: scheme.error),
                      ),
                    );
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: _Markdownish(source: snap.data!),
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

/// Just enough Markdown for these documents, without a dependency.
///
/// The three files use headings, bullets, block quotes, bold and horizontal
/// rules — nothing else. Adding `flutter_markdown` to render that would pull a
/// package into the build for four syntaxes, so this handles those four and
/// renders everything else as the plain text it already is. If the real
/// documents arrive with tables or links, swap this for a real renderer rather
/// than growing it.
class _Markdownish extends StatelessWidget {
  final String source;
  const _Markdownish({required this.source});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = context.mlText.bodyMedium.copyWith(
      color: scheme.onSurface,
      height: 1.6,
    );
    final children = <Widget>[];

    for (final raw in source.split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 10));
        continue;
      }
      if (line.startsWith('---')) {
        children.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1),
        ));
        continue;
      }
      final heading = RegExp(r'^(#{1,4})\s+(.*)$').firstMatch(line);
      if (heading != null) {
        final level = heading.group(1)!.length;
        children.add(Padding(
          padding: EdgeInsets.only(top: level == 1 ? 4 : 14, bottom: 4),
          child: Text(
            _plain(heading.group(2)!),
            style: body.copyWith(
              fontSize: level == 1 ? 17 : (level == 2 ? 15 : 13.5),
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
        ));
        continue;
      }
      // A block quote — the draft warning at the top of each file is one, and
      // it is the part that most needs to stand out.
      if (line.startsWith('>')) {
        children.add(Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: scheme.errorContainer.withValues(alpha: 0.35),
            border: Border(
              left: BorderSide(color: scheme.error, width: 3),
            ),
          ),
          child: Text(
            _plain(line.replaceFirst(RegExp(r'^>\s?'), '')),
            style: body.copyWith(fontSize: 13),
          ),
        ));
        continue;
      }
      final bullet = RegExp(r'^\s*[-*]\s+(.*)$').firstMatch(line);
      if (bullet != null) {
        children.add(Padding(
          padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('•  ', style: body),
              Expanded(child: Text(_plain(bullet.group(1)!), style: body)),
            ],
          ),
        ));
        continue;
      }
      children.add(Text(_plain(line), style: body));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  /// Strips the inline markers these documents use. They carry meaning to a
  /// reader of the raw file and only noise to a reader of the rendered one.
  static String _plain(String s) => s
      .replaceAll('**', '')
      .replaceAll('`', '')
      .replaceAllMapped(RegExp(r'(?<!\*)\*(?!\*)'), (_) => '');
}
