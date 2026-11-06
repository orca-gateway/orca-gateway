// Contract drift guard (Epic 23b, task 23b.1).
//
// `open-source/schema/action.schema.json` is the public wire contract for
// actions; `engine/src/types/action.ts` is what the engine actually emits.
// Every discriminator literal on one side must exist on the other, and
// every schema definition that pins a `type` const must be reachable from
// the top-level `oneOf`. Downstream SDKs (Flutter, Swift, Kotlin) build
// their executors from the schema, so a kind that exists only in the TS
// union is invisible to them until this test fails.
import { describe, expect, test } from "bun:test";
import { readFileSync } from "fs";
import { join } from "path";

const ENGINE_ROOT = join(import.meta.dir, "..");
const ACTION_TS = join(ENGINE_ROOT, "src/types/action.ts");
const ACTION_SCHEMA = join(ENGINE_ROOT, "../schema/action.schema.json");

/** Discriminator literals declared as `type: "<kind>";` in action.ts. */
function tsActionKinds(): string[] {
  const src = readFileSync(ACTION_TS, "utf8");
  const kinds = new Set<string>();
  const re = /^\s*type:\s*"([A-Za-z][A-Za-z0-9]*)";/gm;
  let m: RegExpExecArray | null;
  while ((m = re.exec(src)) !== null) kinds.add(m[1]);
  return [...kinds].sort();
}

interface SchemaDef {
  properties?: { type?: { const?: string } };
}
interface ActionSchema {
  oneOf: { $ref: string }[];
  definitions: Record<string, SchemaDef>;
}

function loadSchema(): ActionSchema {
  return JSON.parse(readFileSync(ACTION_SCHEMA, "utf8")) as ActionSchema;
}

/** `type` consts pinned by schema definitions, keyed by definition name. */
function schemaActionKinds(schema: ActionSchema): Map<string, string> {
  const out = new Map<string, string>();
  for (const [name, def] of Object.entries(schema.definitions)) {
    const c = def.properties?.type?.const;
    if (typeof c === "string") out.set(name, c);
  }
  return out;
}

describe("action.schema.json ↔ action.ts", () => {
  test("every TS action kind has a schema definition, and vice versa", () => {
    const ts = tsActionKinds();
    const schema = [...schemaActionKinds(loadSchema()).values()].sort();
    expect(schema).toEqual(ts);
  });

  test("every kind-bearing definition is reachable from the top-level oneOf", () => {
    const schema = loadSchema();
    const referenced = new Set(schema.oneOf.map((o) => o.$ref.replace("#/definitions/", "")));
    const missing = [...schemaActionKinds(schema).keys()].filter((n) => !referenced.has(n));
    expect(missing).toEqual([]);
  });
});
