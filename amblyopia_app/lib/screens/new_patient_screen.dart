import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/screening_provider.dart';
import '../providers/auth_provider.dart';
import 'screening/screening_flow_screen.dart';

class NewPatientScreen extends StatefulWidget {
  const NewPatientScreen({super.key});

  @override
  State<NewPatientScreen> createState() => _NewPatientScreenState();
}

class _NewPatientScreenState extends State<NewPatientScreen> {
  String _selectedAgeGroup = 'child';
  final _villageController = TextEditingController(text: "00000000-0000-0000-0000-000000000001");
  bool _isLoading = false;

  void _startScreening() async {
    setState(() => _isLoading = true);
    final screeningProvider = Provider.of<ScreeningProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    bool patientCreated = await screeningProvider.createPatient(_selectedAgeGroup, _villageController.text);
    if (patientCreated) {
      bool sessionStarted = await screeningProvider.startSession(
        authProvider.nurseProfile?['id'] ?? "OFFLINE_NURSE",
        _villageController.text,
        11.0168,
        76.9558,
      );
      
      if (sessionStarted) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ScreeningFlowScreen()),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Patient')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Patient Demographic', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            const Text('Age Group'),
            DropdownButton<String>(
              value: _selectedAgeGroup,
              isExpanded: true,
              items: ['infant', 'child', 'adult', 'elderly'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedAgeGroup = val!),
            ),
            const SizedBox(height: 20),
            const Text('Village ID'),
            TextField(controller: _villageController, decoration: const InputDecoration(hintText: 'Enter Village UUID')),
            const Spacer(),
            ElevatedButton(
              onPressed: _isLoading ? null : _startScreening,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('CONTINUE TO SCREENING', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
