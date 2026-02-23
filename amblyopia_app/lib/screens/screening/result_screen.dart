import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/screening_provider.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _isFinalizing = false;

  @override
  void initState() {
    super.initState();
    _finalize();
  }

  Future<void> _finalize() async {
    setState(() => _isFinalizing = true);
    final provider = Provider.of<ScreeningProvider>(context, listen: false);
    await provider.completeSession();
    if (mounted) setState(() => _isFinalizing = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ScreeningProvider>(context);
    final diag = provider.finalDiagnosis;

    return Scaffold(
      appBar: AppBar(title: const Text('Screening Result'), automaticallyImplyLeading: false),
      body: _isFinalizing 
        ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Generating Final Report...')]))
        : Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.check_circle, size: 80, color: Colors.green),
                const SizedBox(height: 24),
                const Text('SCREENING COMPLETE', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 40),
                if (diag != null) ...[
                  _buildResultRow('Risk Level', diag['risk_level'] ?? 'N/A'),
                  _buildResultRow('Severity', 'Grade ${diag['severity_grade'] ?? 0}'),
                  const SizedBox(height: 20),
                  const Text('Recommendation:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(diag['recommendation'] ?? 'Wait for doctor review.'),
                ],
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    provider.reset();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('BACK TO DASHBOARD'),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
