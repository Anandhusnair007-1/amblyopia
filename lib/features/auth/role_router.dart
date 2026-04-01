import 'package:flutter/material.dart';
import 'providers/auth_provider.dart';
import '../patient_portal/screens/patient_home_screen.dart';
import '../doctor_portal/screens/doctor_dashboard_screen.dart';
import '../health_worker/screens/worker_home_screen.dart';
import 'screens/patient_login_screen.dart';

class RoleRouter {
  static Widget resolve(UserRole role) {
    switch (role) {
      case UserRole.patient:
        return const PatientHomeScreen();
      case UserRole.doctor:
        return const DoctorDashboardScreen();
      case UserRole.worker:
        return const WorkerHomeScreen();
      case UserRole.none:
        return const PatientLoginScreen();
    }
  }
}
