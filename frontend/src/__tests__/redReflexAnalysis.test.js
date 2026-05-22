import {
  classifyRedReflexEye,
  aggregateRedReflex,
  redRatio,
} from "../core/clinical/redReflexAnalysis";

describe("redReflexAnalysis", () => {
  it("detects normal red pupil", () => {
    const out = classifyRedReflexEye([200, 40, 40]);
    expect(out.classification).toBe("normal");
    expect(out.red_ratio).toBeGreaterThan(0.38);
  });

  it("detects leukocoria (bright desaturated)", () => {
    const out = classifyRedReflexEye([240, 235, 230]);
    expect(out.classification).toBe("leukocoria");
  });

  it("aggregate prefers worst eye", () => {
    const left = classifyRedReflexEye([200, 40, 40]);
    const right = classifyRedReflexEye([240, 235, 230]);
    const agg = aggregateRedReflex(left, right);
    expect(agg.classification).toBe("leukocoria");
    expect(agg.asymmetric).toBe(true);
  });

  it("redRatio favors red channel", () => {
    expect(redRatio(200, 50, 50)).toBeGreaterThan(0.6);
  });
});
