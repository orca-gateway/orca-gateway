// DevTools fixtures ↔ devtools-events.schema.json (native-parity-s19, C19.7).
//
// schema/fixtures/devtools/ holds the events every SDK builds byte-equal
// (Flutter, Swift, Kotlin) and DevTools parses. This test proves each of
// them also satisfies the published schema, so a fixture cannot drift from
// the contract it pins. New fixtures are picked up from the folder.
//
// No JSON-Schema library is in the repo, so the validator below covers
// exactly the keywords schema/devtools-events.schema.json uses:
//   assertions:  type (string or array), required, properties,
//                additionalProperties (schema form), items (schema form),
//                enum, const
//   applicators: allOf, if/then, $ref (JSON pointer into the same file)
//   annotations: $schema, $id, title, description, definitions
// Any other keyword throws, both while validating and in a walk of the whole
// schema, so a schema edit that uses one fails here instead of passing
// silently (even in a branch no fixture reaches yet).
import { describe, expect, test } from "bun:test";
import { readdirSync, readFileSync } from "fs";
import { join } from "path";

const SCHEMA_ROOT = join(import.meta.dir, "../../schema");
const SCHEMA_FILE = join(SCHEMA_ROOT, "devtools-events.schema.json");
const FIXTURE_DIR = join(SCHEMA_ROOT, "fixtures/devtools");

type Json = null | boolean | number | string | Json[] | { [key: string]: Json };
type Schema = { [keyword: string]: Json };

const KEYWORDS = new Set([
  "type", "required", "properties", "additionalProperties", "items", "enum", "const",
  "allOf", "if", "then", "$ref",
  "$schema", "$id", "title", "description", "definitions",
]);

function assertKnownKeywords(schema: Schema, at: string): void {
  if (typeof schema !== "object" || schema === null || Array.isArray(schema)) {
    throw new Error(`unsupported schema form ${JSON.stringify(schema)} at ${at}`);
  }
  for (const keyword of Object.keys(schema)) {
    if (!KEYWORDS.has(keyword)) throw new Error(`unsupported schema keyword "${keyword}" at ${at}`);
  }
}

/** Every subschema of `schema`, depth first, with its location (static walk, no instance). */
function* subschemas(schema: Schema, at = "#"): Generator<[Schema, string]> {
  yield [schema, at];
  for (const map of ["properties", "definitions"] as const) {
    for (const [name, sub] of Object.entries((schema[map] ?? {}) as Record<string, Schema>)) {
      yield* subschemas(sub, `${at}/${map}/${name}`);
    }
  }
  for (const single of ["additionalProperties", "items", "if", "then"] as const) {
    if (schema[single] !== undefined) yield* subschemas(schema[single] as Schema, `${at}/${single}`);
  }
  for (const [i, sub] of ((schema.allOf ?? []) as Schema[]).entries()) yield* subschemas(sub, `${at}/allOf/${i}`);
}

