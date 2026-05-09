/**
 * Minimal smoke test so CI can run `npm test` before more UI tests exist.
 */
test("jest and jsdom are wired", () => {
  expect(typeof document).toBe("object");
  expect(1 + 1).toBe(2);
});
