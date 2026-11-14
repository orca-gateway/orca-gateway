// launch-builds, task T2: step 1 of the example READMEs starts the demo server
// by Docker, a download from the newest Engine release, or Bun from source, and
// the iOS and Android READMEs list the Todo app among the other example apps.
import { describe, expect, test } from "bun:test";
import { readFileSync } from "fs";
import { join } from "path";

const EXAMPLES = join(import.meta.dir, "../../examples");
const RELEASES_LINK = "](https://github.com/orca-gateway/orca-gateway/releases?q=engine-v)";

function readme(dir: string): string {
  return readFileSync(join(EXAMPLES, dir, "README.md"), "utf8");
}

describe("launch READMEs", () => {
  for (const dir of ["server", "app", "app-ios", "app-android"]) {
    test(`U11 examples/${dir}/README.md: step 1 offers Docker, the download, then Bun, and says when it is ready`, () => {
      const text = readme(dir);

      const docker = text.search(/docker run --rm -p 8080:8080(?:\s+\\\n\s*|\s+)ghcr\.io\/orca-gateway\/demo-server:latest/);
      expect(docker).toBeGreaterThanOrEqual(0);

      const download = text.indexOf(RELEASES_LINK);
      expect(download).toBeGreaterThan(docker);
      expect(text).toContain("chmod +x demo-server-linux-x64");
      expect(text).toContain("demo-server-macos-arm64.zip");
      expect(text).toContain("Open Anyway");
      expect(text).toContain("Run anyway");

      const bun = text.indexOf("task example:dev:server");
      expect(bun).toBeGreaterThan(download);

      const ready = text.search(/Ready when it prints [`"]Orca demo server [^`"\n]+ on http:\/\/localhost:8080[`"]/);
      expect(ready).toBeGreaterThan(bun);
    });
  }

  for (const dir of ["app-ios", "app-android"]) {
    test(`U11 examples/${dir}/README.md: "Other example apps" has a Todo row naming todo and home`, () => {
      const section = readme(dir).split("## Other example apps")[1]?.split("\n## ")[0] ?? "";
      const row = section.split("\n").find((line) => /^\| Todo \|/.test(line));
      expect(row).toBeDefined();
      expect(row).toContain("| `todo` |");
      expect(row).toContain("`home`");
    });
  }
});
