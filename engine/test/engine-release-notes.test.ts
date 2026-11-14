import { describe, expect, it } from "bun:test";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
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

// U16-U19: the build targets, what a pre-release does to the image and to the
// GitHub release, and the macOS check. The image and publish steps run their
// own `run:` scripts with bash against a stub docker / gh that records its
// arguments, one call per line.

type Job = {
  name?: string;
  needs?: string | string[];
  "runs-on"?: string;
  "timeout-minutes"?: number;
  permissions?: Record<string, string>;
  env?: Record<string, string>;
  steps: Step[];
};

function workflowJobs(): Record<string, Job> {
  return (Bun.YAML.parse(readFileSync(WORKFLOW, "utf8")) as { jobs: Record<string, Job> }).jobs;
}

function publishStep(name: string): Step {
  const step = workflowJobs().publish.steps.find((s) => s.name === name);
  if (!step?.run) throw new Error(`engine-release.yml: the publish job has no step "${name}" with a run script`);
  return step;
}

// `stub` is bash run after the call is logged; `env` gets the temp dir.
function runWithStub(step: Step, cmd: string, stub: string, env: (dir: string) => Record<string, string>) {
  const dir = mkdtempSync(join(tmpdir(), "engine-release-stub-"));
  try {
    const bin = join(dir, "bin");
    const work = join(dir, "work");
    mkdirSync(bin);
    mkdirSync(work);
    const log = join(dir, `${cmd}.log`);
    writeFileSync(join(bin, cmd), `#!/usr/bin/env bash\nprintf '%s\\n' "$*" >> '${log}'\n${stub}\nexit 0\n`, { mode: 0o755 });
    const vars = env(dir);
    const res = Bun.spawnSync(["bash", "-e", "-c", step.run!], {
      cwd: work,
      env: { PATH: `${bin}:${process.env.PATH ?? "/usr/bin:/bin"}`, ...vars },
    });
    return {
      code: res.exitCode,
      out: res.stdout.toString() + res.stderr.toString(),
      calls: existsSync(log) ? readFileSync(log, "utf8").split("\n").filter(Boolean) : [],
      vars,
    };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

const IMAGE = "ghcr.io/orca-gateway/demo-server";

describe("engine-release.yml builds, pre-releases and the macOS check", () => {
  it("U16 the compile step targets bun-linux-x64-baseline, bun-windows-x64-baseline and bun-darwin-arm64; asset names unchanged", () => {
    const run = publishStep("Compile the demo server").run!;
    const builds = run
      .split("\n")
      .filter((line) => line.includes("bun build --compile"))
      .map((line) => [line.match(/--target=(\S+)/)?.[1], line.match(/--outfile\s+"?([^"\s]+)"?/)?.[1]]);
    expect(builds).toEqual([
      ["bun-linux-x64-baseline", "$ASSETS/demo-server-linux-x64"],
      ["bun-windows-x64-baseline", "$ASSETS/demo-server-windows-x64.exe"],
      ["bun-darwin-arm64", "$ASSETS/macos/demo-server"],
    ]);
    expect(run).toContain("zip -q ../demo-server-macos-arm64.zip demo-server");

    // The release still ships the same three files.
    const publish = publishStep("Publish the release").run!;
    for (const asset of ["demo-server-linux-x64", "demo-server-windows-x64.exe", "demo-server-macos-arm64.zip"]) {
      expect(publish).toContain(`"$ASSETS/${asset}"`);
    }
  });

  it("U17 the image step pushes :0.3.5 and :latest for 0.3.5, and only :0.4.0-alpha.1 for 0.4.0-alpha.1", () => {
    const step = publishStep("Build and push the image");
    expect(step.run).not.toContain("${{");
    expect(Object.keys(step.env ?? {})).toEqual(
      expect.arrayContaining(["VERSION", "ASSETS", "CONTEXT", "REPO", "ACTOR", "GITHUB_TOKEN"]),
    );

    const image = (version: string) =>
      runWithStub(step, "docker", `if [ "$1" = login ]; then cat > /dev/null; fi`, (dir) => {
        mkdirSync(join(dir, "assets"));
        writeFileSync(join(dir, "assets", "demo-server-linux-x64"), "binary");
        return {
          VERSION: version,
          ASSETS: join(dir, "assets"),
          CONTEXT: join(dir, "image"),
          REPO: "orca-gateway/orca-gateway",
          ACTOR: "release-bot",
          GITHUB_TOKEN: "dummy-token",
        };
      });

    const stable = image("0.3.5");
    expect(stable.code, stable.out).toBe(0);
    expect(stable.calls.some((c) => c.startsWith("build ") && c.includes(`-t ${IMAGE}:0.3.5`))).toBe(true);
    // :latest is put on the image (build -t or docker tag) and pushed.
    expect(stable.calls.some((c) => !c.startsWith("push ") && c.includes(`${IMAGE}:latest`))).toBe(true);
    expect(stable.calls).toContain(`push ${IMAGE}:0.3.5`);
    expect(stable.calls).toContain(`push ${IMAGE}:latest`);

    const pre = image("0.4.0-alpha.1");
    expect(pre.code, pre.out).toBe(0);
    expect(pre.calls.some((c) => c.startsWith("build ") && c.includes(`-t ${IMAGE}:0.4.0-alpha.1`))).toBe(true);
    expect(pre.calls).toContain(`push ${IMAGE}:0.4.0-alpha.1`);
    expect(pre.calls.join("\n")).not.toContain(":latest");
  });

  it("U18 the publish step makes a pre-release version a GitHub pre-release, on create and on a re-run; a stable one stays a normal release", () => {
    const step = publishStep("Publish the release");
    expect(step.run).not.toContain("${{");

    const publish = (version: string, exists: boolean) =>
      runWithStub(step, "gh", `if [ "$1 $2" = "release view" ]; then exit ${exists ? 0 : 1}; fi`, (dir) => ({
        TAG: `engine-v${version}`,
        VERSION: version,
        ASSETS: join(dir, "assets"),
        NOTES: join(dir, "release-notes.md"),
        GH_TOKEN: "dummy-token",
        GH_REPO: "orca-gateway/orca-gateway",
      }));
    const call = (calls: string[], verb: string) => calls.filter((c) => c.startsWith(`release ${verb} `));

    const newPre = publish("0.4.0-alpha.1", false);
    expect(newPre.code, newPre.out).toBe(0);
    expect(call(newPre.calls, "create")).toHaveLength(1);
    expect(call(newPre.calls, "create")[0]).toContain("engine-v0.4.0-alpha.1");
    expect(call(newPre.calls, "create")[0]).toContain("--prerelease");

    const newStable = publish("0.3.5", false);
    expect(newStable.code, newStable.out).toBe(0);
    expect(call(newStable.calls, "create")).toHaveLength(1);
    expect(call(newStable.calls, "create")[0]).toContain("engine-v0.3.5");
    expect(newStable.calls.join("\n")).not.toContain("--prerelease");

    const rerunPre = publish("0.4.0-alpha.1", true);
    expect(rerunPre.code, rerunPre.out).toBe(0);
    expect(call(rerunPre.calls, "create")).toHaveLength(0);
    expect(call(rerunPre.calls, "upload")[0]).toContain("--clobber");
    expect(call(rerunPre.calls, "edit")).toHaveLength(1);
    expect(call(rerunPre.calls, "edit")[0]).toContain("--prerelease");

    const rerunStable = publish("0.3.5", true);
    expect(rerunStable.code, rerunStable.out).toBe(0);
    expect(call(rerunStable.calls, "create")).toHaveLength(0);
    expect(call(rerunStable.calls, "edit")).toHaveLength(1);
    expect(rerunStable.calls.join("\n")).not.toContain("--prerelease");
  });

  it("U19 a verify-macos job after publish, on a macOS runner, downloads demo-server-macos-arm64.zip, checks codesign and asks it for the Todo page", () => {
    const job = workflowJobs()["verify-macos"];
    expect(job).toBeDefined();
    expect([job.needs].flat()).toEqual(["publish"]);
    expect(job["runs-on"]).toMatch(/^macos-/);
    expect(job["timeout-minutes"]).toBeGreaterThan(0);
    expect(job["timeout-minutes"]).toBeLessThanOrEqual(15);
    expect(job.permissions).toEqual({ contents: "read" });
    expect(job.env?.TAG).toBe("${{ needs.publish.outputs.tag }}");

    const run = job.steps.map((s) => s.run ?? "").join("\n");
    expect(run).toContain("mktemp -d");
    expect(run).toMatch(/gh release download "\$TAG" -p demo-server-macos-arm64\.zip/);
    expect(run).toContain("unzip");
    expect(run).toMatch(/codesign --verify --verbose\b.*demo-server/);
    expect(run).toContain("PORT=8081");
    expect(run).toContain("x-api-key: demo-key");
    expect(run).toContain("http://localhost:8081/api/v1/app/todo/page/home");
    expect(run).toContain("Nothing to do yet");
    expect(run).toContain("::error::");
    const download = job.steps.find((s) => s.run?.includes("gh release download"));
    expect(download?.env?.GH_TOKEN).toBe("${{ github.token }}");
    expect(download?.env?.GH_REPO).toBe("${{ github.repository }}");
  });
});
