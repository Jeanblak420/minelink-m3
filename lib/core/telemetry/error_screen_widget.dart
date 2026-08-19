import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// What the user sees when a widget throws during build.
///
/// `ErrorWidget.builder` was never set, so in a release build this was
/// Flutter's default: a grey box, no words, and — because the app renders on
/// canvas — nothing the user could copy or act on. On a mine site that reads as
/// "the app is broken", with no way to tell anyone what broke.
///
/// ## Constraints this runs under, which shape everything below
///
/// It is called **from inside a failed build**, so it must assume almost
/// nothing:
///
/// * there may be no `Directionality` ancestor — hence the explicit one;
/// * `Theme.of(context)` may not resolve, so every colour is a token constant
///   rather than a `MlSemantic.of(context)` lookup;
/// * it must not itself throw, or Flutter replaces it with the grey box anyway
///   and the whole exercise is moot. Nothing here reads a provider, touches
///   the network or does layout that can overflow — the text wraps and the
///   whole thing scrolls.
///
/// It deliberately does **not** show the exception text in release. A stack
/// trace on a driver's phone helps nobody there and can leak identifiers; it
/// goes to `crashReporter` instead, where support can read it. In debug it is
/// shown, because that is when it is useful.
Widget mlErrorWidgetBuilder(FlutterErrorDetails details) {
  return _MlErrorPanel(details: details);
}

class _MlErrorPanel extends StatelessWidget {
  const _MlErrorPanel({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    // Dark is the app's default theme and the only one that can be assumed
    // without resolving a Theme, which may be what failed.
    const bg = MlTokens.navy900;
    const ink = MlTokens.inkOnFill;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: bg,
        padding: const EdgeInsets.all(20),
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: MlTokens.amber500,
                    size: 30,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This part of the screen could not be shown',
                    style: TextStyle(
                      fontFamily: MlTokens.fontSans,
                      fontSize: MlTokens.fsBody,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Says what to do, and what is already true — the report has
                  // been recorded whether or not they tell anyone.
                  const Text(
                    'The rest of the app still works. Go back and try again, '
                    'and if it keeps happening tell your administrator what '
                    'you were doing — the fault has been recorded.',
                    style: TextStyle(
                      fontFamily: MlTokens.fontSans,
                      fontSize: MlTokens.fsBodySm,
                      height: 1.45,
                      color: MlTokens.slate300,
                    ),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 14),
                    Text(
                      details.exceptionAsString(),
                      style: const TextStyle(
                        fontFamily: MlTokens.fontMono,
                        fontSize: MlTokens.fsMicro,
                        color: MlTokens.red400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
