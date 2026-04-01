/// Localized strings for the Informed Consent screen.
/// Languages: English (en), Malayalam (ml), Hindi (hi), Tamil (ta).
class ConsentStrings {
  ConsentStrings({
    required this.title,
    required this.page1Title,
    required this.page1Bullets,
    required this.page2Title,
    required this.page2Bullets,
    required this.page3Title,
    required this.page3Bullets,
    required this.formTitle,
    required this.patientNameLabel,
    required this.dateOfBirthLabel,
    required this.guardianNameLabel,
    required this.guardianRelationLabel,
    required this.checkboxCamera,
    required this.checkboxStored,
    required this.checkboxResearch,
    required this.checkboxShareDoctor,
    required this.signatureHint,
    required this.consentButton,
    required this.renewalTitle,
    required this.renewalSubtitle,
    required this.renewalExpiredPrefix,
    required this.renewalExpiredSuffix,
  });

  final String title;
  final String page1Title;
  final List<String> page1Bullets;
  final String page2Title;
  final List<String> page2Bullets;
  final String page3Title;
  final List<String> page3Bullets;
  final String formTitle;
  final String patientNameLabel;
  final String dateOfBirthLabel;
  final String guardianNameLabel;
  final String guardianRelationLabel;
  final String checkboxCamera;
  final String checkboxStored;
  final String checkboxResearch;
  final String checkboxShareDoctor;
  final String signatureHint;
  final String consentButton;
  final String renewalTitle;
  final String renewalSubtitle;
  final String renewalExpiredPrefix;
  final String renewalExpiredSuffix;

  static ConsentStrings forLanguage(String code) {
    switch (code) {
      case 'ml':
        return _malayalam;
      case 'hi':
        return _hindi;
      case 'ta':
        return _tamil;
      default:
        return _english;
    }
  }

  static final ConsentStrings _english = ConsentStrings(
    title: 'Informed Consent',
    page1Title: 'What We Collect',
    page1Bullets: [
      'Camera images (eye region only)',
      'Test responses (voice)',
      'Results stored on device',
      'Anonymized data for research',
    ],
    page2Title: 'How We Use It',
    page2Bullets: [
      'Screen for amblyopia',
      'Share with assigned doctor',
      'Improve AI model (anonymized)',
      'Never sold to third parties',
    ],
    page3Title: 'Your Rights',
    page3Bullets: [
      'Delete your data anytime',
      'Withdraw consent anytime',
      'Not a clinical diagnosis',
      'Consult doctor for treatment',
    ],
    formTitle: 'Consent Form',
    patientNameLabel: 'Patient / Child Name',
    dateOfBirthLabel: 'Date of Birth',
    guardianNameLabel: 'Guardian Name (required if age < 18)',
    guardianRelationLabel: 'Relationship',
    checkboxCamera: 'Camera use during tests',
    checkboxStored: 'Results stored on device',
    checkboxResearch: 'Anonymized data for research',
    checkboxShareDoctor: 'Results shared with doctor',
    signatureHint: 'Draw your signature below',
    consentButton: 'I Consent',
    renewalTitle: 'Consent Renewal',
    renewalSubtitle: 'Your previous consent is over 12 months old. Please review and renew.',
    renewalExpiredPrefix: 'Your consent from ',
    renewalExpiredSuffix: ' has expired.',
  );

