/// "Export profile PDF" — renders the live profile (identity, contact,
/// documents, productivity, activity) into a shareable PDF. Real data only:
/// the caller passes exactly what the screen is showing.
library;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:flutter_application_1/features/employee/services/employee_profile_service.dart';

Future<void> exportEmployeeProfilePdf({
  required EmployeeProfileBundle bundle,
  required List<ProfileMetric> metrics,
  required List<ProfileActivityItem> activity,
  required List<ProfileDocItem> docs,
  required List<ProfileFlag> flags,
}) async {
  final e = bundle.person.employee;
  final roleLabel = profileRoleLabel(bundle.company.orgType, e.role);
  final doc = pw.Document();

  pw.Widget kv(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(children: [
          pw.SizedBox(
            width: 130,
            child: pw.Text(k,
                style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                    fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(child: pw.Text(v, style: const pw.TextStyle(fontSize: 10))),
        ]),
      );

  pw.Widget section(String title, List<pw.Widget> children) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 14),
          pw.Text(title,
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.2)),
          pw.Divider(color: PdfColors.grey400, thickness: 0.5),
          ...children,
        ],
      );

  String hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Text(e.fullName,
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.Text(
            '$roleLabel · ${bundle.company.name} · ${bundle.company.orgType.label}',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text(
            'Exported ${DateTime.now()} · Live profile snapshot — MineLink',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        section('CONTACT & IDENTITY', [
          kv('Employee ID', profileEmpCode(e)),
          kv('Role', roleLabel),
          if (bundle.person.email != null) kv('Email', bundle.person.email!),
          kv('WhatsApp', e.whatsappNumber),
          if (e.idNumber?.isNotEmpty == true) kv('ID number', e.idNumber!),
          if (bundle.person.whatsappOnly)
            kv('Account', 'WhatsApp-only — signs in with their WhatsApp number'),
          kv('Joined', e.createdAt.toString().substring(0, 10)),
          kv('Status', e.status ?? 'active'),
        ]),
        if (metrics.isNotEmpty)
          section("TODAY'S PRODUCTIVITY", [
            for (final m in metrics)
              kv(m.label, '${m.value}${m.unit} — ${m.sub}'),
          ]),
        if (docs.isNotEmpty)
          section('DOCUMENTS · ${docs.length}', [
            for (final d in docs)
              kv(d.title, '${d.statusLabel} · ${d.subtitle}'),
          ]),
        if (activity.isNotEmpty)
          section('ACTIVITY · LAST 24H', [
            for (final a in activity)
              kv(a.isNow ? 'now' : hm(a.at), '${a.bold}${a.rest}'),
          ]),
        if (flags.isNotEmpty)
          section('NOTES & FLAGS', [
            for (final f in flags) kv(f.title, f.body),
          ]),
      ],
    ),
  );

  final safe = e.fullName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
  await Printing.sharePdf(bytes: await doc.save(), filename: 'profile_$safe.pdf');
}
