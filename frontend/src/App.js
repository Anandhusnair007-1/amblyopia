import "@/index.css";
import { BrowserRouter, Routes, Route, Navigate, Outlet } from "react-router-dom";
import { Toaster } from "sonner";
import Landing from "@/portals/Landing";
import PatientLogin from "@/portals/auth/PatientLogin";
import DoctorLogin from "@/portals/auth/DoctorLogin";
import PatientRegister from "@/portals/patient/PatientRegister";
import PatientHome from "@/portals/patient/PatientHome";
import ConsentScreen from "@/portals/patient/ConsentScreen";
import QuickTest from "@/portals/patient/QuickTest";
import TestRunner from "@/tests/TestRunner";
import PatientResults from "@/portals/patient/PatientResults";
import DoctorDashboard from "@/portals/doctor/DoctorDashboard";
import DoctorPatientDetail from "@/portals/doctor/DoctorPatientDetail";
import DoctorReport from "@/portals/doctor/DoctorReport";
import DoctorAuditLogs from "@/portals/doctor/DoctorAuditLogs";
import StaffShell from "@/components/shell/StaffShell";
import AdminHome from "@/portals/admin/AdminHome";
import AdminCamps from "@/portals/admin/AdminCamps";
import AdminStaff from "@/portals/admin/AdminStaff";
import AdminReferrals from "@/portals/admin/AdminReferrals";
import AdminFollowups from "@/portals/admin/AdminFollowups";
import ProtectedRoute from "@/core/auth/ProtectedRoute";
import AccessDenied from "@/portals/staff/AccessDenied";
import { useEffect } from "react";
import { useAuthStore } from "@/core/auth/AuthStore";
import { useOfflineSync } from "@/core/offline/useOfflineSync";
import { ThemeProvider } from "next-themes";

/** Anyone who may enter the staff shell (clinical and/or operations). */
const STAFF_GATE = ["doctor", "optometrist", "field_worker", "super_admin", "hospital_admin", "admin"];
const CLINICAL_GATE = ["doctor", "optometrist", "field_worker"];
const ADMIN_SECTION_GATE = ["super_admin", "hospital_admin", "admin", "doctor", "optometrist"];
const ALL_AUTH_ROLES = [
  "patient",
  "patient_pending",
  "doctor",
  "optometrist",
  "field_worker",
  "admin",
  "hospital_admin",
  "super_admin",
];

function App() {
  const hydrate = useAuthStore((s) => s.hydrate);
  useOfflineSync();
  useEffect(() => {
    hydrate();
  }, [hydrate]);

  return (
    <ThemeProvider attribute="class" defaultTheme="light">
      <BrowserRouter>
        <Toaster position="top-right" richColors closeButton />
        <Routes>
          <Route path="/" element={<Landing />} />
          <Route path="/patient-login" element={<PatientLogin />} />
          <Route path="/doctor-login" element={<DoctorLogin />} />

          <Route element={<ProtectedRoute allow={["patient", "patient_pending"]} />}>
            <Route path="/patient/register" element={<PatientRegister />} />
          </Route>

          <Route element={<ProtectedRoute allow={["patient"]} />}>
            <Route path="/patient" element={<PatientHome />} />
            <Route path="/patient/consent" element={<ConsentScreen />} />
            <Route path="/patient/quick/:testId" element={<QuickTest />} />
            <Route path="/patient/session/:sessionId/test/:testIndex" element={<TestRunner />} />
            <Route path="/patient/session/:sessionId/test/heidelberg" element={<TestRunner />} />
            <Route path="/patient/session/:sessionId/results" element={<PatientResults />} />
          </Route>

          <Route element={<ProtectedRoute allow={ALL_AUTH_ROLES} />}>
            <Route path="/access-denied" element={<AccessDenied />} />
          </Route>

          <Route element={<ProtectedRoute allow={STAFF_GATE} />}>
            <Route element={<StaffShell />}>
              <Route element={<ProtectedRoute allow={CLINICAL_GATE} />}>
                <Route path="/doctor" element={<DoctorDashboard />} />
                <Route path="/doctor/audit" element={<DoctorAuditLogs />} />
                <Route path="/doctor/patient/:patientId" element={<DoctorPatientDetail />} />
                <Route path="/doctor/session/:sessionId" element={<DoctorReport />} />
              </Route>
              <Route element={<ProtectedRoute allow={ADMIN_SECTION_GATE} />}>
                <Route path="/admin" element={<Outlet />}>
                  <Route index element={<AdminHome />} />
                  <Route path="camps" element={<AdminCamps />} />
                  <Route path="staff" element={<AdminStaff />} />
                  <Route path="referrals" element={<AdminReferrals />} />
                  <Route path="followups" element={<AdminFollowups />} />
                </Route>
              </Route>
            </Route>
          </Route>

          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </BrowserRouter>
    </ThemeProvider>
  );
}

export default App;
