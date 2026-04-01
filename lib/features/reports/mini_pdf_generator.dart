import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class MiniPDFGenerator {
  static Future<String> generateSingleTestReport({
    required String patientName,
    required String patientPhone,
    required String testName,
    required String summary,
    required String status,
  }) async {
    final pdf = pw.Document();
    final regular = await PdfGoogleFonts.poppinsRegular();
    final bold = await PdfGoogleFonts.poppinsBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#1A237E'),
                    borderRadius: pw.BorderRadius.circular(12),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'AmbyoAI Mini Report',
                        style: pw.TextStyle(font: bold, fontSize: 18, color: PdfColors.white),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
                        style: pw.TextStyle(font: regular, fontSize: 10, color: PdfColors.white),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 18),
                pw.Text('Patient', style: pw.TextStyle(font: bold, fontSize: 14)),
                pw.SizedBox(height: 6),
                pw.Text(patientName, style: pw.TextStyle(font: regular)),
                pw.Text(patientPhone.isEmpty ? '-' : '+91 $patientPhone', style: pw.TextStyle(font: regular)),
                pw.SizedBox(height: 16),
                pw.Text('Test', style: pw.TextStyle(font: bold, fontSize: 14)),
                pw.SizedBox(height: 6),
                pw.Text(testName.replaceAll('_', ' ').toUpperCase(), style: pw.TextStyle(font: regular)),
                pw.SizedBox(height: 16),
                pw.Text('Result', style: pw.TextStyle(font: bold, fontSize: 14)),
                pw.SizedBox(height: 6),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F7F9FC'),
                    borderRadius: pw.BorderRadius.circular(10),
                    border: pw.Border.all(color: PdfColor.fromHex('#D8E0ED')),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(summary, style: pw.TextStyle(font: regular)),
                      pw.SizedBox(height: 6),
                      pw.Text('Status: $status', style: pw.TextStyle(font: bold)),
                    ],
                  ),
                ),
                pw.Spacer(),
                pw.Divider(),
                pw.Text(
                  'This is a screening summary. Clinical diagnosis required.',
                  style: pw.TextStyle(font: regular, fontSize: 10, color: PdfColors.grey700),
                ),
              ],
            ),
          );
        },
      ),
    );

    final output = await getApplicationDocumentsDirectory();
    final fileName =
        'AmbyoAI_Mini_${testName}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
    final file = File('${output.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }
}
