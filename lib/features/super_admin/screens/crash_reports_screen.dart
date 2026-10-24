import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/super_admin/data/models/models.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/core/telemetry/crash_reporter.dart';
import 'package:intl/intl.dart';

/// Super-global admin console: read-only viewer over `public.crash_reports`
/// (Task 2 created the table, Task 3 fills it from `SupabaseReportingSink`).
///
/// The table has a SELECT policy gated to `is_platform_admin()` and no
/// UPDATE/DELETE policy at all — a crash report is not editable, and it is
/// removed only by `prune_telemetry_job()` at the 90-day retention window.
/// This screen offers no mutation, matching that: no claim/approve/reject
/// flow like `TokenRequestsScreen`, just a filterable, expandable list.
///
/// [reports] lets a test (or a future caller) inject rows directly, bypassing
/// the Riverpod provider and the database entirely. That path filters
/// client-side over the injected list (there is no database to push the
/// filter into); the live path filters server-side — see
/// `crashReportsProvider`.
class CrashReportsScreen extends ConsumerStatefulWidget {
  final List<CrashReportRow>? reports;

  const CrashReportsScreen({super.key, this.reports});

  @override
  ConsumerState<CrashReportsScreen> createState() =>
      _CrashReportsScreenState();
}

class _CrashReportsScreenState extends ConsumerState<CrashReportsScreen> {
  bool _fatalOnly = false;
  String? _platform;
  String? _appVersion;
  String? _expandedId;

  List<CrashReportRow> _filteredLocally(List<CrashReportRow> all) {
    var out = all;
    if (_fatalOnly) out = out.where((r) => r.fatal).toList();
    if (_platform != null) {
      out = out.where((r) => r.platform == _platform).toList();
    }
    if (_appVersion != null) {
      out = out.where((r) => r.appVersion == _appVersion).toList();
    }
    return [...out]..sort((a, b) => b.at.compareTo(a.at));
  }

  List<String> _distinct(Iterable<String?> values) {
    final out = values.whereType<String>().where((v) => v.isNotEmpty).toSet().toList();
    out.sort();
    return out;
  }

