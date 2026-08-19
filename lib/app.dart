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
    return MaterialApp.router(
      title: AppBranding.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      // User-controlled via the portal app-bar toggle; defaults to dark.
      themeMode: ref.watch(themeModeProvider),
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
