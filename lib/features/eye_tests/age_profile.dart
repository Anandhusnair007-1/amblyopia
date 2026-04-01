/// Age-based test profile. Determines which tests run and which variant of each.
/// Profile A: 3-4 (Preverbal), B: 5-7 (Early verbal), C: 8+ (Standard).
enum AgeProfile {
  a,
  b,
  c;

  /// Profile A = 3-4, B = 5-7, C = 8+
  static AgeProfile fromAge(int age) {
    if (age <= 4) return AgeProfile.a;
    if (age <= 7) return AgeProfile.b;
    return AgeProfile.c;
  }

  String get label {
    switch (this) {
      case AgeProfile.a:
        return 'Age 3-4 (Preverbal)';
      case AgeProfile.b:
        return 'Age 5-7 (Early verbal)';
      case AgeProfile.c:
        return 'Age 8+ (Standard)';
    }
  }
}

/// Snellen variant per profile.
enum SnellenVariant {
  /// Picture chart: House, Bird, Apple, Hand — worker taps what child points to (Profile A).
  picture,
  /// Tumbling E — child says or points direction (Profile B).
  tumblingE,
  /// Standard letter chart + voice (Profile C).
  letter,
}

SnellenVariant snellenVariantForProfile(AgeProfile p) {
  switch (p) {
    case AgeProfile.a:
      return SnellenVariant.picture;
    case AgeProfile.b:
      return SnellenVariant.tumblingE;
    case AgeProfile.c:
      return SnellenVariant.letter;
  }
}

/// Suppression test variant.
enum SuppressionVariant {
  /// Full-screen red/blue flash; worker reports "Both eyes blinked" / "Only one eye" (Profile A).
  simplifiedFlash,
  /// Voice: "What color? Red / Blue / Both" (Profile B).
  simplifiedVoice,
  /// Standard horizontal/vertical rivalry (Profile C).
  standard,
}

SuppressionVariant suppressionVariantForProfile(AgeProfile p) {
  switch (p) {
    case AgeProfile.a:
      return SuppressionVariant.simplifiedFlash;
    case AgeProfile.b:
      return SuppressionVariant.simplifiedVoice;
    case AgeProfile.c:
      return SuppressionVariant.standard;
  }
}

/// Ishihara: skip (A), 4 plates (B), full (C).
bool isIshiharaSkippedForProfile(AgeProfile p) => p == AgeProfile.a;
bool isIshiharaSimplifiedForProfile(AgeProfile p) => p == AgeProfile.b;

/// Titmus: fly only (A), fly + animal (B), full (C).
enum TitmusVariant {
  flyOnly,
  flyAndAnimal,
  full,
}

TitmusVariant titmusVariantForProfile(AgeProfile p) {
  switch (p) {
    case AgeProfile.a:
      return TitmusVariant.flyOnly;
    case AgeProfile.b:
      return TitmusVariant.flyAndAnimal;
    case AgeProfile.c:
      return TitmusVariant.full;
  }
}

/// Depth: simplified (observe head turning) for A only.
bool isDepthSimplifiedForProfile(AgeProfile p) => p == AgeProfile.a;