  /// Pushes one report through the app's real reporter — the same sink every
  /// crash uses — and checks that it reached the table.
  ///
  /// Nothing arrived after 17 Oct, and nothing on this screen could tell a
  /// quiet app from a broken pipeline (admin phone audit, 2026-10-24). The
  /// table accepted a signed-in user's insert when probed, the reporter is
  /// wired at start-up, and the last reports were a since-fixed storm — so
  /// the quiet looks genuine, but this button is how anyone can prove it.
  Future<void> _sendTestReport() async {
    final messenger = ScaffoldMessenger.of(context);
    // The time makes the message unique, so finding it proves THIS report
    // arrived, not an earlier test.
    final message = 'Test report sent from the Crash reports screen at '
        '${DateFormat('HH:mm:ss').format(MlTime.now())} — not an error.';
    crashReporter.recordError(message, StackTrace.current,
        context: 'test report');
    messenger.showSnackBar(
        const SnackBar(content: Text('Test report sent — checking it arrived…')));
    final filters = (fatalOnly: false, platform: null, appVersion: null);
    for (var attempt = 0; attempt < 5; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      // A failed read is "not seen yet", never an escaped error: the screen
      // must always end by saying whether the report arrived.
      List<CrashReportRow> rows;
      try {
        rows = await ref
            .read(superAdminRepositoryProvider)
            .getCrashReports(limit: 5);
      } catch (_) {
        rows = const <CrashReportRow>[];
      }
      final arrived = rows.any((r) => r.error.startsWith(message));
      if (arrived) {
        ref.invalidate(crashReportsProvider(filters));
        ref.invalidate(crashReportsProvider(
            (fatalOnly: _fatalOnly, platform: _platform, appVersion: _appVersion)));
        ref.invalidate(crashReportTotalProvider);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
              content: Text('Test report received — crash reporting works.')));
        return;
      }
    }
    if (!mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        backgroundColor: MlTokens.red600,
        content: Text('The test report did not arrive within 10 seconds. '
            'Crash reporting from this device is not reaching the server.'),
      ));
  }

  void _onExpand(String id) =>
      setState(() => _expandedId = _expandedId == id ? null : id);

  @override
  Widget build(BuildContext context) {
    final injected = widget.reports;
    if (injected != null) {
      return _CrashReportsBody(
        rows: _filteredLocally(injected),
        platforms: _distinct(injected.map((r) => r.platform)),
        appVersions: _distinct(injected.map((r) => r.appVersion)),
        fatalOnly: _fatalOnly,
        platform: _platform,
        appVersion: _appVersion,
        expandedId: _expandedId,
        onFatalOnlyChanged: (v) => setState(() => _fatalOnly = v),
        onPlatformChanged: (v) => setState(() => _platform = v),
        onAppVersionChanged: (v) => setState(() => _appVersion = v),
        onExpand: _onExpand,
      );
    }

    final filters =
        (fatalOnly: _fatalOnly, platform: _platform, appVersion: _appVersion);
    final rowsAsync = ref.watch(crashReportsProvider(filters));
    final total = ref.watch(crashReportTotalProvider(filters)).valueOrNull;
    final facets = ref.watch(crashReportFacetsProvider).valueOrNull;

    return rowsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => MlEmptyState(
        icon: Icons.error_outline,
        title: 'Could not load crash reports',
        message: friendlyError(e),
      ),
      data: (rows) => _CrashReportsBody(
        rows: rows,
        total: total,
        onSendTest: _sendTestReport,
        platforms: (facets?.platforms.toList() ?? const <String>[])..sort(),
        appVersions: (facets?.appVersions.toList() ?? const <String>[])
          ..sort(),
        fatalOnly: _fatalOnly,
        platform: _platform,
        appVersion: _appVersion,
        expandedId: _expandedId,
        onFatalOnlyChanged: (v) => setState(() => _fatalOnly = v),
        onPlatformChanged: (v) => setState(() => _platform = v),
        onAppVersionChanged: (v) => setState(() => _appVersion = v),
        onExpand: _onExpand,
      ),
    );
  }
}

/// The actual page content, split out so both the injected-data path and the
/// provider-backed path render through one place. Not a [Scaffold] itself —
/// it is always hosted inside exactly one, either [CrashReportsScreen]'s own
/// (the live route) or the caller's (tests wrap it in one directly).
class _CrashReportsBody extends StatelessWidget {
  final List<CrashReportRow> rows;

  /// Every report matching the filters (the list stops at the newest 500).
  final int? total;

  /// "Send a test report"; null where there is no live reporter (tests that
  /// inject rows).
  final Future<void> Function()? onSendTest;
  final List<String> platforms;
  final List<String> appVersions;
  final bool fatalOnly;
  final String? platform;
  final String? appVersion;
  final String? expandedId;
  final ValueChanged<bool> onFatalOnlyChanged;
  final ValueChanged<String?> onPlatformChanged;
  final ValueChanged<String?> onAppVersionChanged;
  final ValueChanged<String> onExpand;

