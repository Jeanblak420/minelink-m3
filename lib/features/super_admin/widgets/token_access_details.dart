import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:flutter_application_1/features/super_admin/data/models/serial_token.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// Prefer the newest active token when multiple exist.
SerialToken? pickActiveSerialToken(List<SerialToken> tokens) {
  final active = tokens.where((t) => t.status == 'active').toList()
    ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
  return active.isEmpty ? null : active.first;
}

String formatAccessTimestamp(DateTime utc) {
  return DateFormat('dd-MM-yyyy HH:mm:ss').format(MlTime.sast(utc));
}

DateTime? parseOrgTimestamp(dynamic raw) {
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString());
}

/// Static countdown text (use with a parent timer tick, e.g. Tokens table).
///
/// Two things changed here on 2026-08-21, both found by rendering the
/// organisation detail screen for the first time.
///
/// **The clock.** It read `DateTime.now()` — the device's opinion of the hour,
/// which CLAUDE.md §7.1 keeps out of anything a user reads, and a number that
/// changes every second cannot be photographed at all: the golden differed on
/// every run. `MlTime.instant()` is the real instant and honours the render
/// harness's frozen clock.
///
/// **The seconds.** A year-long countdown printed `308d 9h 9m 29s`, and the
/// widget below redrew every second to advance a figure whose left-hand digits
/// move once a day. Seconds appear under an hour, minutes under a day, and
/// above that the reading is days and hours — which is the precision anybody
/// renewing a token is working at.
String formatTokenExpiresRemaining(DateTime expiresAt, {bool compact = false}) {
  final d = expiresAt.toUtc().difference(MlTime.instant());
  if (d.isNegative) return 'Expired';
  final days = d.inDays;
  final hours = d.inHours.remainder(24);
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60);
  if (compact) {
    if (days > 0) return '${days}d ${hours}h';
    if (d.inHours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m ${seconds}s';
  }
  if (days > 0) {
    return '$days ${days == 1 ? 'day' : 'days'}, '
        '$hours ${hours == 1 ? 'hour' : 'hours'}';
  }
  if (d.inHours > 0) {
    return '$hours ${hours == 1 ? 'hour' : 'hours'}, '
        '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
  }
  return '$minutes ${minutes == 1 ? 'minute' : 'minutes'}, '
      '${seconds.toString().padLeft(2, '0')} seconds';
}

/// How often a countdown to [expiresAt] needs to redraw.
///
/// Matches what [formatTokenExpiresRemaining] actually prints: a second while
/// seconds are on screen, otherwise half a minute. A `Timer.periodic(1s)` that
/// rebuilds a tab to change nothing is not a live readout, it is a repaint
/// loop.
Duration tokenCountdownTick(DateTime expiresAt) {
  final d = expiresAt.toUtc().difference(MlTime.instant());
  return d.inHours >= 1 ? const Duration(seconds: 30) : const Duration(seconds: 1);
}

/// Rows: Token Assigned, Lifetime, Expiration, live countdown — plus optional heading.
class TokenAccessDetailsSection extends StatelessWidget {
  final SerialToken? activeToken;
  final Map<String, dynamic>? companyFallback;

  const TokenAccessDetailsSection({
    super.key,
    required this.activeToken,
    this.companyFallback,
  });

  @override
  Widget build(BuildContext context) {
    final assigned = activeToken?.issuedAt ??
        parseOrgTimestamp(companyFallback?['last_token_generated_at']);
    final lifetime =
        activeToken?.validDays ?? (companyFallback?['token_valid_days'] as int?);
    final expiration = activeToken?.expiresAt ??
        parseOrgTimestamp(companyFallback?['token_expires_at']);

    final hasAnything =
        assigned != null || lifetime != null || expiration != null;

    if (!hasAnything) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No serial access token on record yet.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Access token',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        _InfoRow(
          label: 'Token Assigned',
          value: assigned != null ? formatAccessTimestamp(assigned) : '—',
        ),
        _InfoRow(
          label: 'Token Lifetime',
          value: lifetime != null ? '$lifetime days' : '—',
        ),
        _InfoRow(
          label: 'Token Expiration',
          value:
              expiration != null ? formatAccessTimestamp(expiration) : '—',
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 168,
                child: Text(
                  'Token Expires in',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: expiration != null
                    ? TokenExpiryLiveCountdown(
                        expiresAt: expiration,
                        compact: false,
                      )
                    : const Text('—'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final variant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 168,
            child: Text(label, style: TextStyle(color: variant)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Live countdown to [expiresAt] (absolute expiry instant).
class TokenExpiryLiveCountdown extends StatefulWidget {
  final DateTime expiresAt;
  final bool compact;

  const TokenExpiryLiveCountdown({
    super.key,
    required this.expiresAt,
    this.compact = false,
  });

  @override
  State<TokenExpiryLiveCountdown> createState() =>
      _TokenExpiryLiveCountdownState();
}

class _TokenExpiryLiveCountdownState extends State<TokenExpiryLiveCountdown> {
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = TickerMode.valuesOf(context).enabled;
    if (!enabled) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??=
        Timer.periodic(tokenCountdownTick(widget.expiresAt), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.expiresAt.toUtc().difference(MlTime.instant());
    final text = formatTokenExpiresRemaining(widget.expiresAt, compact: widget.compact);
    final style = widget.compact
        ? Theme.of(context).textTheme.bodyMedium
        : Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: remaining.isNegative
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
            );

    return Text(text, style: style);
  }
}