  static final ConsentStrings _malayalam = ConsentStrings(
    title: 'അറിവുള്ള സമ്മതം',
    page1Title: 'ഞങ്ങൾ എന്ത് ശേഖരിക്കുന്നു',
    page1Bullets: [
      'ക്യാമറ ചിത്രങ്ങൾ (കണ്ണ് പ്രദേശം മാത്രം)',
      'ടെസ്റ്റ് പ്രതികരണങ്ങൾ (ശബ്ദം)',
      'ഫലങ്ങൾ ഉപകരണത്തിൽ സംഭരിച്ചിരിക്കുന്നു',
      'ഗവേഷണത്തിനായി അജ്ഞാത ഡാറ്റ',
    ],
    page2Title: 'ഞങ്ങൾ ഇത് എങ്ങനെ ഉപയോഗിക്കുന്നു',
    page2Bullets: [
      'ആംബ്ലിയോപിയയ്ക്ക് സ്ക്രീനിംഗ്',
      'നിയുക്ത ഡോക്ടറുമായി പങ്കിടുക',
      'AI മോഡൽ മെച്ചപ്പെടുത്തുക (അജ്ഞാതം)',
      'മൂന്നാം കക്ഷികൾക്ക് ഒരിക്കലും വിറ്റഴിക്കില്ല',
    ],
    page3Title: 'നിങ്ങളുടെ അവകാശങ്ങൾ',
    page3Bullets: [
      'നിങ്ങളുടെ ഡാറ്റ എപ്പോൾ വേണമെങ്കിലും ഇല്ലാതാക്കുക',
      'എപ്പോൾ വേണമെങ്കിലും സമ്മതം പിൻവലിക്കുക',
      'ക്ലിനിക്കൽ രോഗനിർണയമല്ല',
      'ചികിത്സയ്ക്ക് ഡോക്ടറുമായി ആലോചിക്കുക',
    ],
    formTitle: 'സമ്മത ഫോം',
    patientNameLabel: 'രോഗി / കുട്ടിയുടെ പേര്',
    dateOfBirthLabel: 'ജനനത്തീയതി',
    guardianNameLabel: 'അഭിഭാവകന്റെ പേര് (18 വയസ്സിന് താഴെ ആവശ്യം)',
    guardianRelationLabel: 'ബന്ധം',
    checkboxCamera: 'ടെസ്റ്റുകളിൽ ക്യാമറ ഉപയോഗം',
    checkboxStored: 'ഫലങ്ങൾ ഉപകരണത്തിൽ സംഭരിച്ചിരിക്കുന്നു',
    checkboxResearch: 'ഗവേഷണത്തിനായി അജ്ഞാത ഡാറ്റ',
    checkboxShareDoctor: 'ഫലങ്ങൾ ഡോക്ടറുമായി പങ്കിടുന്നു',
    signatureHint: 'ചുവടെ നിങ്ങളുടെ ഒപ്പ് വരയ്ക്കുക',
    consentButton: 'ഞാൻ സമ്മതിക്കുന്നു',
    renewalTitle: 'സമ്മത പുതുക്കൽ',
    renewalSubtitle: 'നിങ്ങളുടെ മുമ്പത്തെ സമ്മതം 12 മാസത്തിലധികം പഴയതാണ്. അവലോകനം ചെയ്ത് പുതുക്കുക.',
    renewalExpiredPrefix: 'നിങ്ങളുടെ സമ്മതം ',
    renewalExpiredSuffix: ' മുതൽ കാലഹരണപ്പെട്ടു.',
  );

  static final ConsentStrings _hindi = ConsentStrings(
    title: 'सूचित सहमति',
    page1Title: 'हम क्या एकत्र करते हैं',
    page1Bullets: [
      'कैमरा छवियां (केवल आंख क्षेत्र)',
      'टेस्ट प्रतिक्रियाएं (आवाज)',
      'परिणाम डिवाइस पर संग्रहित',
      'अनुसंधान के लिए अनाम डेटा',
    ],
    page2Title: 'हम इसका उपयोग कैसे करते हैं',
    page2Bullets: [
      'एम्ब्लियोपिया के लिए स्क्रीनिंग',
      'नियुक्त डॉक्टर के साथ साझा करें',
      'AI मॉडल में सुधार (अनाम)',
      'तीसरे पक्ष को कभी नहीं बेचा जाता',
    ],
    page3Title: 'आपके अधिकार',
    page3Bullets: [
      'किसी भी समय अपना डेटा हटाएं',
      'किसी भी समय सहमति वापस लें',
      'नैदानिक निदान नहीं',
      'उपचार के लिए डॉक्टर से परामर्श करें',
    ],
    formTitle: 'सहमति फॉर्म',
    patientNameLabel: 'रोगी / बच्चे का नाम',
    dateOfBirthLabel: 'जन्म तिथि',
    guardianNameLabel: 'अभिभावक का नाम (18 वर्ष से कम उम्र में आवश्यक)',
    guardianRelationLabel: 'संबंध',
    checkboxCamera: 'टेस्ट के दौरान कैमरा उपयोग',
    checkboxStored: 'परिणाम डिवाइस पर संग्रहित',
    checkboxResearch: 'अनुसंधान के लिए अनाम डेटा',
    checkboxShareDoctor: 'परिणाम डॉक्टर के साथ साझा',
    signatureHint: 'नीचे अपने हस्ताक्षर बनाएं',
    consentButton: 'मैं सहमत हूं',
    renewalTitle: 'सहमति नवीनीकरण',
    renewalSubtitle: 'आपकी पिछली सहमति 12 महीने से अधिक पुरानी है। कृपया समीक्षा करें और नवीनीकरण करें।',
    renewalExpiredPrefix: 'आपकी सहमति ',
    renewalExpiredSuffix: ' को समाप्त हो गई।',
  );

