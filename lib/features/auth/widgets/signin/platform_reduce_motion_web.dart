/// Web: read `prefers-reduced-motion` from the browser directly, because
/// Flutter does not put it in `MediaQuery.disableAnimations`.
library;

import 'package:web/web.dart' as web;

bool? platformReduceMotion() =>
    web.window.matchMedia('(prefers-reduced-motion: reduce)').matches;
