import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../offline/local_database.dart';
import 'report_model.dart';

class PDFGenerator {
  static Future<String> generateReport(ReportData data) async {
    final pdf = pw.Document(compress: true);
    final regularFont = await PdfGoogleFonts.poppinsRegular();
    final boldFont = await PdfGoogleFonts.poppinsBold();
    final primaryBlue = PdfColor.fromHex('#1A237E');
    final teal = PdfColor.fromHex('#00897B');
    final amber = PdfColor.fromHex('#FFB300');
    final danger = PdfColor.fromHex('#C62828');
    final success = PdfColor.fromHex('#2E7D32');
    final surfaceTint = PdfColor.fromHex('#F7F9FC');

    PdfColor riskColor(String level) {
      switch (level.toUpperCase()) {
        case 'URGENT':
        case 'HIGH':
          return danger;
        case 'MILD':
        case 'MEDIUM':
          return amber;
        default:
          return success;
      }
    }

    pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => _coverPage(data, boldFont, regularFont, primaryBlue)));
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) =>
            _summaryPage(data, boldFont, regularFont, riskColor, surfaceTint),
      ),
    );
    pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => _gazePage(data, boldFont, regularFont)));
    pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => _hirschbergPrismPage(data, boldFont, regularFont)));
    pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => _additionalTestsPage(data, boldFont, regularFont, teal)));
    pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => _visualColorPage(data, boldFont, regularFont, amber)));
    pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => _aiPage(data, boldFont, regularFont, primaryBlue)));
    pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => _doctorPage(data, boldFont, regularFont)));

    final bytes = await pdf.save();
    final sizeKb = bytes.length ~/ 1024;
    debugPrint('PDF size: $sizeKb KB');
    if (bytes.length > 5 * 1024 * 1024) {
      debugPrint('Warning: PDF is large, consider reducing content');
    }

    final output = await getApplicationDocumentsDirectory();
    final fileName =
        'AmbyoAI_Report_${data.patientId}_${DateFormat('yyyyMMdd_HHmm').format(data.reportDate)}.pdf';
    final file = File('${output.path}/$fileName');
    await file.writeAsBytes(bytes);
    await LocalDatabase.instance.saveReportPath(data.sessionId, file.path);
    return file.path;
  }

  static pw.Widget _coverPage(
    ReportData data,
    pw.Font boldFont,
    pw.Font regularFont,
    PdfColor primaryBlue,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(24),
          color: primaryBlue,
          child: pw.Column(
            children: [
              pw.Container(
                width: 56,
                height: 56,
                decoration: const pw.BoxDecoration(
                    color: PdfColors.white, shape: pw.BoxShape.circle),
              ),
              pw.SizedBox(height: 12),
              pw.Text('AmbyoAI - Smart Vision Screening',
                  style: pw.TextStyle(
                      font: boldFont, fontSize: 24, color: PdfColors.white)),
              pw.Text('Clinical Screening Report',
                  style: pw.TextStyle(
                      font: regularFont, fontSize: 14, color: PdfColors.white)),
            ],
          ),
        ),
        pw.SizedBox(height: 24),
        _sectionTitle('Patient Details', boldFont),
        _keyValueTable({
          'Name': data.patientName,
          'Age': data.patientAge.toString(),
          'Gender': data.patientGender,
          'Patient ID': data.patientId,
        }, regularFont),
        pw.SizedBox(height: 18),
        _sectionTitle('Screening Details', boldFont),
        _keyValueTable({
          'Date': DateFormat('dd MMM yyyy').format(data.reportDate),
          'Time': DateFormat('hh:mm a').format(data.reportDate),
          'Screened by': data.screenedBy,
          'Location': 'Device-based screening',
          'Device': 'AmbyoAI Mobile',
          'Report ID': data.reportId,
        }, regularFont),
        if (data.consentObtainedDate != null ||
            data.consentGuardianName != null ||
            (data.signatureImageBytes != null &&
                data.signatureImageBytes!.isNotEmpty)) ...[
          pw.SizedBox(height: 18),
          _sectionTitle('Consent (clinical audit)', boldFont),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (data.consentObtainedDate != null)
                      pw.Text(
                        'Consent obtained: ${DateFormat('dd MMM yyyy').format(data.consentObtainedDate!)}',
                        style: pw.TextStyle(font: regularFont, fontSize: 10),
                      ),
                    if (data.consentGuardianName != null &&
                        data.consentGuardianName!.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 4),
                        child: pw.Text(
                          'Guardian: ${data.consentGuardianName}',
                          style: pw.TextStyle(font: regularFont, fontSize: 10),
                        ),
                      ),
                  ],
                ),
              ),
              if (data.signatureImageBytes != null &&
                  data.signatureImageBytes!.isNotEmpty)
                pw.Container(
                  width: 100,
                  height: 40,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                  ),
                  child: pw.Image(
                    pw.MemoryImage(
                        Uint8List.fromList(data.signatureImageBytes!)),
                    width: 100,
                    height: 40,
                  ),
                ),
            ],
          ),
        ],
        pw.Spacer(),
        pw.Divider(),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Amrita School of Computing',
                style: pw.TextStyle(font: regularFont, fontSize: 12)),
            pw.Text('Aravind Eye Hospital',
                style: pw.TextStyle(font: regularFont, fontSize: 12)),
            pw.Text('Powered by AmbyoAI v1.0',
                style: pw.TextStyle(font: regularFont, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _summaryPage(
    ReportData data,
    pw.Font boldFont,
    pw.Font regularFont,
    PdfColor Function(String) riskColor,
    PdfColor surfaceTint,
  ) {
    final prediction = data.aiPrediction;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _pageHeader('Executive Summary', boldFont),
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.all(18),
          decoration: pw.BoxDecoration(
            color: riskColor(prediction?.riskLevel ?? 'NORMAL'),
            borderRadius: pw.BorderRadius.circular(16),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(prediction?.riskLevel ?? 'NORMAL',
                  style: pw.TextStyle(
                      font: boldFont, fontSize: 24, color: PdfColors.white)),
              pw.Text(
                  'AI Risk Score: ${(prediction?.riskScore ?? 0).toStringAsFixed(2)}',
                  style:
                      pw.TextStyle(font: regularFont, color: PdfColors.white)),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: ['Test Name', 'Result', 'Status'],
          cellStyle: pw.TextStyle(font: regularFont, fontSize: 10),
          headerStyle: pw.TextStyle(font: boldFont, fontSize: 10),
          data: [
            [
              'Gaze Detection',
              '${data.gazeResult?.prismDiopterValue.toStringAsFixed(1) ?? '-'}Δ',
              data.gazeResult == null
                  ? '-'
                  : (data.gazeResult!.requiresUrgentReferral
                      ? 'Urgent'
                      : 'Reviewed')
            ],
            [
              'Hirschberg',
              '${data.hirschbergResult?.leftDisplacementMM.toStringAsFixed(1) ?? '-'}mm',
              data.hirschbergResult?.severity ?? '-'
            ],
            [
              'Prism Diopter',
              '${data.prismResult?.totalDeviation.toStringAsFixed(1) ?? '-'}Δ',
              data.prismResult?.severity ?? '-'
            ],
            [
              'Red Reflex',
              '${data.redReflexScore ?? '-'}',
              _statusFromScore(data.redReflexScore, invert: true)
            ],
            [
              'Suppression',
              '${data.suppressionScore ?? '-'}',
              _statusFromScore(data.suppressionScore)
            ],
            [
              'Depth Perception',
              '${data.depthScore ?? '-'}',
              _statusFromScore(data.depthScore, invert: true)
            ],
            [
              'Worth 4 Dot',
              '${data.worthFourDotScore ?? '-'}',
              data.worthFourDotResult?.fusionStatus ?? '-'
            ],
            [
              'Color Vision',
              '${data.colorVisionScore ?? '-'}',
              _statusFromScore(data.colorVisionScore, invert: true)
            ],
            [
              'Visual Acuity',
              '${data.visualAcuityScore ?? '-'}',
              _statusFromScore(data.visualAcuityScore)
            ],
          ],
        ),
        if (data.qualityByTest != null && data.qualityByTest!.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text('Test quality',
              style: pw.TextStyle(font: boldFont, fontSize: 11)),
          pw.SizedBox(height: 6),
          ...data.qualityByTest!.entries.map(
            (e) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(
                '${e.key}: ${e.value}',
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: 10,
                  color: e.value.startsWith('Poor')
                      ? PdfColor.fromHex('#C62828')
                      : PdfColors.grey800,
                ),
              ),
            ),
          ),
        ],
        pw.SizedBox(height: 18),
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: surfaceTint,
            border: pw.Border.all(
                color: riskColor(prediction?.riskLevel ?? 'NORMAL')),
            borderRadius: pw.BorderRadius.circular(14),
          ),
          child: pw.Text(
            prediction?.recommendation ??
                'Routine clinical follow-up recommended.',
            style: pw.TextStyle(font: regularFont, fontSize: 12),
          ),
        ),
      ],
    );
  }

  static pw.Widget _gazePage(
      ReportData data, pw.Font boldFont, pw.Font regularFont) {
    final gaze = data.gazeResult;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _pageHeader('Gaze Detection Results', boldFont),
        pw.SizedBox(height: 14),
        if (gaze == null)
          pw.Text('No gaze data available.',
              style: pw.TextStyle(font: regularFont))
        else ...[
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: gaze.directions
                .map(
                  (direction) => pw.Container(
                    width: 150,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(10),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(direction.direction,
                            style: pw.TextStyle(font: boldFont, fontSize: 11)),
                        pw.Text(
                            '${direction.prismDiopters.toStringAsFixed(1)}Δ',
                            style:
                                pw.TextStyle(font: regularFont, fontSize: 10)),
                        pw.Text(
                            '${direction.deviationAngleDegrees.toStringAsFixed(1)}°',
                            style:
                                pw.TextStyle(font: regularFont, fontSize: 10)),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Key findings',
              style: pw.TextStyle(font: boldFont, fontSize: 14)),
          pw.Bullet(
              text: 'Max deviation: ${gaze.maxDeviation.toStringAsFixed(1)}°'),
          pw.Bullet(text: 'Strabismus type: ${gaze.strabismusType}'),
          pw.Bullet(
              text:
                  'Prism diopter value: ${gaze.prismDiopterValue.toStringAsFixed(1)}Δ'),
          pw.SizedBox(height: 16),
          pw.Text('Clinical notes',
              style: pw.TextStyle(font: boldFont, fontSize: 14)),
          pw.Container(
            height: 120,
            decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300)),
          ),
        ],
      ],
    );
  }

  static pw.Widget _hirschbergPrismPage(
      ReportData data, pw.Font boldFont, pw.Font regularFont) {
    final hirschberg = data.hirschbergResult;
    final prism = data.prismResult;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _pageHeader('Hirschberg + Prism Results', boldFont),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: ['Measurement', 'Left Eye', 'Right Eye'],
          headerStyle: pw.TextStyle(font: boldFont, fontSize: 10),
          cellStyle: pw.TextStyle(font: regularFont, fontSize: 10),
          data: [
            [
              'Displacement',
              '${hirschberg?.leftDisplacementMM.toStringAsFixed(1) ?? '-'}mm',
              '${hirschberg?.rightDisplacementMM.toStringAsFixed(1) ?? '-'}mm'
            ],
            [
              'Deviation',
              '${hirschberg?.leftDeviationDegrees.toStringAsFixed(1) ?? '-'}°',
              '${hirschberg?.rightDeviationDegrees.toStringAsFixed(1) ?? '-'}°'
            ],
            [
              'Prism',
              '${hirschberg?.leftPrismDiopters.toStringAsFixed(1) ?? '-'}Δ',
              '${hirschberg?.rightPrismDiopters.toStringAsFixed(1) ?? '-'}Δ'
            ],
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Text(
            'Strabismus classification: ${hirschberg?.strabismusType ?? '-'}',
            style: pw.TextStyle(font: boldFont, fontSize: 12)),
        pw.Text('Severity: ${hirschberg?.severity ?? '-'}',
            style: pw.TextStyle(font: regularFont)),
        pw.SizedBox(height: 16),
        pw.Text('Prism correction estimate',
            style: pw.TextStyle(font: boldFont, fontSize: 14)),
        pw.Bullet(
            text:
                'Distance prism: ${prism?.distancePrism.toStringAsFixed(1) ?? '-'}Δ'),
        pw.Bullet(
            text: 'Near prism: ${prism?.nearPrism.toStringAsFixed(1) ?? '-'}Δ'),
        pw.Bullet(text: 'Base direction: ${prism?.baseDirection ?? '-'}'),
      ],
    );
  }

  static pw.Widget _additionalTestsPage(
      ReportData data, pw.Font boldFont, pw.Font regularFont, PdfColor teal) {
    final redReflex = data.redReflexResult;
    final suppression = data.suppressionResult;
    final depth = data.depthResult;
    final worthFourDot = data.worthFourDotResult;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _pageHeader('Additional Test Results', boldFont),
        pw.SizedBox(height: 16),
        _resultBlock(
          'Red Reflex findings',
          redReflex == null
              ? '${data.redReflexScore ?? '-'}'
              : '${redReflex.leftReflexType}/${redReflex.rightReflexType}',
          regularFont,
          teal,
        ),
        pw.SizedBox(height: 10),
        _resultBlock(
          'Suppression test result',
          suppression == null
              ? '${data.suppressionScore ?? '-'}'
              : '${suppression.result} (${(suppression.suppressionScore * 100).toStringAsFixed(0)}%)',
          regularFont,
          teal,
        ),
        pw.SizedBox(height: 10),
        _resultBlock(
          'Depth perception score',
          depth == null
              ? '${data.depthScore ?? '-'}'
              : '${depth.correctAnswers}/${depth.totalTrials} • ${depth.stereoGrade}',
          regularFont,
          teal,
        ),
        pw.SizedBox(height: 10),
        _resultBlock(
          'Worth 4 Dot fusion',
          worthFourDot == null
              ? '${data.worthFourDotScore ?? '-'}'
              : '${worthFourDot.fusionStatus} (${worthFourDot.correctAnswers}/${worthFourDot.totalTrials})',
          regularFont,
          teal,
        ),
        if (redReflex != null) ...[
          pw.SizedBox(height: 14),
          pw.Text('Red reflex note: ${redReflex.clinicalNote}',
              style: pw.TextStyle(font: regularFont, fontSize: 10)),
        ],
        if (suppression != null) ...[
          pw.SizedBox(height: 10),
          pw.Text('Suppression note: ${suppression.clinicalNote}',
              style: pw.TextStyle(font: regularFont, fontSize: 10)),
        ],
        if (depth != null) ...[
          pw.SizedBox(height: 10),
          pw.Text('Depth note: ${depth.clinicalNote}',
              style: pw.TextStyle(font: regularFont, fontSize: 10)),
        ],
        if (worthFourDot != null) ...[
          pw.SizedBox(height: 10),
          pw.Text('Worth 4 Dot note: ${worthFourDot.clinicalNote}',
              style: pw.TextStyle(font: regularFont, fontSize: 10)),
        ],
      ],
    );
  }

  static pw.Widget _visualColorPage(
      ReportData data, pw.Font boldFont, pw.Font regularFont, PdfColor amber) {
    final titmus = data.titmusResult;
    final lang = data.langResult;
    final ishihara = data.ishiharaResult;
    final snellen = data.snellenResult;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _pageHeader('Visual + Stereo + Color', boldFont),
        pw.SizedBox(height: 16),
        _resultBlock(
          'Snellen visual acuity',
          snellen == null
              ? '${data.visualAcuityScore ?? '-'}'
              : '${snellen.visualAcuity} (score ${(snellen.acuityScore).toStringAsFixed(2)})',
          regularFont,
          amber,
        ),
        pw.SizedBox(height: 10),
        _resultBlock(
          'Ishihara color vision',
          ishihara == null
              ? '${data.colorVisionScore ?? '-'}'
              : '${ishihara.colorVisionStatus} (${ishihara.correctAnswers}/${ishihara.totalTestPlates})',
          regularFont,
          amber,
        ),
        pw.SizedBox(height: 10),
        _resultBlock(
          'Titmus stereo acuity',
          titmus == null
              ? '-'
              : '${titmus.stereoAcuityArcSeconds.toStringAsFixed(0)}" • ${titmus.stereoGrade} (${titmus.circlesCorrect}/${titmus.circlesTotal} circles)',
          regularFont,
          amber,
        ),
        pw.SizedBox(height: 10),
        _resultBlock(
          'Lang random-dot stereo',
          lang == null
              ? '-'
              : '${lang.stereopsisLevel} (${lang.patternsDetected}/3 patterns)',
          regularFont,
          amber,
        ),
        if (snellen != null) ...[
          pw.SizedBox(height: 12),
          pw.Text('Snellen note: ${snellen.clinicalNote}',
              style: pw.TextStyle(font: regularFont, fontSize: 10)),
        ],
        if (ishihara != null) ...[
          pw.SizedBox(height: 8),
          pw.Text('Ishihara note: ${ishihara.clinicalNote}',
              style: pw.TextStyle(font: regularFont, fontSize: 10)),
        ],
        if (titmus != null) ...[
          pw.SizedBox(height: 8),
          pw.Text('Titmus note: ${titmus.clinicalNote}',
              style: pw.TextStyle(font: regularFont, fontSize: 10)),
        ],
        if (lang != null) ...[
          pw.SizedBox(height: 8),
          pw.Text('Lang note: ${lang.clinicalNote}',
              style: pw.TextStyle(font: regularFont, fontSize: 10)),
        ],
      ],
    );
  }

  static pw.Widget _aiPage(ReportData data, pw.Font boldFont,
      pw.Font regularFont, PdfColor primaryBlue) {
    final prediction = data.aiPrediction;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _pageHeader('AI Analysis', boldFont),
        pw.SizedBox(height: 16),
        _keyValueTable({
          'Model version': data.modelVersion,
          'Risk level': prediction?.riskLevel ?? '-',
          'Risk score': prediction?.riskScore.toStringAsFixed(2) ?? '-',
          'Confidence vector': prediction?.rawOutput
                  .map((e) => e.toStringAsFixed(2))
                  .join(', ') ??
              '-',
        }, regularFont),
        pw.SizedBox(height: 16),
        pw.Text(
          'This is a screening tool. Clinical diagnosis required.',
          style: pw.TextStyle(font: boldFont, color: primaryBlue),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Grad-CAM note if available: not included in this mobile report build.',
          style: pw.TextStyle(font: regularFont),
        ),
      ],
    );
  }

  static pw.Widget _doctorPage(
      ReportData data, pw.Font boldFont, pw.Font regularFont) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _pageHeader('For Doctor Use Only', boldFont),
        pw.SizedBox(height: 16),
        ...[
          'Clinical Diagnosis',
          'Recommended Treatment',
          'Follow-up Date',
          'Referred to',
          'Doctor Signature',
          'Date',
        ].map((field) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 14),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(field,
                      style: pw.TextStyle(font: boldFont, fontSize: 12)),
                  pw.SizedBox(height: 6),
                  pw.Container(
                    height: 26,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide()),
                    ),
                  ),
                ],
              ),
            )),
        pw.SizedBox(height: 16),
        pw.Text(
          'AmbyoAI is a screening aid only. Not a substitute for clinical examination. Aravind Eye Hospital / Amrita School of Computing.',
          style: pw.TextStyle(font: regularFont, fontSize: 10),
        ),
      ],
    );
  }

  static pw.Widget _pageHeader(String title, pw.Font boldFont) {
    return pw.Text(title, style: pw.TextStyle(font: boldFont, fontSize: 20));
  }

  static pw.Widget _sectionTitle(String title, pw.Font boldFont) {
    return pw.Text(title, style: pw.TextStyle(font: boldFont, fontSize: 14));
  }

  static pw.Widget _keyValueTable(
      Map<String, String> data, pw.Font regularFont) {
    return pw.Column(
      children: data.entries
          .map(
            (entry) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                      width: 120,
                      child: pw.Text(entry.key,
                          style: pw.TextStyle(font: regularFont))),
                  pw.Expanded(
                      child: pw.Text(entry.value,
                          style: pw.TextStyle(font: regularFont))),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  static pw.Widget _resultBlock(
      String title, String value, pw.Font regularFont, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: color),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(title, style: pw.TextStyle(font: regularFont)),
          pw.Text(value, style: pw.TextStyle(font: regularFont, color: color)),
        ],
      ),
    );
  }

  static String _statusFromScore(double? score, {bool invert = false}) {
    if (score == null) {
      return '-';
    }
    final abnormal = invert ? score < 0.5 : score > 0.5;
    return abnormal ? 'Alert' : 'Normal';
  }
}
