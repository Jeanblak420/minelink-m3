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
String formatTokenExpiresRemaining(DateTime expiresAt, {bool compact = false}) {
  final d = expiresAt.difference(DateTime.now());
  if (d.isNegative) return 'Expired';
  final days = d.inDays;
  final hours = d.inHours.remainder(24);
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60);
  if (compact) {
    return '${days}d ${hours}h ${minutes}m ${seconds}s';
  }
  return '$days days, $hours hours, $minutes minutes, '
      '${seconds.toString().padLeft(2, '0')} seconds';
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
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
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
    final remaining = widget.expiresAt.difference(DateTime.now());
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
