import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/widgets/minelink_logo.dart';
import 'package:flutter_application_1/core/design/tokens/ml_auth_tokens.dart';
import 'package:flutter_application_1/features/auth/widgets/signin/minelink_signin_brand.dart';

/// MineLink auth chrome (2026-08-05 dark login mock): the WHOLE page is deep
/// navy — a brand rail with a faint grid, white/gold logo and platform stats
/// on wide screens, and the auth form on dark chrome beside it, headed by the
/// chain-link mark. Auth is always dark regardless of the app theme.
class AuthShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final bool showBackButton;
  final VoidCallback? onBack;

  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.showBackButton = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    // Force dark styling for the whole auth surface (mock): controls, text
    // and MlSemantic all resolve dark inside this subtree.
    return Theme(
      data: AppTheme.darkTheme,
      child: Builder(builder: _buildShell),
    );
  }

  Widget _buildShell(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = MlSemantic.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 980;

    final form = SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showBackButton)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.chevron_left_rounded, size: 18),
                  label: const Text('Back'),
                  style: TextButton.styleFrom(
                    foregroundColor: semantic.textMuted,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            // Chain-link mark headers the form (full logo on phones, where
            // there is no brand rail).
            Center(
              child: wide
                  ? const MineLinkMark(size: 140, onDark: true)
                  : const MineLinkLogo(height: 132, onDark: true),
            ),
            const SizedBox(height: 26),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.28,
                color: MlAuth.shellInkHi,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 15,
                color: MlAuth.shellInkMid,
              ),
            ),
            const SizedBox(height: 28),
            child,
            if (footer != null) ...[
              const SizedBox(height: 28),
              footer!,
            ],
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: MlAuth.shellSurface,
      body: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _AuthRail(),
                Expanded(child: Center(child: form)),
              ],
            )
          : Center(child: form),
    );
  }
}

class _AuthRail extends StatelessWidget {
  const _AuthRail();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 460,
      padding: const EdgeInsets.all(44),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MlTokens.navy700, MlTokens.navy800, MlTokens.navy950],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: const _RailBackdropPainter(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mock: white/gold logo, left-aligned at the top of the rail.
            const Align(
              alignment: Alignment.topLeft,
              child: MineLinkLogo(width: 290, onDark: true),
            ),
            const Spacer(),
            const Text(
              'MINERAL LOGISTICS, CONNECTED',
              style: TextStyle(
                fontFamily: MlTokens.fontSans,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.1,
                color: MlTokens.accent,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'From the mine gate to the offload point — every ton tracked.',
              style: TextStyle(
                fontFamily: MlTokens.fontSans,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                height: 1.2,
                letterSpacing: -0.3,
                color: MlTokens.inkOnFill,
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(
              width: 330,
              child: Text(
                'Loading, security, haulage and reconciliation for mines, buyers '
                'and transporters — on one premium platform.',
                style: TextStyle(
                  fontFamily: MlTokens.fontSans,
                  fontSize: 15,
                  height: 1.6,
                  color: MlAuth.shellInkBody,
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Read from `kMlPlaceholderBrandStats`, not typed out again.
            //
            // These same three figures were written here a second time, as
            // strings (`'24+'`, `'480'`, `'1.2M t'`), while the sign-in panel
            // held them as `MlBrandStat`s. `no-hardcoded-brand-stat` matches
            // `MlBrandStat(value: <digit>`, so it watched that copy and was
            // blind to this one — on the two screens (`/forgot-password`,
            // `/reset-password`) this shell actually renders. Same numbers,
            // one source, and the guard now covers every place they appear.
            Row(
              children: [
                for (var i = 0; i < kMlPlaceholderBrandStats.length; i++) ...[
                  if (i > 0) const SizedBox(width: 26),
                  _RailStat(stat: kMlPlaceholderBrandStats[i]),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RailStat extends StatelessWidget {
  final MlBrandStat stat;

  const _RailStat({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(stat.icon, size: 20, color: MlTokens.accent),
        const SizedBox(height: 6),
        Text(
          '${stat.value.toStringAsFixed(stat.decimals)}${stat.suffix}',
          style: const TextStyle(
            fontFamily: MlTokens.fontSans,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: MlTokens.inkOnFill,
          ),
        ),
        Text(
          stat.label,
          style: const TextStyle(
            fontFamily: MlTokens.fontSans,
            fontSize: 12,
            color: MlAuth.shellInkMuted,
          ),
        ),
      ],
    );
  }
}

/// Faint 40px grid + a radial cyan glow in the rail's top-right corner.
class _RailBackdropPainter extends CustomPainter {
  const _RailBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = MlAuth.shellHairline
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += 40) {
      canvas.drawLine(Offset(x, -44), Offset(x, size.height + 44), grid);
    }
    for (double y = 0; y <= size.height; y += 40) {
      canvas.drawLine(Offset(-44, y), Offset(size.width + 44, y), grid);
    }
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          MlTokens.accent.withValues(alpha: 0.22),
          MlTokens.accent.withValues(alpha: 0),
        ],
      ).createShader(
        Rect.fromCircle(center: Offset(size.width + 36, -36), radius: 320),
      );
    canvas.drawCircle(Offset(size.width + 36, -36), 320, glow);
  }

  @override
  bool shouldRepaint(covariant _RailBackdropPainter oldDelegate) => false;
}
