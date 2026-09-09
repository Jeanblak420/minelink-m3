import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/core/theme/theme_mode_provider.dart';
import 'package:flutter_application_1/core/constants/app_branding.dart';
import 'package:flutter_application_1/core/routing/app_router.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      // Handle native back button to navigate within the app instead of closing
      // Only intercept when GoRouter can pop (i.e., not at root)
      canPop: _canPopSafely(),
      onPopInvokedWithResult: (didPop, result) {
        // This is called when canPop returns false
        if (!didPop && _canPopSafely()) {
          // Let GoRouter handle the back navigation
          AppRouter.router.pop();
        }
      },
      child: MaterialApp.router(
        title: AppBranding.appName,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        // User-controlled via the portal app-bar toggle; defaults to dark.
        themeMode: ref.watch(themeModeProvider),
        routerConfig: AppRouter.router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }

  /// Safely check if the router can pop without throwing an error
  bool _canPopSafely() {
    try {
      return !AppRouter.router.canPop();
    } catch (e) {
      // If canPop throws (e.g., when router is not yet initialized),
      // assume we cannot pop
      return true;
    }
  }
}
