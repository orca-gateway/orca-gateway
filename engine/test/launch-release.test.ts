// Release-side checks for the launch: the root CHANGELOG.md points at each
// package's own changelog, and scripts/release.sh refuses an engine version
// whose "## X.Y.Z" section is missing from engine/CHANGELOG.md.
//
// U13 and U14 run release.sh in a scratch git repo under a fresh temp dir,
// with a local bare origin and a stub `npm` on PATH: no network, no real
// registry, and nothing in this repository is touched. P-release releases the
// voice recorder's iOS and Android packages the same way, its mirror a local
// bare repository and `swift`, `./gradlew` and `java` stubs.

import { afterAll, describe, expect, test } from "bun:test";
import {
  copyFileSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  realpathSync,
  rmSync,
  writeFileSync,
} from "fs";
import { tmpdir } from "os";
import { dirname, join, resolve } from "path";

const REPO_ROOT = resolve(import.meta.dir, "..", "..");
const RELEASE_SH = join(REPO_ROOT, "scripts", "release.sh");

// ── U12: root CHANGELOG.md links each package's own ─────────

describe("root CHANGELOG.md", () => {
  test("U12 the root CHANGELOG.md drops the 0.1.0 body and links each package's CHANGELOG.md, all of which exist", () => {
    const text = readFileSync(join(REPO_ROOT, "CHANGELOG.md"), "utf8");
    expect(text).not.toContain("[0.1.0] - Unreleased");

    const links = [...text.matchAll(/\]\(([^)\s]+)\)/g)].map((m) => m[1]);
    const expected = [
      "engine/CHANGELOG.md",
      "sdk/CHANGELOG.md",
      "cli/CHANGELOG.md",
      "plugins/orca_google_map/CHANGELOG.md",
      "plugins/orca_push_notification/CHANGELOG.md",
      "plugins/orca_video_player/CHANGELOG.md",
      "plugins/orca_voice_recorder/CHANGELOG.md",
    ];
    for (const path of expected) expect(links).toContain(path);

    const local = links.filter((l) => !/^[a-z]+:/i.test(l) && !l.startsWith("#"));
    for (const path of local) {
      expect({ path, exists: existsSync(join(REPO_ROOT, path)) }).toEqual({ path, exists: true });
    }
  });
});

// ── U13 / U14: the notes check in scripts/release.sh ────────

const TEMP_ROOTS: string[] = [];

afterAll(() => {
  for (const dir of TEMP_ROOTS) {
    // Only the exact dirs mkdtemp returned, under the system temp dir.
    if (dir && dir.startsWith(tmpdir()) && dir.includes("orca-release-test-")) {
      rmSync(dir, { recursive: true, force: true });
    }
  }
});

// The twelve manifests PACKAGES in release.sh reads, engine at 0.3.4.
const MANIFESTS: Record<string, string> = {
  "engine/package.json": JSON.stringify(
    {
      name: "@orca-gateway/engine",
      version: "0.3.4",
      publishConfig: { registry: "https://registry.npmjs.org/", access: "public" },
    },
    null,
    2,
  ) + "\n",
  "sdk/pubspec.yaml": "name: orca_gateway\nversion: 0.3.3\n",
  "cli/pubspec.yaml": "name: orca_gateway_cli\nversion: 0.2.0\n",
  "devtools/pubspec.yaml": "name: orca_devtools\nversion: 0.2.1+1\n",
  "plugins/orca_google_map/pubspec.yaml": "name: orca_google_map\nversion: 0.2.1\n",
  "plugins/orca_push_notification/pubspec.yaml": "name: orca_push_notification\nversion: 0.2.1\n",
  "plugins/orca_video_player/pubspec.yaml": "name: orca_video_player\nversion: 0.2.1\n",
  "plugins/orca_voice_recorder/pubspec.yaml": "name: orca_voice_recorder\nversion: 0.2.1\n",
  "sdk-swift/VERSION": "0.1.0-alpha.1\n",
  "sdk-kotlin/VERSION": "0.1.0-alpha.1\n",
  "plugins/orca_voice_recorder/ios/VERSION": "0.1.0-alpha.1\n",
  "plugins/orca_voice_recorder/android/VERSION": "0.1.0-alpha.1\n",
};

