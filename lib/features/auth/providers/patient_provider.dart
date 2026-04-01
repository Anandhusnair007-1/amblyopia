import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../offline/database_tables.dart';
import '../../offline/local_database.dart';

final patientProvider = ChangeNotifierProvider<PatientProvider>((ref) => PatientProvider());

class PatientProvider extends ChangeNotifier {
  Patient? _currentPatient;

  Patient? get current => _currentPatient;

  Future<void> loadPatient(String phone) async {
    _currentPatient = await LocalDatabase.instance.getPatientByPhone(phone);
    notifyListeners();
  }

  Future<void> createPatient(String phone) async {
    final patient = Patient(
      id: const Uuid().v4(),
      name: 'Patient',
      age: 0,
      gender: 'Unknown',
      phone: phone,
      createdAt: DateTime.now().toUtc(),
    );
    await LocalDatabase.instance.savePatient(patient);
    _currentPatient = patient;
    notifyListeners();
  }

  Future<void> updatePatient(Patient updated) async {
    await LocalDatabase.instance.updatePatient(updated);
    _currentPatient = updated;
    notifyListeners();
  }

  void clear() {
    _currentPatient = null;
    notifyListeners();
  }
}

