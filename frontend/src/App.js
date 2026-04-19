import "@/index.css";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
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
import ProtectedRoute from "@/core/auth/ProtectedRoute";
import { useEffect } from "react";
import { useAuthStore } from "@/core/auth/AuthStore";

function App() {
  const hydrate = useAuthStore((s) => s.hydrate);
  useEffect(() => { hydrate(); }, [hydrate]);

  return (
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
          <Route path="/patient/session/:sessionId/results" element={<PatientResults />} />
        </Route>

        <Route element={<ProtectedRoute allow={["doctor"]} />}>
          <Route path="/doctor" element={<DoctorDashboard />} />
          <Route path="/doctor/patient/:patientId" element={<DoctorPatientDetail />} />
          <Route path="/doctor/session/:sessionId" element={<DoctorReport />} />
        </Route>

        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
