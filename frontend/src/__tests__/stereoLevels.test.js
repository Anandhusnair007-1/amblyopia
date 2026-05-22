import {
  arcSecondsFromLevels,
  stereoGradeFromArcSeconds,
  STEREO_LEVELS_ASCENDING,
} from "../core/vision/stereoLevels";

describe("stereoLevels", () => {
  it("returns 2500 when no levels passed", () => {
    expect(arcSecondsFromLevels([])).toBe(2500);
  });

  it("returns finest passed arc seconds", () => {
    const passed = [STEREO_LEVELS_ASCENDING[0], STEREO_LEVELS_ASCENDING[3]];
    expect(arcSecondsFromLevels(passed)).toBe(120);
  });

  it("maps arc seconds to Sandra bands", () => {
    expect(stereoGradeFromArcSeconds(50)).toBe("normal");
    expect(stereoGradeFromArcSeconds(150)).toBe("mild_impairment");
    expect(stereoGradeFromArcSeconds(500)).toBe("moderate");
    expect(stereoGradeFromArcSeconds(900)).toBe("severe");
    expect(stereoGradeFromArcSeconds(3000)).toBe("absence_stereo");
  });
});
