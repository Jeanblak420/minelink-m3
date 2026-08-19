import 'package:flutter/material.dart';

import 'package:flutter_application_1/features/portal/widgets/ml/ml.dart';

/// What the driver filled in on the hazard report sheet. The caller supplies
/// the position (reports are always made AT the reporter's current location)
/// and performs the actual `HazardService.report` insert.
typedef HazardReportDraft = ({
  String type,
  String severity,
  String description,
});

/// Bottom sheet collecting a hazard report (phase-5 T7 / design §3.4):
/// hazard type + severity + optional description. Returns the draft, or null
/// when dismissed. Reusable from the nav screen and (later) the mine
/// security screen.
Future<HazardReportDraft?> showHazardReportSheet(BuildContext context) {
  return showModalBottomSheet<HazardReportDraft>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const HazardReportSheet(),
  );
}

class HazardReportSheet extends StatefulWidget {
  const HazardReportSheet({super.key});

  @override
  State<HazardReportSheet> createState() => _HazardReportSheetState();
}

class _HazardReportSheetState extends State<HazardReportSheet> {
  // Wire strings of `mine_hazards.hazard_type` / `.severity`.
  static const _types = [
    (wire: 'blasting', label: 'Blasting Zone'),
    (wire: 'pothole', label: 'Pothole'),
    (wire: 'slow_haulage', label: 'Slow Haulage'),
    (wire: 'road_closure', label: 'Road Closure'),
  ];

  String _type = 'pothole';
  String _severity = 'medium';
  final _description = TextEditingController();

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return SafeArea(
      child: Padding(
        // Keep the sheet above the keyboard while typing a description.
        padding: EdgeInsets.fromLTRB(
            20, 18, 20, 18 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const MlIconWell(
                  icon: Icons.warning_amber_rounded,
                  tone: MlTone.warn,
                  size: 40,
                  radius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Report a hazard',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: semantic.textStrong)),
                    Text('Placed at your current position on the road.',
                        style: TextStyle(
                            fontSize: 12.5, color: semantic.textMuted)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _type,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Hazard type'),
              items: [
                for (final t in _types)
                  DropdownMenuItem(value: t.wire, child: Text(t.label)),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'low', label: Text('Low')),
                ButtonSegment(value: 'medium', label: Text('Medium')),
                ButtonSegment(value: 'critical', label: Text('Critical')),
              ],
              selected: {_severity},
              onSelectionChanged: (s) =>
                  setState(() => _severity = s.first),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _description,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'e.g. Deep pothole on the left lane',
              ),
            ),
            const SizedBox(height: 16),
            MlButton.primary(
              label: 'Report hazard',
              icon: Icons.campaign_outlined,
              onPressed: () => Navigator.pop(context, (
                type: _type,
                severity: _severity,
                description: _description.text.trim(),
              )),
            ),
            const SizedBox(height: 6),
            MlButton.ghost(
              label: 'Cancel',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
