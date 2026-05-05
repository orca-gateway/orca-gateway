// Unit tests for min-sdk-version.ts (Epic 25b task 25b.6).
//
// The e2e test at caps-policy-e2e.test.ts covers the HTTP 426 response path
// end-to-end through a live engine. This file covers the pure helpers in
// isolation so regressions in semver parsing / gate logic surface without
// needing to boot a server.

import { describe, test, expect } from "bun:test";
import {
  parseSemver,
  compareSemver,
  createStaticMinSdkResolver,
  checkMinSdkVersion,
  buildUpgradeRequiredBody,
} from "../src/core/min-sdk-version";

describe("parseSemver", () => {
  test("parses a well-formed version", () => {
    expect(parseSemver("1.2.3")).toEqual([1, 2, 3]);
    expect(parseSemver("0.0.0")).toEqual([0, 0, 0]);
    expect(parseSemver("10.20.30")).toEqual([10, 20, 30]);
  });

  test("rejects malformed input as null", () => {
    expect(parseSemver("")).toBeNull();
    expect(parseSemver("1.2")).toBeNull();
    expect(parseSemver("1.2.3.4")).toBeNull();
    expect(parseSemver("1.2.x")).toBeNull();
    expect(parseSemver("v1.2.3")).toBeNull();
    expect(parseSemver("1.2.3-beta")).toBeNull();
    expect(parseSemver("a.b.c")).toBeNull();
  });
});

describe("compareSemver", () => {
  test("equal versions return 0", () => {
    expect(compareSemver("1.2.3", "1.2.3")).toBe(0);
  });

  test("numeric precedence across major/minor/patch", () => {
    expect(compareSemver("1.0.0", "2.0.0")).toBeLessThan(0);
    expect(compareSemver("2.0.0", "1.0.0")).toBeGreaterThan(0);
    expect(compareSemver("1.1.0", "1.2.0")).toBeLessThan(0);
    expect(compareSemver("1.0.1", "1.0.2")).toBeLessThan(0);
  });

  test("two-digit components sort numerically, not lexically", () => {
    // Lexical sort would put "10" before "2" — the parser must compare as numbers.
    expect(compareSemver("1.10.0", "1.2.0")).toBeGreaterThan(0);
    expect(compareSemver("1.2.10", "1.2.2")).toBeGreaterThan(0);
  });

  test("malformed input compares as zero (safe default)", () => {
    expect(compareSemver("garbage", "1.0.0")).toBe(0);
    expect(compareSemver("1.0.0", "garbage")).toBe(0);
    expect(compareSemver("", "1.0.0")).toBe(0);
  });
});

describe("createStaticMinSdkResolver", () => {
  test("empty config returns empty min (no gate)", () => {
    const r = createStaticMinSdkResolver({});
    expect(r.minFor(undefined)).toBe("");
    expect(r.minFor("prod")).toBe("");
  });

  test("appDefault applies when no env matches", () => {
    const r = createStaticMinSdkResolver({ appDefault: "1.0.0" });
    expect(r.minFor(undefined)).toBe("1.0.0");
    expect(r.minFor("staging")).toBe("1.0.0");
  });

  test("envOverrides take precedence over appDefault", () => {
    const r = createStaticMinSdkResolver({
      appDefault: "1.0.0",
      envOverrides: { prod: "2.0.0", dev: "0.5.0" },
    });
    expect(r.minFor("prod")).toBe("2.0.0");
    expect(r.minFor("dev")).toBe("0.5.0");
    expect(r.minFor("staging")).toBe("1.0.0"); // unlisted env → appDefault
    expect(r.minFor(undefined)).toBe("1.0.0");
  });

  test("empty-string override explicitly disables the gate for that env", () => {
    const r = createStaticMinSdkResolver({
      appDefault: "99.0.0",
      envOverrides: { dev: "" },
    });
    expect(r.minFor("dev")).toBe(""); // empty → no min
    expect(r.minFor("prod")).toBe("99.0.0");
  });
});

describe("checkMinSdkVersion", () => {
  test("empty min always allows", () => {
    expect(checkMinSdkVersion("0.0.1", "")).toBeNull();
    expect(checkMinSdkVersion(undefined, "")).toBeNull();
  });

  test("unversioned client always allows", () => {
    // Safety: dev tools and unversioned scripts should NOT be blocked by a min.
    expect(checkMinSdkVersion(undefined, "2.0.0")).toBeNull();
    expect(checkMinSdkVersion("", "2.0.0")).toBeNull();
  });

  test("malformed client version always allows", () => {
    // Don't punish garbage headers — treat as unversioned.
    expect(checkMinSdkVersion("garbage", "2.0.0")).toBeNull();
    expect(checkMinSdkVersion("v1", "2.0.0")).toBeNull();
  });

  test("client below min is blocked and returns the enforced min", () => {
    expect(checkMinSdkVersion("1.0.0", "2.0.0")).toBe("2.0.0");
    expect(checkMinSdkVersion("1.9.99", "2.0.0")).toBe("2.0.0");
  });

  test("client at exactly min is allowed", () => {
    expect(checkMinSdkVersion("2.0.0", "2.0.0")).toBeNull();
  });

  test("client above min is allowed", () => {
    expect(checkMinSdkVersion("2.0.1", "2.0.0")).toBeNull();
    expect(checkMinSdkVersion("3.0.0", "2.0.0")).toBeNull();
  });
});

describe("buildUpgradeRequiredBody", () => {
  test("body carries the three diagnostic fields + PageResponse envelope", () => {
    const body = buildUpgradeRequiredBody("home", "1.0.0", "2.0.0");
    expect(body.error).toBe("sdk_version_too_old");
    expect(body.minSdkVersion).toBe("2.0.0");
    expect(body.clientSdkVersion).toBe("1.0.0");
    expect(body.page).toBeDefined();
  });

  test("embedded page is a PageResponse with a single blocking FallbackPrompt", () => {
    const body = buildUpgradeRequiredBody("home", "1.0.0", "2.0.0");
    expect(body.page.pageId).toBe("home");
    expect(body.page.title).toBe("Update required");
    expect(body.page.state).toEqual([]);
    expect(body.page.components).toHaveLength(1);

    const block = body.page.components[0];
    expect(block.id).toBe("__min_sdk_block_root__");
    expect(block.type).toBe("FallbackPrompt");
    expect(block.kind).toBe("primitive");
    expect(block.childMode).toBe("none");
    expect(block.props.severity).toBe("blocking");
    expect(block.props.title).toBe("Update required");
    // The body text includes the enforced min version so the user knows
    // what to update to.
    expect(block.props.body).toContain("2.0.0");
    expect(block.children).toEqual([]);
    expect(block.watches).toEqual([]);
  });

  test("undefined client version falls through as empty string in the body", () => {
    const body = buildUpgradeRequiredBody("home", undefined, "2.0.0");
    expect(body.clientSdkVersion).toBe("");
    expect(body.minSdkVersion).toBe("2.0.0");
  });
});
