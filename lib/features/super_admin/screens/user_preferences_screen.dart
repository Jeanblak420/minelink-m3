import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/design/tokens/ui_prefs.dart';
import 'package:flutter_application_1/features/super_admin/widgets/super_admin_dashboard_widgets.dart';

/// Settings → User Preferences — per-user appearance & accessibility for the
/// Super-Admin console (the design's Appearance panel relocated from the
/// floating palette button / top-bar theme toggle into Settings).
///
///  - Appearance/Display: light/dark mode, accent colour, canvas texture.
///  - Console sidebar: Classic / Haul / Weighbridge.
///  - Accessibility: text size, high contrast, bold text.
///
/// Everything here is saved to the signed-in admin's account only and never
/// affects other users.
class UserPreferencesScreen extends ConsumerWidget {
  const UserPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(uiPrefsProvider);
    final notifier = ref.read(uiPrefsProvider.notifier);
    final s = MlSemantic.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SaSectionHeader(
                  title: 'Appearance / Display',
                  subtitle:
                      'Theme mode, accent colour and workspace display — how the console looks for you.',
                ),
                const SizedBox(height: 14),
                _PrefsCard(
                  children: [
                    const _GroupLabel('Mode'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _ModeButton(
                            label: 'Light',
                            icon: Icons.light_mode_outlined,
                            selected: !prefs.darkMode,
                            accent: prefs.accent.color,
                            onTap: () => notifier.setDarkMode(false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ModeButton(
                            label: 'Dark',
                            icon: Icons.dark_mode_outlined,
                            selected: prefs.darkMode,
                            accent: prefs.accent.color,
                            onTap: () => notifier.setDarkMode(true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _GroupLabel('Accent'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final a in ConsoleAccent.values)
                          _AccentSwatch(
                            accent: a,
                            selected: a == prefs.accent,
                            onTap: () => notifier.setAccent(a),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      prefs.accent.label,
                      style: TextStyle(fontSize: 12, color: s.textMuted),
                    ),
                    const SizedBox(height: 18),
                    _SwitchRow(
                      title: 'Canvas texture',
                      description:
                          'Engineering dot-grid and soft brand washes behind the light workspace.',
                      value: prefs.canvasTexture,
                      onChanged: notifier.setCanvasTexture,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const SaSectionHeader(
                  title: 'Accessibility',
                  subtitle:
                      'Text size, high contrast and font adjustments — applied across the console.',
                ),
                const SizedBox(height: 14),
                _PrefsCard(
                  children: [
                    Row(
                      children: [
                        const Expanded(child: _GroupLabel('Text size')),
                        Text(
                          '${(prefs.textScale * 100).round()}%',
                          style: TextStyle(
                            fontFamily: MlTokens.fontMono,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: s.textStrong,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: prefs.textScale,
                      min: 0.85,
                      max: 1.3,
                      divisions: 9,
                      label: '${(prefs.textScale * 100).round()}%',
                      onChanged: notifier.setTextScale,
                    ),
                    const SizedBox(height: 8),
                    _SwitchRow(
                      title: 'High contrast',
                      description:
                          'Strengthens text and border contrast throughout the console.',
                      value: prefs.highContrast,
                      onChanged: notifier.setHighContrast,
                    ),
                    const SizedBox(height: 4),
                    _SwitchRow(
                      title: 'Bold text',
                      description: 'Renders console text with heavier weights.',
                      value: prefs.boldText,
                      onChanged: notifier.setBoldText,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        size: 15, color: s.textMuted),
                    const SizedBox(width: 6),
                    // Expanded, so the sentence wraps instead of pushing the
                    // row over (CLAUDE.md 10.4). Wrapping rather than
                    // ellipsising: it is one short line telling the admin
                    // where these settings live, and half of it is no use.
                    Expanded(
                      child: Text(
                        'Saved to your account only',
                        style: TextStyle(fontSize: 12, color: s.textMuted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// White design card (surface-card fill, card border, lg radius).
class _PrefsCard extends StatelessWidget {
  final List<Widget> children;
  const _PrefsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final s = MlSemantic.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: s.surfaceCard,
        borderRadius: BorderRadius.circular(MlTokens.rLg),
        border: Border.all(color: s.borderCard),
        boxShadow: MlTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// Uppercase micro group label (design's "MODE" / "ACCENT" captions).
class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final s = MlSemantic.of(context);
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: MlTokens.fontSans,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.66,
        color: s.textFaint,
      ),
    );
  }
}

/// Light/Dark segmented button — selected state fills with the accent.
class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = MlSemantic.of(context);
    return Material(
      color: selected ? accent : s.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: MlShape.radiusMedium,
        side: BorderSide(color: selected ? accent : s.borderStrong),
      ),
      child: InkWell(
        borderRadius: MlShape.radiusMedium,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18, color: selected ? MlTokens.inkOnFill : s.textBody),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? MlTokens.inkOnFill : s.textBody,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Accent colour swatch (32px rounded square, ring when selected).
class _AccentSwatch extends StatelessWidget {
  final ConsoleAccent accent;
  final bool selected;
  final VoidCallback onTap;
  const _AccentSwatch({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = MlSemantic.of(context);
    return Tooltip(
      message: accent.label,
      child: InkWell(
        borderRadius: MlShape.radiusMedium,
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: accent.color,
            borderRadius: MlShape.radiusMedium,
            border: Border.all(
              width: 2.5,
              color: selected ? s.textStrong : Colors.transparent,
            ),
          ),
          child: selected
              ? const Icon(Icons.check_rounded, size: 16, color: MlTokens.inkOnFill)
              : null,
        ),
      ),
    );
  }
}

/// Titled switch row with a muted one-line description (design's
/// notification-prefs row pattern).
class _SwitchRow extends StatelessWidget {
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final s = MlSemantic.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: s.textStrong,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(fontSize: 13, color: s.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
