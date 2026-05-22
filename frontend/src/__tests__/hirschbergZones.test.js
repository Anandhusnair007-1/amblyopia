import {
  normalizedOffsetR,
  zoneFromNormalizedR,
  classifyEyeZone,
  aggregateHirschbergZones,
  ZONE_PD,
} from "../core/clinical/hirschbergZones";

describe("hirschbergZones", () => {
  it("maps low r to center (0 PD)", () => {
    expect(zoneFromNormalizedR(0.1).predicted_pd).toBe(ZONE_PD.center);
    expect(zoneFromNormalizedR(0.34).zone).toBe("center");
  });

  it("maps pupil edge band to 15 PD", () => {
    expect(zoneFromNormalizedR(0.5).predicted_pd).toBe(15);
  });

  it("maps mid cornea to 30 PD", () => {
    expect(zoneFromNormalizedR(1.0).predicted_pd).toBe(30);
  });

  it("maps limbus to 45 PD", () => {
    expect(zoneFromNormalizedR(2.0).predicted_pd).toBe(45);
  });

  it("classifies eye from px displacement", () => {
    const z = classifyEyeZone({ displacementPx: 10, irisDiameterPx: 20 });
    expect(z.normalized_offset_r).toBe(1);
    expect(z.predicted_pd).toBe(30);
  });

  it("aggregate picks worst eye", () => {
    const left = classifyEyeZone({ displacementPx: 2, irisDiameterPx: 20 });
    const right = classifyEyeZone({ displacementPx: 20, irisDiameterPx: 20 });
    const agg = aggregateHirschbergZones(left, right);
    expect(agg.predicted_pd).toBe(45);
  });

  it("normalizedOffsetR uses half-iris", () => {
    expect(normalizedOffsetR(5, 10)).toBe(1);
  });
});