  const _CrashReportsBody({
    required this.rows,
    this.total,
    this.onSendTest,
    required this.platforms,
    required this.appVersions,
    required this.fatalOnly,
    required this.platform,
    required this.appVersion,
    required this.expandedId,
    required this.onFatalOnlyChanged,
    required this.onPlatformChanged,
    required this.onAppVersionChanged,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The shared page header, not a hand-rolled 16px sans title: every
        // other console screen opens in the Fraunces display face through
        // MlPageHeader, with a description and the count on the right.
        // Found 2026-08-23 in the Phase 3 pass.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: MlPageHeader(
            title: 'Crash reports',
            description:
                'Errors the app reported about itself — newest first, fatal '
                'ones marked.',
            // The real number. It said "500 fingerprints": the length of the
            // newest-500 page, under 9,243 reports.
            meta: total == null || total! <= rows.length
                ? mlCount(total ?? rows.length, 'report')
                : '${NumberFormat.decimalPattern().format(total)} reports '
                    '· newest ${rows.length} shown',
            padding: EdgeInsets.zero,
          ),
        ),
        // When the last one arrived, so a silence is visible — and a way to
        // check the silence is real.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                rows.isEmpty
                    ? 'No reports received.'
                    : 'Last report received ${MlTime.ago(rows.first.at)}.',
                style: context.mlText.bodySmall.copyWith(
                  color: MlSemantic.of(context).textMuted,
                ),
              ),
              if (onSendTest != null)
                MlButton.outline(
                  label: 'Send a test report',
                  icon: Icons.send_outlined,
                  compact: true,
                  onPressed: () => onSendTest!(),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Fatal only'),
                  selected: fatalOnly,
                  onSelected: onFatalOnlyChanged,
                ),
                for (final p in platforms) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(p),
                    selected: platform == p,
                    onSelected: (sel) => onPlatformChanged(sel ? p : null),
                  ),
                ],
                for (final v in appVersions) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('v$v'),
                    selected: appVersion == v,
                    onSelected: (sel) => onAppVersionChanged(sel ? v : null),
                  ),
                ],
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: rows.isEmpty
              ? const MlEmptyState(
                  icon: Icons.bug_report_outlined,
                  title: 'Nothing broke',
                  message: 'No crash reports in the last 90 days.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    return _CrashReportCard(
                      report: r,
                      expanded: expandedId == r.id,
                      onTap: () => onExpand(r.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CrashReportCard extends StatelessWidget {
  final CrashReportRow report;
  final bool expanded;
  final VoidCallback onTap;

  const _CrashReportCard({
    required this.report,
    required this.expanded,
    required this.onTap,
  });

  String _contextLabel() {
    final parts = <String>[
      if (report.platform != null && report.platform!.isNotEmpty)
        report.platform!,
      if (report.appVersion != null && report.appVersion!.isNotEmpty)
        'v${report.appVersion}',
    ];
    return parts.isEmpty ? 'Unknown context' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final tone = report.fatal ? MlTone.error : MlTone.neutral;

    return MlCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MlIconWell(
                icon: report.fatal
                    ? Icons.report_gmailerrorred_rounded
                    : Icons.warning_amber_rounded,
                tone: tone,
                size: 40,
                radius: 11,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Text(
                            report.errorFirstLine,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.mlText.titleSmall.copyWith(
                              color: semantic.textStrong,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        MlStatusBadge(
                          label: report.fatal ? 'Fatal' : 'Handled',
                          tone: tone,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 13, color: semantic.textFaint),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            MlTime.stamp(report.at),
                            overflow: TextOverflow.ellipsis,
                            style: context.mlText.code(
                              color: semantic.textFaint,
                              size: 12,
                              weight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.smartphone_rounded,
                            size: 13, color: semantic.textFaint),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _contextLabel(),
                            overflow: TextOverflow.ellipsis,
                            style: context.mlText.bodySmall.copyWith(
                              color: semantic.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                color: semantic.textFaint,
              ),
            ],
          ),
          if (expanded) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: semantic.divider),
            const SizedBox(height: 12),
            // A stack trace is the widest text in this app — it must scroll
            // inside its own box, never push this card (or the page)
            // sideways. Keyed so the test suite can find this exact box
            // (there may be several cards expanded/collapsed in a sweep).
            if (report.stack != null && report.stack!.isNotEmpty)
              SizedBox(
                key: ValueKey('stack-scroll-${report.id}'),
                width: double.infinity,
                // A stack frame past the right edge is a stack frame nobody
                // knows is there.
                child: MlWideTable(
                  child: Text(
                    report.stack!,
                    style: TextStyle(
                      fontFamily: MlTokens.fontMono,
                      fontSize: 12,
                      height: 1.4,
                      color: semantic.textBody,
                    ),
                  ),
                ),
              )
            else
              Text(
                'No stack trace recorded.',
                style: context.mlText.bodyMedium.copyWith(
                  color: semantic.textFaint,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