// What the logins check calls: `npm config get @orca-gateway:registry`,
// `npm whoami --registry ...`, `npm view ... maintainers`. Anything else
// (pack, publish) fails loudly.
const NPM_STUB = `#!/bin/sh
echo "npm $*" >> "$NPM_STUB_LOG"
case "$1" in
  whoami) echo tester ;;
  config) echo undefined ;;
  view) exit 1 ;;
  *) echo "stub npm: unexpected call: $*" >&2; exit 1 ;;
esac
`;

interface Scratch {
  root: string;
  work: string;
  env: Record<string, string>;
}

function git(cwd: string, env: Record<string, string>, ...args: string[]): string {
  const r = Bun.spawnSync(["git", ...args], { cwd, env, stdout: "pipe", stderr: "pipe" });
  if (r.exitCode !== 0) {
    throw new Error(`git ${args.join(" ")} failed: ${r.stderr.toString()}`);
  }
  return r.stdout.toString();
}

function makeScratchRepo(changelog: string): Scratch {
  const root = mkdtempSync(join(tmpdir(), "orca-release-test-"));
  TEMP_ROOTS.push(root);
  const work = join(root, "work");
  const origin = join(root, "origin.git");
  const bin = join(root, "bin");
  mkdirSync(work);
  mkdirSync(bin);

  writeFileSync(join(bin, "npm"), NPM_STUB, { mode: 0o755 });

  const env: Record<string, string> = {
    PATH: `${bin}:${process.env.PATH ?? ""}`,
    HOME: root,
    NPM_STUB_LOG: join(root, "npm-calls.log"),
    // Keep the user's git config (signing, hooks) out of the scratch repo.
    GIT_CONFIG_GLOBAL: "/dev/null",
    GIT_CONFIG_NOSYSTEM: "1",
    GIT_AUTHOR_NAME: "Release Test",
    GIT_AUTHOR_EMAIL: "release-test@example.invalid",
    GIT_COMMITTER_NAME: "Release Test",
    GIT_COMMITTER_EMAIL: "release-test@example.invalid",
    GIT_TERMINAL_PROMPT: "0",
  };

  mkdirSync(join(work, "scripts"));
  copyFileSync(RELEASE_SH, join(work, "scripts", "release.sh"));
  for (const [path, body] of Object.entries(MANIFESTS)) {
    mkdirSync(dirname(join(work, path)), { recursive: true });
    writeFileSync(join(work, path), body);
  }
  writeFileSync(join(work, "engine", "CHANGELOG.md"), changelog);

  git(root, env, "init", "--bare", "-b", "main", origin);
  git(work, env, "init", "-b", "main");
  git(work, env, "add", "-A");
  git(work, env, "commit", "-m", "scratch");
  git(work, env, "remote", "add", "origin", origin);
  git(work, env, "push", "--quiet", "origin", "main");

  return { root, work, env };
}