function isObject(value: Json): value is { [key: string]: Json } {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function typeName(value: Json): string {
  if (value === null) return "null";
  if (Array.isArray(value)) return "array";
  return typeof value;
}

function hasType(value: Json, type: string): boolean {
  switch (type) {
    case "integer":
      return Number.isInteger(value);
    case "number":
    case "string":
    case "boolean":
    case "object":
    case "array":
    case "null":
      return typeName(value) === type;
    default:
      throw new Error(`unsupported type "${type}"`);
  }
}

function child(path: string, key: string | number): string {
  if (typeof key === "number") return `${path}[${key}]`;
  return /^[A-Za-z_$][\w$]*$/.test(key) ? `${path}.${key}` : `${path}[${JSON.stringify(key)}]`;
}

function resolveRef(root: Schema, ref: string): Schema {
  if (!ref.startsWith("#/")) throw new Error(`unsupported $ref "${ref}"`);
  let node: Json = root;
  for (const raw of ref.slice(2).split("/")) {
    const part = raw.replace(/~1/g, "/").replace(/~0/g, "~");
    if (!isObject(node) || !(part in node)) throw new Error(`unresolved $ref "${ref}"`);
    node = node[part];
  }
  return node as Schema;
}

/** Errors for `value` against `schema`, each `<path>: <what>`; empty means valid. */
function validate(root: Schema, schema: Schema, value: Json, path = "$"): string[] {
  assertKnownKeywords(schema, path);
  const errors: string[] = [];

  if (typeof schema.$ref === "string") errors.push(...validate(root, resolveRef(root, schema.$ref), value, path));

  if (schema.type !== undefined) {
    const types = (Array.isArray(schema.type) ? schema.type : [schema.type]) as string[];
    if (!types.some((t) => hasType(value, t))) {
      errors.push(`${path}: expected ${types.join(" or ")}, got ${typeName(value)}`);
    }
  }
  if (schema.enum !== undefined && !(schema.enum as Json[]).some((e) => Bun.deepEquals(e, value))) {
    errors.push(`${path}: ${JSON.stringify(value)} is not one of ${JSON.stringify(schema.enum)}`);
  }
  if (schema.const !== undefined && !Bun.deepEquals(schema.const, value)) {
    errors.push(`${path}: ${JSON.stringify(value)} is not ${JSON.stringify(schema.const)}`);
  }

  if (isObject(value)) {
    for (const key of (schema.required ?? []) as string[]) {
      if (!(key in value)) errors.push(`${path}: missing required property ${JSON.stringify(key)}`);
    }
    const properties = (schema.properties ?? {}) as Record<string, Schema>;
    for (const [key, item] of Object.entries(value)) {
      if (key in properties) errors.push(...validate(root, properties[key], item, child(path, key)));
      else if (schema.additionalProperties !== undefined) {
        errors.push(...validate(root, schema.additionalProperties as Schema, item, child(path, key)));
      }
    }
  }
  if (Array.isArray(value) && schema.items !== undefined) {
    value.forEach((item, i) => errors.push(...validate(root, schema.items as Schema, item, child(path, i))));
  }

  for (const sub of (schema.allOf ?? []) as Schema[]) errors.push(...validate(root, sub, value, path));
  if (schema.if !== undefined && validate(root, schema.if as Schema, value, path).length === 0) {
    if (schema.then !== undefined) errors.push(...validate(root, schema.then as Schema, value, path));
  }
  return errors;
}

function loadSchema(): Schema {
  return JSON.parse(readFileSync(SCHEMA_FILE, "utf8")) as Schema;
}

function fixtureFiles(): string[] {
  return readdirSync(FIXTURE_DIR)
    .filter((f) => f.endsWith(".json"))
    .sort();
}

describe("C19.7 devtools fixtures validate against devtools-events.schema.json", () => {
  const schema = loadSchema();
  const files = fixtureFiles();

  test("C19.7 the schema uses only keywords the validator knows", () => {
    for (const [sub, at] of subschemas(schema)) assertKnownKeywords(sub, at);
  });

  test("C19.7 the fixture folder is not empty", () => {
    expect(files.length).toBeGreaterThan(0);
  });

  for (const file of files) {
    test(`C19.7 ${file} validates`, () => {
      const event = JSON.parse(readFileSync(join(FIXTURE_DIR, file), "utf8")) as Json;
      expect(validate(schema, schema, event)).toEqual([]);
    });
  }
});

describe("C19.7 the validator rejects bad events with a readable path", () => {
  const schema = loadSchema();
  const event = (type: string, payload: { [key: string]: Json }): { [key: string]: Json } => ({
    type,
    deviceId: "fixture-device",
    timestamp: 1793980800000,
    payload,
  });
  const action = (): { [key: string]: Json } =>
    event("action", {
      actionType: "setState",
      family: "state",
      pageId: "home",
      data: { type: "setState", key: "count", scope: "page", value: 1 },
      durationMs: 0.75,
      transformTrace: [{ op: "toString", in: "1", out: "1" }],
    });
  const rebuild = (): { [key: string]: Json } =>
    event("widget_rebuild", {
      widgetId: "5",
      widgetType: "Text",
      watches: ["count"],
      propTraces: { data: [{ op: "toString", in: "1", out: "1" }] },
    });
  const network = (): { [key: string]: Json } =>
    event("network", { method: "GET", url: "http://localhost:8080/", statusCode: 200, durationMs: 12.5 });

  test("C19.7 the unmutated bases are valid", () => {
    expect(validate(schema, schema, action())).toEqual([]);
    expect(validate(schema, schema, rebuild())).toEqual([]);
    expect(validate(schema, schema, network())).toEqual([]);
  });

  test("C19.7 a missing required key is rejected", () => {
    const bad = action();
    delete (bad.payload as { [key: string]: Json }).pageId;
    expect(validate(schema, schema, bad)).toEqual(['$.payload: missing required property "pageId"']);
  });

  test('C19.7 an action family "nope" is rejected', () => {
    const bad = action();
    (bad.payload as { [key: string]: Json }).family = "nope";
    expect(validate(schema, schema, bad)).toEqual([
      '$.payload.family: "nope" is not one of ["navigation","state","ui-feedback","data","lifecycle","custom"]',
    ]);
  });

  test("C19.7 a TraceStep whose out is a number is rejected (propTraces and transformTrace)", () => {
    const badRebuild = rebuild();
    ((badRebuild.payload as { [key: string]: Json }).propTraces as { [key: string]: Json[] }).data[0] = {
      op: "toString",
      in: "1",
      out: 1,
    };
    expect(validate(schema, schema, badRebuild)).toEqual([
      "$.payload.propTraces.data[0].out: expected string, got number",
    ]);

    const badAction = action();
    (badAction.payload as { [key: string]: Json }).transformTrace = [{ op: "toString", out: 1 }];
    expect(validate(schema, schema, badAction)).toEqual([
      "$.payload.transformTrace[0].out: expected string, got number",
    ]);
  });

  test("C19.7 a network statusCode as a string is rejected", () => {
    const bad = network();
    (bad.payload as { [key: string]: Json }).statusCode = "200";
    expect(validate(schema, schema, bad)).toEqual(["$.payload.statusCode: expected integer, got string"]);
  });

  test("C19.7 a keyword the validator does not know throws", () => {
    const withPattern: Schema = { type: "string", pattern: "^x" };
    expect(() => validate(withPattern, withPattern, "x")).toThrow('unsupported schema keyword "pattern" at $');
  });
});
