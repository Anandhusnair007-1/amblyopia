# AmbyoAI — User Guide

For Aravind Eye Hospital clinical pilot. Export this document to PDF for handoff.

---

## For Patients

### How to log in

1. Open the AmbyoAI app.
2. Select **Patient** role on the login screen.
3. Enter a 10-digit phone number.
4. On the OTP screen, enter the code you receive (for demo, OTP is **1234**).
5. Tap to continue. You will see the patient home screen.

### How to start screening

1. From patient home, tap **Start Full Screening**.
2. If this is your first time (or consent is older than 12 months), read the consent form, check all boxes, and sign in the signature pad.
3. Tap **I Consent** to proceed. The eye scan and test flow will start.
4. Follow on-screen instructions for each test (distance, gaze, Hirschberg, etc.).

### How to view reports

1. From patient home, open **My Reports** (or the reports / history section).
2. Select a past screening to view the full report.
3. Use **Share** or **Download** to save or send the PDF report.

---

## For Doctors

### How to log in

1. Open the AmbyoAI app.
2. Select **Doctor** role.
3. Use the default credentials (change these before pilot):
   - **Username:** doctor  
   - **Password:** AmbyoDoc#9274!  

### How to view patient reports

1. After login, open the **Patient list** or dashboard.
2. Tap a patient to see their screening history.
3. Tap **View** on a session to see all 10 test results and quality scores.
4. Review the PDF report and any urgent findings.

### How to add a diagnosis

1. Open a patient’s report/session.
2. Tap **Diagnose** (or **Add diagnosis**).
3. Enter your clinical notes and risk label.
4. Save. The diagnosis is stored on the backend and an audit entry is created.

### How to generate a referral letter

1. For an urgent case, open the **Urgent report** screen.
2. Tap **Generate Referral Letter**.
3. Choose the Aravind center (e.g. Coimbatore, Madurai).
4. The PDF referral letter is generated. Use **Share** to send it.

---

## For Workers (Field screeners)

### How to register children

1. Log in as **Worker** and go to the worker home screen.
2. Tap **Register New Child**.
3. Fill in name, age, phone, and other required fields.
4. If the phone is already registered, a dialog will show the existing patient; you can **Screen Existing Patient** or **Register Anyway**.

### How to use the screening queue

1. From worker home, open the **Screening queue**.
2. The queue shows registered children for the day. You can set age profile (A/B/standard) per child.
3. Tap **Start Screening** for a child. Consent will be requested if needed, then the test flow starts.

### How to do bulk screening

1. Register multiple children from the registration screen.
2. Use the queue to start screening one after another. Complete consent and tests for each child in turn.

### Distance calibration

1. From worker home, tap **Distance Calibration** (or **Calibration**).
2. Follow the A4 paper flow: hold an A4 sheet, position the phone at the required distance (e.g. 40 cm).
3. The app confirms when the distance is correct. Use this to train screeners and verify device placement.

---

## Backend and credentials

- **Backend URL:** Set in the app (Doctor portal) to your server URL after deployment. For real-device testing, use your machine’s LAN IP (e.g. `http://192.168.1.105:8000`).
- **Default doctor credentials:** doctor / AmbyoDoc#9274! — **must be changed before sending to Aravind.** Update in `backend/main.py` (or via environment) and document the new credentials for the hospital.

---

## Contacts and reference

- **AmbyoAI** — Smart Amblyopia Screening for Every Child  
- **Aravind Eye Hospital**, Coimbatore  
- **Amrita School of Computing**  
- Research / team: Aditya Anil Deyal, Anandhu S. Nair, Vasudev PC  

For handoff: Clinical Ophthalmology Team, Aravind Eye Hospital, Coimbatore.