function runRelease(s: Scratch, answers: string) {
  const r = Bun.spawnSync(["bash", "scripts/release.sh"], {
    cwd: s.work,
    env: s.env,
    stdin: new TextEncoder().encode(answers),
    stdout: "pipe",
    stderr: "pipe",
  });
  // Colours wrap words like "ok"; the reader sees them without the codes.
  const out = (r.stdout.toString() + r.stderr.toString()).replace(/\x1b\[[0-9;]*m/g, "");
  return { exitCode: r.exitCode, out };
}

function expectNothingChanged(s: Scratch, head: string) {
  expect(git(s.work, s.env, "status", "--porcelain")).toBe("");
  expect(git(s.work, s.env, "rev-parse", "HEAD")).toBe(head);
  expect(git(s.work, s.env, "tag", "-l")).toBe("");
  for (const [path, body] of Object.entries(MANIFESTS)) {
    expect({ path, body: readFileSync(join(s.work, path), "utf8") }).toEqual({ path, body });
  }
}

const OLD_SECTIONS = "# Changelog\n\n## 0.3.50 - x\n\n- later\n\n## 0.3.4 - x\n\n- earlier\n";

describe("release.sh notes check", () => {
  test("U13 an engine bump with no \"## 0.3.5\" section stops before any change", () => {
    const s = makeScratchRepo(OLD_SECTIONS);
    const head = git(s.work, s.env, "rev-parse", "HEAD");

    const { exitCode, out } = runRelease(s, "1\n\n");

    expect(out).toContain('stop: engine/CHANGELOG.md has no "## 0.3.5"');
    expect(out).toContain("Nothing was changed.");
    expect(out).not.toContain("ok notes");
    expect(out).not.toContain("Summary:");
    expect(exitCode).not.toBe(0);
    expectNothingChanged(s, head);
    expect(git(s.work, s.env, "ls-remote", "--tags", "origin")).toBe("");
  }, 30_000);

  test("U14 with the \"## 0.3.5\" section committed the check passes and the summary names the GitHub release", () => {
    const s = makeScratchRepo(OLD_SECTIONS);
    writeFileSync(
      join(s.work, "engine", "CHANGELOG.md"),
      "# Changelog\n\n## 0.3.5 - 2026-11-20\n\n- new\n\n## 0.3.50 - x\n\n- later\n\n## 0.3.4 - x\n\n- earlier\n",
    );
    git(s.work, s.env, "commit", "-am", "notes for 0.3.5");
    git(s.work, s.env, "push", "--quiet", "origin", "main");
    const head = git(s.work, s.env, "rev-parse", "HEAD");

    const { exitCode, out } = runRelease(s, "1\n\nn\n");

    expect(out).toContain('ok notes, engine/CHANGELOG.md "## 0.3.5"');
    expect(out).not.toContain("stop:");
    const summary = out.slice(out.indexOf("Summary:"));
    expect(out.indexOf("Summary:")).toBeGreaterThan(out.indexOf("ok notes"));
    expect(summary).toContain("0.3.4");
    expect(summary).toContain("-> 0.3.5");
    expect(summary).toContain("then a GitHub release: notes, demo image, 3 downloads");
    expect(out).toContain("aborted");
    expect(exitCode).not.toBe(0);
    expectNothingChanged(s, head);
  }, 30_000);
});

// ── P-release: the voice recorder's iOS and Android rows ────

// Each stub logs its call to $STUB_LOG and succeeds; `bun` fails, since a
// plugin package has no capability vector to regenerate.
const LOGGING_STUB = (name: string) => `#!/bin/sh
echo "${name} $*" >> "$STUB_LOG"
`;
const GRADLEW_STUB = `#!/bin/sh
echo "gradlew $PWD $*" >> "$STUB_LOG"
`;
const JAVA_STUB = `#!/bin/sh
echo 'openjdk version "17.0.12" 2024-07-16' >&2
`;
const BUN_STUB = `#!/bin/sh
echo "bun $*" >> "$STUB_LOG"
exit 1
`;

describe("release.sh native plugin rows", () => {
  test("P-release the voice recorder's ios and android rows are 11 and 12 with their VERSIONs, and release through their own mirror, validation, artifact and workflows", () => {
    const s = makeScratchRepo(OLD_SECTIONS);
    const android = join(s.work, "plugins", "orca_voice_recorder", "android");
    writeFileSync(join(android, "gradlew"), GRADLEW_STUB, { mode: 0o755 });
    git(s.work, s.env, "add", "-A");
    git(s.work, s.env, "commit", "-m", "the android package's wrapper");
    git(s.work, s.env, "push", "--quiet", "origin", "main");

    const bin = join(s.root, "bin");
    writeFileSync(join(bin, "swift"), LOGGING_STUB("swift"), { mode: 0o755 });
    writeFileSync(join(bin, "bun"), BUN_STUB, { mode: 0o755 });
    const jdk = join(s.root, "jdk");
    mkdirSync(join(jdk, "bin"), { recursive: true });
    writeFileSync(join(jdk, "bin", "java"), JAVA_STUB, { mode: 0o755 });
    const androidSdk = join(s.root, "android-sdk");
    mkdirSync(androidSdk);
    const voiceMirror = join(s.root, "voice-mirror.git");
    git(s.root, s.env, "init", "--bare", "-b", "main", voiceMirror);
    const log = join(s.root, "stub-calls.log");
    const env = {
      ...s.env,
      STUB_LOG: log,
      JAVA_HOME: jdk,
      ANDROID_HOME: androidSdk,
      ORCA_VOICE_RECORDER_SWIFT_MIRROR_URL: voiceMirror,
      // sdk-swift's override, unreachable: the plugin must not use it.
      SWIFT_MIRROR_URL: join(s.root, "no-sdk-swift-mirror.git"),
    };

    // 11 next, 12 kept (the default for an untagged pre-release), proceed.
    const { exitCode, out } = runRelease({ ...s, env }, "11,12\nn\n\ny\n");

    expect(out).toMatch(/^ +10\) sdk-kotlin +0\.1\.0-alpha\.1 +\(maven\)$/m);
    expect(out).toMatch(/^ +11\) orca_voice_recorder-ios +0\.1\.0-alpha\.1 +\(mirror\)$/m);
    expect(out).toMatch(/^ +12\) orca_voice_recorder-android +0\.1\.0-alpha\.1 +\(maven\)$/m);
    expect(out).not.toMatch(/^ +13\)/m);

    expect(out).toContain(`ok mirror ${voiceMirror} `);
    expect(out).not.toContain("no-sdk-swift-mirror");
    expect(out).toContain(`ok JDK 17.0.12, Android SDK ${androidSdk} `);
    expect(out).toContain(
      "[orca_voice_recorder-ios] 0.1.0-alpha.1 -> [k]eep 0.1.0-alpha.1 / [n]ext 0.1.0-alpha.2 / [r]elease 0.1.0",
    );
    expect(out).not.toContain("Regenerating");

    const calls = readFileSync(log, "utf8").trimEnd().split("\n");
    expect(calls).toEqual([
      "swift build --package-path plugins/orca_voice_recorder/ios",
      "swift test --package-path plugins/orca_voice_recorder/ios",
      // The shell's $PWD: on macOS the temp dir's /var is /private/var.
      `gradlew ${realpathSync(android)} build publishAllPublicationsToStagingRepository --console=plain`,
    ]);

    const ios = out.indexOf(
      `[orca_voice_recorder-ios] tag push triggers .github/workflows/sdk-swift-mirror.yml (split, push to ${voiceMirror}, tag 0.1.0-alpha.2 there)`,
    );
    const kotlin = out.indexOf(
      "[orca_voice_recorder-android] tag push triggers .github/workflows/sdk-kotlin-publish.yml (signs and releases com.orcagateway:orca-voice-recorder 0.1.0-alpha.1 to Maven Central)",
    );
    expect(ios).toBeGreaterThan(-1);
    expect(kotlin).toBeGreaterThan(ios);
    expect(out).toContain("All done.");
    expect(exitCode).toBe(0);

    expect(readFileSync(join(s.work, "plugins/orca_voice_recorder/ios/VERSION"), "utf8")).toBe("0.1.0-alpha.2\n");
    expect(readFileSync(join(android, "VERSION"), "utf8")).toBe("0.1.0-alpha.1\n");
    expect(git(s.work, s.env, "log", "-1", "--format=%B").trimEnd()).toBe(
      "chore(release): version bump\n\n" +
        "- orca_voice_recorder-ios 0.1.0-alpha.1 -> 0.1.0-alpha.2\n" +
        "- orca_voice_recorder-android 0.1.0-alpha.1 -> 0.1.0-alpha.1",
    );
    expect(git(s.work, s.env, "diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD")).toBe(
      "plugins/orca_voice_recorder/ios/VERSION\n",
    );
    const tags = git(s.work, s.env, "ls-remote", "--tags", "origin");
    expect(tags).toContain("refs/tags/orca_voice_recorder-ios-v0.1.0-alpha.2");
    expect(tags).toContain("refs/tags/orca_voice_recorder-android-v0.1.0-alpha.1");
    expect(git(s.work, s.env, "ls-remote", "origin", "main").split("\t")[0]).toBe(
      git(s.work, s.env, "rev-parse", "HEAD").trim(),
    );
  }, 30_000);
});
