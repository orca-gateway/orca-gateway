import { describe, expect, it } from "bun:test";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

// U15: the release notes come from the notes step of engine-release.yml. The
// test runs that step's own `run:` script with bash against a fixture
// CHANGELOG.md, so the step must stay one script driven by env vars.

const WORKFLOW = join(import.meta.dir, "../../.github/workflows/engine-release.yml");

type Step = { id?: string; name?: string; run?: string; env?: Record<string, string> };

function notesStep(): Step {
  const doc = Bun.YAML.parse(readFileSync(WORKFLOW, "utf8")) as {
    jobs: { publish: { steps: Step[] } };
  };
  const step = doc.jobs.publish.steps.find((s) => s.id === "notes");
  if (!step?.run) throw new Error("engine-release.yml: the publish job has no step with id notes and a run script");
  return step;
}

function runNotes(changelog: string, version: string) {
  const dir = mkdtempSync(join(tmpdir(), "engine-release-notes-"));
  try {
    const changelogPath = join(dir, "CHANGELOG.md");
    const notesPath = join(dir, "notes.md");
    writeFileSync(changelogPath, changelog);
    // GitHub runs a `run:` step with no `shell:` as `bash -e {0}`.
    const res = Bun.spawnSync(["bash", "-e", "-c", notesStep().run!], {
      cwd: dir,
      env: { PATH: process.env.PATH ?? "/usr/bin:/bin", VERSION: version, CHANGELOG: changelogPath, NOTES: notesPath },
    });
    return {
      code: res.exitCode,
      out: res.stdout.toString() + res.stderr.toString(),
      notes: existsSync(notesPath) ? readFileSync(notesPath, "utf8") : null,
    };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

const RULE = "\n---\n";

const S036 = ["## 0.3.6 - 2026-11-20", "", "### Changed", "", "- Line only in 0.3.6."];
const S035_BODY = [
  "### Added",
  "",
  "- Todo example on the demo server: add, tick, delete.",
  "",
  "### Fixed",
  "",
  "- Line only in 0.3.5.",
];
const S034 = ["## 0.3.4 - 2026-11-10", "", "### Removed", "", "- Line only in 0.3.4."];

describe("engine-release.yml notes step", () => {
  it("U15 notes for engine-v0.3.5: the Run block, then exactly the 0.3.5 body; no 0.3.6, 0.3.4 or 0.3.50 line", () => {
    const step = notesStep();
    // One self-contained script: no workflow expressions inside it, and the
    // step wires the real changelog and the env vars the script reads.
    expect(step.run).not.toContain("${{");
    expect(step.env?.CHANGELOG).toBe("engine/CHANGELOG.md");
    expect(Object.keys(step.env ?? {})).toEqual(expect.arrayContaining(["VERSION", "CHANGELOG", "NOTES"]));

    const changelog = ["# Changelog", "", ...S036, "", "## 0.3.5 - 2026-11-14", "", ...S035_BODY, "", ...S034, ""].join("\n");
    const { code, out, notes } = runNotes(changelog, "0.3.5");
    expect(code, out).toBe(0);
    expect(notes).not.toBeNull();

    const at = notes!.indexOf(RULE);
    expect(at).toBeGreaterThan(0);
    const runBlock = notes!.slice(0, at);
    const body = notes!.slice(at + RULE.length);

    // The Run block comes first.
    expect(runBlock).toContain("Run the demo server");
    expect(runBlock).toContain("docker run --rm -p 8080:8080 ghcr.io/orca-gateway/demo-server:0.3.5");
    expect(runBlock).toContain("or download yours below and open it. First start:");
    expect(runBlock).toContain("macOS: Privacy & Security › Open Anyway.");
    expect(runBlock).toContain("Windows: More info › Run anyway.");
    for (const line of S035_BODY.filter(Boolean)) expect(runBlock).not.toContain(line);

    // Then exactly the 0.3.5 body, and nothing from its neighbours.
    expect(body.trim()).toBe(S035_BODY.join("\n"));
    const lines = notes!.split("\n");
    for (const line of [...S036, ...S034, "## 0.3.5 - 2026-11-14"].filter(Boolean)) {
      expect(lines).not.toContain(line);
    }

    // "## 0.3.50" is not taken for 0.3.5: alone, the step fails ...
    const only050 = ["# Changelog", "", "## 0.3.50 - 2026-12-01", "", "- Line only in 0.3.50.", ""].join("\n");
    const missing = runNotes(only050, "0.3.5");
    expect(missing.code, missing.out).not.toBe(0);
    expect(missing.out).toContain("## 0.3.5");
    expect(missing.notes ?? "").not.toContain("Line only in 0.3.50.");

    // ... and above a bare "## 0.3.5" heading, only 0.3.5's body is taken.
    const both = ["# Changelog", "", "## 0.3.50 - 2026-12-01", "", "- Line only in 0.3.50.", "", "## 0.3.5", "", "- Bare heading body.", ""].join("\n");
    const bare = runNotes(both, "0.3.5");
    expect(bare.code, bare.out).toBe(0);
    expect(bare.notes!.slice(bare.notes!.indexOf(RULE) + RULE.length).trim()).toBe("- Bare heading body.");
    expect(bare.notes).not.toContain("0.3.50");
  });
});
