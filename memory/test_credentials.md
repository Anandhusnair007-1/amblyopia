# AmbyoAI Test Credentials

## Patient Login (OTP)
- Type: Phone + OTP
- Demo OTP: `1234` (works for ANY 10-digit phone number)
- Endpoint:
  - `POST /api/auth/patient/request-otp` body `{"phone":"9876543210"}`
  - `POST /api/auth/patient/verify-otp` body `{"phone":"9876543210","otp":"1234"}`

## Doctor Login
- Email: `doctor@aravind.in`
- Password: `aravind2026`
- Endpoint: `POST /api/auth/doctor/login` body `{"email":"doctor@aravind.in","password":"aravind2026"}`

## Default Hospital (auto-seeded)
- Aravind Eye Hospital — Coimbatore, Tamil Nadu