  static final ConsentStrings _tamil = ConsentStrings(
    title: 'தகவலறிந்த சம்மதம்',
    page1Title: 'நாம் என்ன சேகரிக்கிறோம்',
    page1Bullets: [
      'கேமரா படங்கள் (கண் பகுதி மட்டும்)',
      'சோதனை பதில்கள் (குரல்)',
      'முடிவுகள் சாதனத்தில் சேமிக்கப்படுகின்றன',
      'ஆராய்ச்சிக்கு அடையாளம் காணப்படாத தரவு',
    ],
    page2Title: 'இதை நாம் எவ்வாறு பயன்படுத்துகிறோம்',
    page2Bullets: [
      'அம்பிலியோபியாவிற்கு திரையிடல்',
      'நியமிக்கப்பட்ட மருத்துவருடன் பகிரவும்',
      'AI மாதிரியை மேம்படுத்துதல் (அடையாளம் காணப்படாதது)',
      'மூன்றாம் தரப்பினருக்கு ஒருபோதும் விற்கப்படாது',
    ],
    page3Title: 'உங்கள் உரிமைகள்',
    page3Bullets: [
      'எந்த நேரத்திலும் உங்கள் தரவை நீக்குங்கள்',
      'எந்த நேரத்திலும் சம்மதத்தை திரும்பப் பெறுங்கள்',
      'மருத்துவ நோய் அறிதல் அல்ல',
      'சிகிச்சைக்கு மருத்துவரைக் கலந்தாலோசிக்கவும்',
    ],
    formTitle: 'சம்மத படிவம்',
    patientNameLabel: 'நோயாளி / குழந்தை பெயர்',
    dateOfBirthLabel: 'பிறந்த தேதி',
    guardianNameLabel: 'பாதுகாவலர் பெயர் (18 வயதுக்கு கீழ் தேவை)',
    guardianRelationLabel: 'உறவு',
    checkboxCamera: 'சோதனைகளின் போது கேமரா பயன்பாடு',
    checkboxStored: 'முடிவுகள் சாதனத்தில் சேமிக்கப்படுகின்றன',
    checkboxResearch: 'ஆராய்ச்சிக்கு அடையாளம் காணப்படாத தரவு',
    checkboxShareDoctor: 'முடிவுகள் மருத்துவருடன் பகிரப்படுகின்றன',
    signatureHint: 'கீழே உங்கள் கையெழுத்தை வரையவும்',
    consentButton: 'நான் சம்மதிக்கிறேன்',
    renewalTitle: 'சம்மத புதுப்பிப்பு',
    renewalSubtitle: 'உங்கள் முந்தைய சம்மதம் 12 மாதங்களுக்கு மேல் பழமையானது. மதிப்பாய்வு செய்து புதுப்பிக்கவும்.',
    renewalExpiredPrefix: 'உங்கள் சம்மதம் ',
    renewalExpiredSuffix: ' காலாவதியாகிவிட்டது.',
  );
}
