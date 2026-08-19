library;

/// Whether the platform is asking for reduced motion, on platforms where
/// Flutter does not report it itself.
///
/// Flutter 3.44 does not surface the browser's `prefers-reduced-motion` in
/// `MediaQuery.disableAnimations` on web — the engine registers the media query
/// but the accessibility feature does not reach the framework, so a person who
/// has asked their system to reduce motion still gets the sign-in panel's rings,
/// sweep, aurora and dust. Measured on Chrome 151 with the setting on:
/// `matchMedia('(prefers-reduced-motion: reduce)').matches` was true while
/// `MediaQuery.disableAnimations` was false.
///
/// Returns null when there is nothing extra to add and `MediaQuery` should be
/// trusted on its own (every non-web target — there Flutter reads the OS
/// setting properly).
///
/// Same conditional-export shape as
/// `auth/services/session_manager_browser_bridge.dart`.
/// `dart.library.html` rather than `dart.library.js_interop`: the same condition
/// `session_manager_browser_bridge.dart` uses, which is known to resolve to the
/// web implementation in this project's dart2js build.
export 'platform_reduce_motion_stub.dart'
    if (dart.library.html) 'platform_reduce_motion_web.dart';
