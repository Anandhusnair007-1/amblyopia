import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf_render_maintained/pdf_render.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/ambyo_theme.dart';
import '../../../core/theme/ambyoai_design_system.dart';
import '../../../core/widgets/enterprise_ui.dart';
import '../report_model.dart';

class ReportPreviewScreen extends StatefulWidget {
  const ReportPreviewScreen({
    super.key,
    this.pdfPath,
    this.reportData,
  });

  final String? pdfPath;
  final ReportData? reportData;

  @override
  State<ReportPreviewScreen> createState() => _ReportPreviewScreenState();
}

class _ReportPreviewScreenState extends State<ReportPreviewScreen> {
  Future<Uint8List>? _pdfBytesFuture;
  int _pageCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.pdfPath != null) {
      _pdfBytesFuture = File(widget.pdfPath!).readAsBytes();
      _loadPageCount();
    }
  }

  Future<void> _loadPageCount() async {
    final path = widget.pdfPath;
    if (path == null) return;
    try {
      final doc = await PdfDocument.openFile(path);
      if (mounted) {
        setState(() => _pageCount = doc.pageCount);
      }
      doc.dispose();
    } catch (_) {
      // ignore
    }
  }

  Future<void> _share() async {
    final path = widget.pdfPath;
    final data = widget.reportData;
    if (path == null || !await File(path).exists()) return;
    final name = data?.patientName ?? 'Patient';
    final date = data?.reportDate != null
        ? _formatDate(data!.reportDate)
        : DateTime.now().toString().split(' ').first;
    await Share.shareXFiles(
      [XFile(path)],
      text: 'AmbyoAI screening report for $name — $date',
    );
  }

  Future<void> _print() async {
    final bytes = _pdfBytesFuture != null ? await _pdfBytesFuture! : null;
    if (bytes == null) return;
    await Printing.layoutPdf(
      onLayout: (_) => Future.value(bytes),
      name: 'AmbyoAI_Report.pdf',
    );
  }

  static String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.pdfPath;
    final data = widget.reportData;

    return Scaffold(
      backgroundColor: AmbyoColors.darkBg,
      appBar: AppBar(
        title: const Text('Clinical Report'),
        backgroundColor: AmbyoColors.darkCard,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: EnterpriseGradientBackground(
        child: SafeArea(
          child: path == null
              ? const _EmptyPreviewState()
              : FutureBuilder<List<int>>(
                  future: _pdfBytesFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const _PdfSkeletonLoading();
                    }
                    final bytes = snapshot.data! as Uint8List;
                    return Column(
                      children: [
                        if (data != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                            child: EnterprisePanel(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _MetaBlock(
                                      label: 'Patient',
                                      value: data.patientName,
                                    ),
                                  ),
                                  Expanded(
                                    child: _MetaBlock(
                                      label: 'Risk',
                                      value: data.aiPrediction?.riskLevel ??
                                          'PENDING',
                                    ),
                                  ),
                                  Expanded(
                                    child: _MetaBlock(
                                      label: 'Report ID',
                                      value: data.reportId,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        _PdfActionBar(
                          onShare: _share,
                          onPrint: _print,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: ColoredBox(
                                color: AmbyoColors.cardLight,
                                child: PdfPreview(
                                  build: (_) => Future.value(bytes),
                                  allowSharing: false,
                                  allowPrinting: false,
                                  pdfFileName: 'AmbyoAI_Report.pdf',
                                  canChangePageFormat: false,
                                  canChangeOrientation: false,
                                  canDebug: false,
                                  useActions: false,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          child: Text(
                            _pageCount > 0
                                ? 'Page 1 of $_pageCount'
                                : 'PDF preview',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _PdfActionBar extends StatelessWidget {
  const _PdfActionBar({
    required this.onShare,
    required this.onPrint,
  });

  final VoidCallback onShare;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: onShare,
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Download',
          ),
          IconButton(
            onPressed: onShare,
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
          ),
          IconButton(
            onPressed: onPrint,
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print',
          ),
        ],
      ),
    );
  }
}

class _PdfSkeletonLoading extends StatelessWidget {
  const _PdfSkeletonLoading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Shimmer.fromColors(
        baseColor: const Color(0xFF18263A),
        highlightColor: const Color(0xFF223A5E),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFF18263A),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF18263A),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  children: List.generate(
                    8,
                    (_) => Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      child: Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF223A5E),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 120,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF223A5E),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaBlock extends StatelessWidget {
  const _MetaBlock({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white60,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _EmptyPreviewState extends StatelessWidget {
  const _EmptyPreviewState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: EnterprisePanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.picture_as_pdf_outlined,
                size: 52,
                color: AmbyoTheme.primaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                'No Generated Report Yet',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                'Complete the screening flow to generate a clinical PDF report for preview, sharing, and printing.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
