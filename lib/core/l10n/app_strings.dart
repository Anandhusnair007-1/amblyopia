class AppStrings {
  static const appName = 'AmbyoAI';
  static const tagline = 'Smart Vision Screening';

  static const welcomeTitle = 'Welcome to AmbyoAI';
  static const welcomeBody =
      'AI-powered eye screening for children. Detect amblyopia and vision problems early.';

  static const enterPhone = 'Enter your phone number';
  static const enterOtp = 'Enter OTP';
  static const demoOtpHint = 'Demo mode: OTP is 4826';
  static const invalidOtp = 'Incorrect OTP';
  static const loginSuccess = 'Login successful';

  static const startFullScreening = 'START FULL EYE SCREENING';
  static const allTestsDuration = 'All 10 tests · ~8 minutes';
  static const individualTests = 'Individual Tests';
  static const recentReports = 'Recent Reports';
  static const notScreenedYet = 'Not screened yet';

  static const riskNormal = 'NORMAL';
  static const riskMild = 'MILD RISK';
  static const riskHigh = 'HIGH RISK';
  static const riskUrgent = 'URGENT';

  static const testGaze = 'Gaze Detection';
  static const testHirschberg = 'Hirschberg';
  static const testPrism = 'Prism Diopter';
  static const testRedReflex = 'Red Reflex';
  static const testSuppression = 'Suppression';
  static const testDepth = 'Depth Perception';
  static const testTitmus = 'Titmus Stereo';
  static const testLang = 'Lang Stereo';
  static const testIshihara = 'Color Vision';
  static const testSnellen = 'Visual Acuity';

  static const eyeScan = 'Eye Scan';
  static const startEyeScan = 'Start Eye Scan';
  static const eyeLocked = 'Eye locked';
  static const scanning = 'Scanning...';

  static const viewPdf = 'View PDF';
  static const shareReport = 'Share Report';
  static const generateReport = 'Generate Report';
  static const reportSaved = 'Report saved to device';

  static const offlineBanner =
      'Offline — data saved locally. Will sync when connected.';
  static const backOnline = 'Connected — syncing now...';

  static const registerChild = 'Register New Child';
  static const screeningQueue = 'Screening Queue';
  static const childrenWaiting = 'children waiting';
  static const noChildrenInQueue = 'No children in queue. All screened today!';

  static const urgentCases = 'URGENT CASES NEED ATTENTION';
  static const addDiagnosis = 'Add Clinical Diagnosis';
  static const saveDiagnosis = 'Save Diagnosis';
  static const diagnosisSaved = 'Diagnosis saved successfully';

  static const cameraPermissionDenied =
      'Camera access required for eye tests. Please allow in Settings.';
  static const micPermissionDenied =
      'Microphone access required for voice tests. Please allow in Settings.';
  static const networkError =
      'Cannot connect to server. Check your connection.';
  static const retryButton = 'Retry';

  static const noTestsYet =
      'No tests recorded yet.\nStart a screening to begin.';
  static const noReportsYet =
      'No reports yet.\nComplete a screening to get your first report.';
  static const noPatientsYet = 'No patients found.';

  /// Get localized string by key and language code (en, ml, hi, ta). Falls back to en then key.
  static String get(String key, String language) {
    return _strings[language]?[key] ?? _strings['en']?[key] ?? key;
  }

  static const Map<String, Map<String, String>> _strings = {
    'en': {
      'eyescan_phase_init': 'Getting ready...',
      'eyescan_phase_detect': 'Finding your eyes...',
      'eyescan_phase_lock': 'Almost ready!',
      'eyescan_phase_ready': 'Let us begin!',
      'eyescan_distance': 'Position face in frame',
      'eyescan_locked': 'Eye locked',
      'gaze_instruction': 'Follow the dot with your eyes',
      'gaze_direction': 'Look at the dot...',
      'gaze_capturing': 'Capturing...',
      'hirschberg_instruction': 'Look directly at the camera',
      'hirschberg_flash': 'Flash will activate briefly',
      'hirschberg_analyzing': 'Analyzing corneal reflex...',
      'redreflex_instruction': 'Hold phone 30-40cm from face',
      'redreflex_flash': 'Keep eyes open. Flash activating...',
      'suppression_instruction': 'Look at the pattern for 30 seconds',
      'suppression_prompt': 'Say HORIZONTAL, VERTICAL, or SWITCHING',
      'suppression_reading': 'Reading {n} of {total}',
      'suppression_prompt_b': 'What color do you see? Say RED, BLUE, or BOTH',
      'depth_instruction': 'Look at the glowing dot',
      'depth_prompt': 'Say FRONT or BACK',
      'depth_trial': 'Trial {n} of {total}',
      'titmus_fly': 'Do the wings lift up? Say YES or NO',
      'titmus_animal': 'Which animal is closest? Say CAT, DUCK, or RABBIT',
      'titmus_circle':
          'Which circle pops forward? Say LEFT, RIGHT, TOP, BOTTOM, or MIDDLE',
      'lang_instruction': 'Look at the dot pattern carefully',
      'lang_prompt_star': 'Do you see a star? Say STAR or NOTHING',
      'lang_prompt_car': 'Do you see a car? Say CAR or NOTHING',
      'lang_prompt_cat': 'Do you see a cat face? Say CAT or NOTHING',
      'ishihara_instruction': 'What number do you see? Say the number',
      'ishihara_plate': 'Plate {n} of {total}',
      'snellen_instruction': 'Read each letter aloud',
      'snellen_say_letter': 'Say this letter aloud',
      'snellen_distance': 'Sit 40cm from screen',
      'snellen_e_instruction': 'Which way does the E point?',
      'snellen_e_prompt': 'Say UP, DOWN, LEFT, or RIGHT',
      'snellen_picture_instruction': 'Point to the same picture',
      'snellen_picture_prompt': 'Tap what the child points to',
      'result_normal': 'Normal',
      'result_mild': 'Mild',
      'result_high': 'High Risk',
      'result_urgent': 'Urgent',
      'result_next_test': 'Next test in {n} seconds',
      'result_next_now': 'Next Now',
      'got_it': 'Got it',
      'retry': 'Retry',
      'skip_test': 'Skip Test',
      'continue_btn': 'Continue',
      'loading': 'Loading...',
      'analyzing': 'Analyzing...',
      'listening_now': 'Listening...',
      'say_something': 'Say your answer',
    },
    'ml': {
      'eyescan_phase_init': 'തയ്യാറാകുന്നു...',
      'eyescan_phase_detect': 'കണ്ണുകൾ കണ്ടെത്തുന്നു...',
      'eyescan_phase_lock': 'ഏതാണ്ട് തയ്യാറായി!',
      'eyescan_phase_ready': 'നമുക്ക് തുടങ്ങാം!',
      'eyescan_distance': 'മുഖം ഫ്രെയിമിൽ നിർത്തൂ',
      'eyescan_locked': 'കണ്ണ് ലോക്ക് ആയി',
      'gaze_instruction': 'ഡോട്ട് കണ്ണ് കൊണ്ട് പിന്തുടരൂ',
      'gaze_direction': 'ഡോട്ടിലേക്ക് നോക്കൂ...',
      'gaze_capturing': 'ക്യാപ്ചർ ചെയ്യുന്നു...',
      'hirschberg_instruction': 'നേരെ ക്യാമറയിലേക്ക് നോക്കൂ',
      'hirschberg_flash': 'ഫ്ലാഷ് ഉടൻ ഉണ്ടാകും',
      'hirschberg_analyzing': 'കോർണിയൽ റിഫ്ലക്സ് പരിശോധിക്കുന്നു...',
      'redreflex_instruction':
          'ഫോൺ മുഖത്ത് നിന്ന് 30-40 സെ.മീ. അകലത്തിൽ പിടിക്കൂ',
      'redreflex_flash': 'കണ്ണ് തുറന്ന് സ്‌ക്രീനിലേക്ക് നോക്കൂ',
      'suppression_instruction': 'ഈ പാറ്റേൺ 30 സെക്കൻഡ് നോക്കൂ',
      'suppression_reading': 'വായന {n} / {total}',
      'suppression_prompt': 'HORIZONTAL, VERTICAL, അല്ലെങ്കിൽ SWITCHING പറയൂ',
      'suppression_prompt_b':
          'നിങ്ങൾ ഏത് നിറം കാണുന്നു? RED, BLUE, അല്ലെങ്കിൽ BOTH പറയൂ',
      'depth_instruction': 'തിളങ്ങുന്ന ഡോട്ട് നോക്കൂ',
      'depth_prompt': 'FRONT അല്ലെങ്കിൽ BACK പറയൂ',
      'depth_trial': 'ട്രയൽ {n} / {total}',
      'titmus_circle':
          'ഏത് വൃത്തം മുന്നോട്ട് വരുന്നു? LEFT, RIGHT, TOP, BOTTOM, അല്ലെങ്കിൽ MIDDLE പറയൂ',
      'lang_instruction': 'ഡോട്ട് പാറ്റേൺ ശ്രദ്ധിച്ചു നോക്കൂ',
      'lang_prompt_star':
          'ഒരു നക്ഷത്രം കാണുന്നുണ്ടോ? STAR അല്ലെങ്കിൽ NOTHING പറയൂ',
      'lang_prompt_car': 'ഒരു കാർ കാണുന്നുണ്ടോ? CAR അല്ലെങ്കിൽ NOTHING പറയൂ',
      'lang_prompt_cat':
          'ഒരു പൂച്ചയുടെ മുഖം കാണുന്നുണ്ടോ? CAT അല്ലെങ്കിൽ NOTHING പറയൂ',
      'snellen_instruction': 'ഓരോ അക്ഷരവും ഉറക്കെ വായിക്കൂ',
      'snellen_say_letter': 'ഈ അക്ഷരം ഉറക്കെ പറയൂ',
      'snellen_distance': 'സ്ക്രീനിൽ നിന്ന് 40 സെ.മീ. ഇരിക്കൂ',
      'snellen_picture_instruction': 'ഒരേ ചിത്രം ചൂണ്ടിക്കാണിക്കൂ',
      'snellen_picture_prompt': 'കുട്ടി ചൂണ്ടിക്കാണിക്കുന്നത് ടാപ്പ് ചെയ്യൂ',
      'listening_now': 'കേൾക്കുന്നു...',
      'say_something': 'നിങ്ങളുടെ ഉത്തരം പറയൂ',
      'test_complete': 'ടെസ്റ്റ് പൂർത്തിയായി',
      'next_test': 'അടുത്ത ടെസ്റ്റ്',
      'titmus_fly': 'ചിറകുകൾ ഉയരുന്നുണ്ടോ? YES അല്ലെങ്കിൽ NO പറയൂ',
      'titmus_animal':
          'ഏത് മൃഗം ഏറ്റവും അടുത്തുണ്ട്? CAT, DUCK, അല്ലെങ്കിൽ RABBIT പറയൂ',
      'ishihara_instruction': 'നിങ്ങൾ ഏത് നമ്പർ കാണുന്നു? നമ്പർ പറയൂ',
      'snellen_e_instruction': 'E ഏത് ദിശയിലേക്ക് ചൂണ്ടുന്നു?',
      'snellen_e_prompt': 'UP, DOWN, LEFT, അല്ലെങ്കിൽ RIGHT പറയൂ',
      'result_normal': 'സാധാരണം',
      'result_mild': 'മൃദുവായ',
      'result_high': 'ഉയർന്ന റിസ്ക്',
      'result_urgent': 'അടിയന്തര',
      'result_next_test': '{n} സെക്കൻഡിൽ അടുത്ത പരീക്ഷ',
      'got_it': 'മനസ്സിലായി',
      'retry': 'വീണ്ടും ശ്രമിക്കൂ',
      'skip_test': 'പരീക്ഷ ഒഴിവാക്കൂ',
      'continue_btn': 'തുടരൂ',
      'loading': 'ലോഡ് ചെയ്യുന്നു...',
      'analyzing': 'വിശകലനം ചെയ്യുന്നു...',
    },
    'hi': {
      'eyescan_phase_init': 'तैयार हो रहे हैं...',
      'eyescan_phase_detect': 'आँखें ढूंढ रहे हैं...',
      'eyescan_phase_lock': 'लगभग तैयार!',
      'eyescan_phase_ready': 'चलिए शुरू करते हैं!',
      'eyescan_distance': 'चेहरा फ्रेम में रखें',
      'eyescan_locked': 'आंख लॉक हो गई',
      'gaze_instruction': 'बिंदु को आंखों से फॉलो करें',
      'gaze_direction': 'बिंदु को देखें...',
      'hirschberg_instruction': 'सीधे कैमरे में देखें',
      'hirschberg_flash': 'फ्लैश थोड़ी देर में आएगा',
      'redreflex_instruction': 'फोन को चेहरे से 30-40 सेमी दूर रखें',
      'suppression_prompt': 'HORIZONTAL, VERTICAL या SWITCHING बोलें',
      'suppression_prompt_b':
          'आप कौन सा रंग देख रहे हैं? RED, BLUE या BOTH बोलें',
      'depth_prompt': 'FRONT या BACK बोलें',
      'titmus_fly': 'क्या पंख ऊपर उठ रहे हैं? YES या NO बोलें',
      'titmus_animal': 'कौन सा जानवर सबसे करीब है? CAT, DUCK या RABBIT बोलें',
      'ishihara_instruction': 'आप कौन सा नंबर देख रहे हैं? नंबर बोलें',
      'snellen_e_instruction': 'E किस दिशा में इशारा कर रहा है?',
      'snellen_e_prompt': 'UP, DOWN, LEFT या RIGHT बोलें',
      'result_normal': 'सामान्य',
      'result_mild': 'हल्का',
      'result_high': 'उच्च जोखिम',
      'result_urgent': 'तत्काल',
      'result_next_test': '{n} सेकंड में अगला परीक्षण',
      'got_it': 'समझ गया',
      'retry': 'फिर कोशिश करें',
      'skip_test': 'परीक्षण छोड़ें',
      'continue_btn': 'जारी रखें',
      'loading': 'लोड हो रहा है...',
      'analyzing': 'विश्लेषण हो रहा है...',
      'listening_now': 'सुन रहे हैं...',
      'say_something': 'अपना जवाब बोलें',
    },
    'ta': {
      'suppression_instruction': 'இந்த முறையை 30 வினாடி பாருங்கள்',
      'suppression_reading': 'படிப்பு {n} / {total}',
      'suppression_prompt': 'HORIZONTAL VERTICAL அல்லது SWITCHING சொல்லுங்கள்',
      'depth_instruction': 'ஒளிரும் புள்ளியை பாருங்கள்',
      'depth_prompt': 'FRONT அல்லது BACK என்று சொல்லுங்கள்',
      'depth_trial': 'சோதனை {n} / {total}',
      'lang_instruction': 'புள்ளி முறையை கவனமாக பாருங்கள்',
      'lang_prompt_star':
          'ஒரு நட்சத்திரம் தெரிகிறதா? STAR அல்லது NOTHING சொல்லுங்கள்',
      'lang_prompt_car': 'ஒரு கார் தெரிகிறதா? CAR அல்லது NOTHING சொல்லுங்கள்',
      'lang_prompt_cat':
          'ஒரு பூனை முகம் தெரிகிறதா? CAT அல்லது NOTHING சொல்லுங்கள்',
      'snellen_instruction': 'ஒவ்வொரு எழுத்தையும் சத்தமாக படியுங்கள்',
      'snellen_say_letter': 'இந்த எழுத்தை சத்தமாக சொல்லுங்கள்',
      'snellen_distance': 'திரையிலிருந்து 40 செ.மீ. அமருங்கள்',
      'snellen_picture_instruction': 'அதே படத்தை சுட்டிக்காட்டுங்கள்',
      'snellen_picture_prompt': 'குழந்தை சுட்டுவதை தட்டுங்கள்',
      'listening_now': 'கேட்கிறது...',
      'say_something': 'உங்கள் பதிலை சொல்லுங்கள்',
      'test_complete': 'சோதனை முடிந்தது',
      'next_test': 'அடுத்த சோதனை',
      'eyescan_phase_init': 'தயாராகுகிறோம்...',
      'eyescan_phase_detect': 'கண்களை கண்டுபிடிக்கிறோம்...',
      'eyescan_phase_lock': 'கிட்டத்தட்ட தயார்!',
      'eyescan_phase_ready': 'ஆரம்பிக்கலாம்!',
      'eyescan_distance': 'முகத்தை ஃப்ரேமில் வையுங்கள்',
      'eyescan_locked': 'கண் பூட்டப்பட்டது',
      'gaze_instruction': 'புள்ளியை கண்களால் பின்தொடரவும்',
      'gaze_direction': 'புள்ளியை பாருங்கள்...',
      'hirschberg_instruction': 'நேரடியாக கேமராவை பாருங்கள்',
      'hirschberg_flash': 'ஃபிளாஷ் சீக்கிரம் வரும்',
      'redreflex_instruction':
          'தொலைபேசியை முகத்திலிருந்து 30-40 செ.மீ தூரத்தில் பிடிக்கவும்',
      'suppression_prompt_b':
          'என்ன நிறம் பார்க்கிறீர்கள்? RED, BLUE அல்லது BOTH சொல்லுங்கள்',
      'titmus_fly': 'இறக்கைகள் மேலே உயர்கிறதா? YES அல்லது NO சொல்லுங்கள்',
      'titmus_animal':
          'எந்த விலங்கு மிக அருகில் உள்ளது? CAT, DUCK அல்லது RABBIT சொல்லுங்கள்',
      'ishihara_instruction': 'என்ன எண் பார்க்கிறீர்கள்? எண்ணை சொல்லுங்கள்',
      'snellen_e_instruction': 'E எந்த திசையில் சுட்டுகிறது?',
      'snellen_e_prompt': 'UP, DOWN, LEFT அல்லது RIGHT சொல்லுங்கள்',
      'result_normal': 'சாதாரண',
      'result_mild': 'லேசான',
      'result_high': 'அதிக ஆபத்து',
      'result_urgent': 'அவசரம்',
      'result_next_test': '{n} வினாடிகளில் அடுத்த சோதனை',
      'got_it': 'புரிந்தது',
      'retry': 'மீண்டும் முயற்சி',
      'skip_test': 'சோதனை தவிர்க்கவும்',
      'continue_btn': 'தொடரவும்',
      'loading': 'ஏற்றுகிறது...',
      'analyzing': 'பகுப்பாய்வு செய்கிறது...',
    },
  };
}
