import 'package:flutter/material.dart';

class PatientListScreen extends StatelessWidget {
  const PatientListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patient List')),
      body: const Center(child: Text('Patient List screen placeholder')),
    );
  }
}
