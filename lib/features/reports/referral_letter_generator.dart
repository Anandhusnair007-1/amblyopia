import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'models/urgent_finding.dart';

class AravindCenter {
  const AravindCenter({
    required this.name,
    required this.city,
    required this.phone,
    required this.address,
  });

  final String name;
  final String city;
  final String phone;
  final String address;
}

class ReferralLetterGenerator {
  static const List<AravindCenter> centers = <AravindCenter>[
    AravindCenter(
      name: 'Aravind Eye Hospital',
      city: 'Coimbatore',
      phone: '0422-4360000',
      address: 'Avinashi Road, Civil Aerodrome Post, Coimbatore 641014',
    ),
    AravindCenter(
      name: 'Aravind Eye Hospital',
      city: 'Madurai',
      phone: '0452-4356100',
      address: '1, Anna Nagar, Madurai 625020',
    ),
    AravindCenter(
      name: 'Aravind Eye Hospital',
      city: 'Chennai',
      phone: '044-45928100',
      address: '15, Venkatnarayana Road, T.Nagar, Chennai 600017',
    ),
    AravindCenter(
      name: 'Aravind Eye Hospital',
      city: 'Tirunelveli',
      phone: '0462-2578800',
      address: 'Tirunelveli 627001',
    ),
    AravindCenter(
      name: 'Aravind Eye Hospital',
      city: 'Pondicherry',
      phone: '0413-2622022',
      address: 'Pondicherry 605001',
    ),
  ];

  static Future<String> generateReferralLetter({
    required String patientName,
    required int patientAge,
    required String sessionId,
    required List<UrgentFinding> findings,
    required String riskLevel,
    required String screenedBy,
    required String centerName,
    required AravindCenter referTo,
  }) async {
    final pdf = pw.Document(compress: true);
    final boldFont = await PdfGoogleFonts.poppinsBold();
    final regularFont = await PdfGoogleFonts.poppinsRegular();

    final today = DateFormat('dd MMMM yyyy').format(DateTime.now());
    final reportId = sessionId.length >= 8 ? sessionId.substring(0, 8).toUpperCase() : sessionId.toUpperCase();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Row(
              children: <pw.Widget>[
                pw.Text(
                  'AmbyoAI',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 20,
                    color: PdfColor.fromHex('#1565C0'),
                  ),
                ),
                pw.Spacer(),
                pw.Text(
                  'REFERRAL LETTER',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 14,
                    color: PdfColor.fromHex('#C62828'),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Divider(color: PdfColor.fromHex('#E3EAF2')),
            pw.SizedBox(height: 16),
            pw.Text(
              'Date: $today',
              style: pw.TextStyle(font: regularFont, fontSize: 12),
            ),
            pw.Text(
              'Ref: AmbyoAI-$reportId',
              style: pw.TextStyle(font: regularFont, fontSize: 12),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'To,',
              style: pw.TextStyle(font: regularFont, fontSize: 12),
            ),
            pw.Text(
              'The Ophthalmologist',
              style: pw.TextStyle(font: boldFont, fontSize: 12),
            ),
            pw.Text(
              '${referTo.name}, ${referTo.city}',
              style: pw.TextStyle(font: regularFont, fontSize: 12),
            ),
            pw.Text(
              referTo.address,
              style: pw.TextStyle(font: regularFont, fontSize: 11, color: PdfColors.grey),
            ),
            pw.Text(
              'Phone: ${referTo.phone}',
              style: pw.TextStyle(font: regularFont, fontSize: 11),
            ),
            pw.SizedBox(height: 24),
            pw.Container(
              color: PdfColor.fromHex('#FFF8F8'),
              padding: const pw.EdgeInsets.all(12),
              child: pw.Text(
                'Subject: Urgent Referral for Paediatric Eye Examination',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 13,
                  color: PdfColor.fromHex('#C62828'),
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Dear Doctor,',
              style: pw.TextStyle(font: regularFont, fontSize: 12),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'This letter is to refer $patientName, $patientAge years of age, for urgent paediatric ophthalmological evaluation.',
              style: pw.TextStyle(font: regularFont, fontSize: 12),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Clinical Findings (AmbyoAI Screening):',
              style: pw.TextStyle(font: boldFont, fontSize: 12),
            ),
            pw.SizedBox(height: 8),
            ...findings.map(
              (f) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(
                  children: <pw.Widget>[
                    pw.Text(
                      '• ',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 12,
                        color: PdfColor.fromHex('#C62828'),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        '${f.findingName}: ${f.measuredValue} (Normal: ${f.normalRange})',
                        style: pw.TextStyle(font: regularFont, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'AI Risk Assessment: $riskLevel',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 12,
                color: PdfColor.fromHex('#C62828'),
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Early intervention is crucial for optimal visual outcomes in paediatric amblyopia. Immediate evaluation and treatment is recommended.',
              style: pw.TextStyle(font: regularFont, fontSize: 12),
            ),
            pw.SizedBox(height: 24),
            pw.Text(
              'Screened by: $screenedBy',
              style: pw.TextStyle(font: regularFont, fontSize: 12),
            ),
            pw.Text(
              'Center: $centerName',
              style: pw.TextStyle(font: regularFont, fontSize: 12),
            ),
            pw.Text(
              'Screening Date: $today',
              style: pw.TextStyle(font: regularFont, fontSize: 12),
            ),
            pw.Text(
              'AmbyoAI Report ID: AmbyoAI-$reportId',
              style: pw.TextStyle(font: regularFont, fontSize: 11, color: PdfColors.grey),
            ),
            pw.SizedBox(height: 40),
            pw.Container(
              color: PdfColor.fromHex('#F5F7FA'),
              padding: const pw.EdgeInsets.all(10),
              child: pw.Text(
                'DISCLAIMER: This referral is based on AmbyoAI automated screening. AmbyoAI is a screening aid and not a substitute for clinical examination by a qualified ophthalmologist. Developed by Amrita School of Computing in collaboration with Aravind Eye Hospital.',
                style: pw.TextStyle(font: regularFont, fontSize: 9, color: PdfColors.grey),
              ),
            ),
          ],
        ),
      ),
    );

    final output = await getApplicationDocumentsDirectory();
    final fileName =
        'AmbyoAI_Referral_${patientName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    final file = File('${output.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }
}
