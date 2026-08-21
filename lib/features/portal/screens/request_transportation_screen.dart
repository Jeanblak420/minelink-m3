import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/features/portal/models/available_route.dart';
import 'package:flutter_application_1/features/portal/models/transportation_request.dart';
import 'package:flutter_application_1/features/portal/portal_colors.dart';
import 'package:flutter_application_1/features/portal/providers/request_provider.dart';
import 'package:flutter_application_1/features/portal/services/request_service.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// Buyer "Request Transportation" form + revise-and-resubmit (§7.5).
///
/// Pass [existing] to re-open a sent-back request for editing; otherwise a new
/// request is created and submitted to the MineLink representative.
///
/// Pass [prefill] (an assigned Available route, §4) to auto-fill the form
/// from a learned route — the requester can edit anything before submitting.
class RequestTransportationScreen extends ConsumerStatefulWidget {
  final TransportationRequest? existing;
  final AvailableRoute? prefill;
  const RequestTransportationScreen({super.key, this.existing, this.prefill});

  @override
  ConsumerState<RequestTransportationScreen> createState() =>
      _RequestTransportationScreenState();
}

class _RequestTransportationScreenState
    extends ConsumerState<RequestTransportationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Free-text controllers.
  final _loadingPoint = TextEditingController();
  final _offloadingPoint = TextEditingController();
  final _commodity = TextEditingController();
  final _distance = TextEditingController();
  final _rate = TextEditingController();
  final _tonsAvailable = TextEditingController();
  final _contractDuration = TextEditingController();
  final _numSlots = TextEditingController();
  final _routeNotes = TextEditingController();

  // Controlled inputs.
  String? _paymentTerms;
  String? _diesel;
  bool _hours24 = false;
  TimeOfDay? _start;
  TimeOfDay? _end;
  DateTime? _startingDate;
  DateTime? _endingDate;
  bool _ongoing = false;
  bool _sealRequired = false;

  bool _saving = false;

  static final _dateFmt = DateFormat('EEE, dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _paymentTerms = e.paymentTerms;
      _diesel = e.diesel;
      _hours24 = e.operatingHours24h;
      _start = _parseTime(e.operatingStart);
      _end = _parseTime(e.operatingEnd);
      _startingDate = e.startingDate;
      _endingDate = e.endingDate;
      _ongoing = e.isOngoing;
      _sealRequired = e.sealRequired;
      _loadingPoint.text = e.loadingPoint ?? '';
      _offloadingPoint.text = e.offloadingPoint ?? '';
      _commodity.text = e.commodity ?? '';
      _distance.text = e.distance ?? '';
      _rate.text = e.rate ?? '';
      _tonsAvailable.text = e.tonsAvailable ?? '';
      _contractDuration.text = e.contractDuration ?? '';
      _numSlots.text = e.numSlots ?? '';
      _routeNotes.text = e.routeNotes ?? '';
    }
    final p = widget.prefill;
    if (e == null && p != null) {
      // Auto-fill from the assigned Available route (§4); all editable.
      _loadingPoint.text = p.loadingPoint ?? '';
      _offloadingPoint.text = p.offloadingPoint ?? '';
      _commodity.text = p.commodity ?? '';
      _tonsAvailable.text = p.tons ?? '';
      _numSlots.text = p.numTrucks ?? '';
      _routeNotes.text = p.routeNotes ?? '';
      // Only adopt terms that are still a valid dropdown option.
      if (RequestOptions.paymentTerms.contains(p.paymentTerms)) {
        _paymentTerms = p.paymentTerms;
      }
      _hours24 = p.operatingHours24h;
      _start = _parseTime(p.operatingStart);
      _end = _parseTime(p.operatingEnd);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _loadingPoint,
      _offloadingPoint,
      _commodity,
      _distance,
      _rate,
      _tonsAvailable,
      _contractDuration,
      _numSlots,
      _routeNotes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  TimeOfDay? _parseTime(String? hhmm) {
    if (hhmm == null || !hhmm.contains(':')) return null;
    final parts = hhmm.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  String? _fmtTime(TimeOfDay? t) => t == null
      ? null
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _label(TimeOfDay? t) => t == null ? 'Select' : t.format(context);

  /// Earliest selectable start date: two days after today — today and
  /// tomorrow are always locked (per Jean, 2026-07-12).
  ///
  /// `MlTime.today()`, not `DateTime.now()`. This is a BUSINESS DAY: it
  /// decides which dates the picker will accept and what is written to
  /// `starting_date`, which is exactly what CLAUDE.md §7.1 is about. On a
  /// handset west of SAST the device's day is behind the mine's for part of
  /// every evening, and the earliest bookable start slid a day with it.
  DateTime get _earliest => MlTime.today().add(const Duration(days: 2));

  RequestDraft _draft() => RequestDraft(
    paymentTerms: _paymentTerms,
    diesel: _diesel,
    operatingHours24h: _hours24,
    operatingStart: _fmtTime(_start),
    operatingEnd: _fmtTime(_end),
    startingDate: _startingDate,
    endingDate: _endingDate,
    isOngoing: _ongoing,
    loadingPoint: _text(_loadingPoint),
    offloadingPoint: _text(_offloadingPoint),
    commodity: _text(_commodity),
    distance: _text(_distance),
    rate: _text(_rate),
    tonsAvailable: _text(_tonsAvailable),
    contractDuration: _text(_contractDuration),
    numSlots: _text(_numSlots),
    routeNotes: _text(_routeNotes),
    sealRequired: _sealRequired,
  );

  String? _text(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_hours24 && (_start == null || _end == null)) {
      _snack('Set both start and end times, or choose 24 hours.');
      return;
    }
    if (_startingDate == null) {
      _snack('Pick a start date.');
      return;
    }
    if (!_ongoing) {
      if (_endingDate == null) {
        _snack('Pick an end date, or choose Ongoing.');
        return;
      }
      if (!_endingDate!.isAfter(_startingDate!)) {
        _snack('The end date must be after the start date.');
        return;
      }
    }
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      _snack('Company not loaded.');
      return;
    }
    setState(() => _saving = true);
    final svc = ref.read(requestServiceProvider);
    try {
      if (widget.existing != null) {
        await svc.resubmit(widget.existing!.id, _draft());
      } else {
        await svc.submit(companyId, _draft());
      }
      ref.invalidateIfMounted(companyRequestsProvider(companyId));
      // Refresh the Request tracking table too so the new request shows without
      // a manual refresh.
      ref.invalidateIfMounted(requestTrackingProvider(companyId));
      if (!mounted) return;
      Navigator.of(context).pop(true);
      _snack('Request sent to the MineLink representative.');
    } catch (e) {
      if (mounted) _snack('Could not submit request. ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String m) {
    // Every caller reaches here after an await, so the screen may already be
    // gone; `ScaffoldMessenger.of` would then throw on a deactivated ancestor.
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Revise request' : 'Request transportation'),
        backgroundColor: MlSemantic.of(context).surfaceApp,
        foregroundColor: MlSemantic.of(context).textStrong,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (editing && widget.existing!.adminNotes != null)
                    _SentBackBanner(notes: widget.existing!.adminNotes!),
                  _section('Route'),
                  _textField(_loadingPoint, 'Loading point', required: true),
                  _textField(
                    _offloadingPoint,
                    'Offloading point',
                    required: true,
                  ),
                  _textField(_commodity, 'Commodity', required: true),
                  _textField(_distance, 'Distance'),
                  // CLAUDE.md §4: tonnage carries a visible `t` unit.
                  _textField(_tonsAvailable, 'Tons available', suffix: 't'),
                  _textField(_numSlots, 'Number of Trucks Required'),
                  _textField(_contractDuration, 'Contract duration'),

                  // The only writer for `routes.seal_required` in the product.
                  // The Load Controller's capture rule and record_truck_load's
                  // server-side enforcement both read that column, and until
                  // 2026-08-17 nothing could ever set it — every route in
                  // production had seals off and the whole path was dead code
                  // (migration 20260817170000).
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Seals required'),
                    subtitle: const Text(
                      'Every load must be sealed. The Load Controller cannot '
                      'complete a load without a number and a photo for each seal.',
                    ),
                    value: _sealRequired,
                    activeThumbColor: PortalColors.accent,
                    onChanged: (v) => setState(() => _sealRequired = v),
                  ),

                  _section('Commercials'),
                  _dropdown(
                    label: 'Payment terms',
                    value: _paymentTerms,
                    options: RequestOptions.paymentTerms,
                    onChanged: (v) => setState(() => _paymentTerms = v),
                  ),
                  _dropdown(
                    label: 'Diesel',
                    value: _diesel,
                    options: RequestOptions.diesel,
                    onChanged: (v) => setState(() => _diesel = v),
                  ),
                  _textField(_rate, 'Rate'),

                  _section('Mine loading operation hours'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('24 hours'),
                    subtitle: const Text('Mine operates continuously'),
                    value: _hours24,
                    activeThumbColor: PortalColors.accent,
                    onChanged: (v) => setState(() => _hours24 = v),
                  ),
                  if (!_hours24)
                    Row(
                      children: [
                        Expanded(
                          child: _timeField('Start time', _start, (t) {
                            setState(() => _start = t);
                          }),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _timeField('End time', _end, (t) {
                            setState(() => _end = t);
                          }),
                        ),
                      ],
                    ),

                  _section('Request period'),
                  _dropdown(
                    label: 'Request type',
                    value: _ongoing ? 'Ongoing' : 'Single request',
                    options: const ['Ongoing', 'Single request'],
                    onChanged: (v) => setState(() => _ongoing = v == 'Ongoing'),
                  ),
                  _dateField(
                    label: 'Start date',
                    value: _startingDate,
                    onPick: (d) => setState(() => _startingDate = d),
                  ),
                  if (!_ongoing)
                    _dateField(
                      label: 'End date',
                      value: _endingDate,
                      // End must land after the chosen start.
                      notBefore: _startingDate?.add(const Duration(days: 1)),
                      onPick: (d) => setState(() => _endingDate = d),
                    ),

                  _section('Notes'),
                  _textField(_routeNotes, 'Route notes', maxLines: 4),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: MlTokens.accent,
                        foregroundColor: MlTokens.navy950,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: MlTokens.inkOnFill,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        editing ? 'Re-submit request' : 'Submit request',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    ),
  );

  Widget _textField(
    TextEditingController c,
    String label, {
    bool required = false,
    int maxLines = 1,
    String? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          border: const OutlineInputBorder(),
          alignLabelWithHint: maxLines > 1,
          suffixText: suffix,
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: '$label *',
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final o in options) DropdownMenuItem(value: o, child: Text(o)),
        ],
        onChanged: onChanged,
        validator: (v) => v == null ? 'Required' : null,
      ),
    );
  }

  Widget _timeField(
    String label,
    TimeOfDay? value,
    ValueChanged<TimeOfDay> onPick,
  ) {
    return InkWell(
      onTap: () async {
        final t = await showTimePicker(
          context: context,
          initialTime: value ?? const TimeOfDay(hour: 6, minute: 0),
        );
        if (t != null) onPick(t);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(_label(value)),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime> onPick,
    DateTime? notBefore,
  }) {
    // Today and tomorrow are always locked; earliest is today + 2 days.
    final usesNotBefore = notBefore != null && notBefore.isAfter(_earliest);
    final first = usesNotBefore ? notBefore : _earliest;
    // The end date's floor is the day after the start date, not today+2.
    final helper = usesNotBefore
        ? 'Must be after the start date'
        : 'Earliest selectable date is 2 days from today';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            firstDate: first,
            initialDate: value != null && value.isAfter(first) ? value : first,
            lastDate: DateTime(_earliest.year + 3),
          );
          if (picked != null) onPick(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            helperText: helper,
            border: const OutlineInputBorder(),
          ),
          child: Text(value == null ? 'Select a date' : _dateFmt.format(value)),
        ),
      ),
    );
  }
}

class _SentBackBanner extends StatelessWidget {
  final String notes;
  const _SentBackBanner({required this.notes});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: MlShape.radiusMedium,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.assignment_return_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Returned for changes',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(notes),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
