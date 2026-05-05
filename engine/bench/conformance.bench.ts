#!/usr/bin/env bun
/**
 * JSON tree encoder benchmark.
 *
 * Runs every fixture in schema/fixtures/render/ through encodeJsonTree()
 * and reports ns/op per fixture. Two variants are measured:
 *
 *   EncodeOnly  — pre-parsed tree, measures only the render step.
 *   Encode      — re-parses the fixture JSON inside the loop, measures the
 *                 full request path (JSON decode + render) that a real
 *                 consumer handling wire-format input would take.
 *
 * Use this as a regression tracker for the encoder: record numbers before
 * a non-trivial refactor of value-resolver.ts, json-tree-encoder.ts, or the
 * Value / Transform types, and compare after. Any sudden regression almost
 * always points to an unintended allocation on the hot path.
 *
 * Usage:
 *   bun run engine/bench/conformance.bench.ts
 */

import { readdirSync, readFileSync } from "fs";
import { join } from "path";
import { encodeJsonTree, type JsonTreeNode } from "../src/core/json-tree-encoder";
import type { ValueResolverContext } from "../src/core/value-resolver";

interface Fixture {
  name: string;
  input: JsonTreeNode;
  context: ValueResolverContext;
}

const FIXTURES_DIR = join(import.meta.dir, "..", "..", "schema", "fixtures", "render");
const ITERATIONS = 200_000;
const WARMUP = 5_000;

const files = readdirSync(FIXTURES_DIR)
  .filter((f) => f.endsWith(".json"))
  .sort();

console.log(`bench: ${files.length} fixtures, ${ITERATIONS} iter each`);
console.log(`pkg: engine/src/core/json-tree-encoder`);

function measure(label: string, run: () => void): number {
  for (let i = 0; i < WARMUP; i++) run();
  const start = performance.now();
  for (let i = 0; i < ITERATIONS; i++) run();
  const nsPerOp = ((performance.now() - start) * 1e6) / ITERATIONS;
  console.log(`${label.padEnd(50)}\t${ITERATIONS}\t${nsPerOp.toFixed(0)} ns/op`);
  return nsPerOp;
}

console.log("\n── EncodeOnly (pre-parsed tree) ──");
for (const file of files) {
  const raw = readFileSync(join(FIXTURES_DIR, file), "utf8");
  const fx: Fixture = JSON.parse(raw);
  measure(`EncodeOnly/${file.replace(/\.json$/, "")}`, () => {
    encodeJsonTree(fx.input, fx.context);
  });
}

console.log("\n── Encode+Parse (re-parse per iter) ──");
for (const file of files) {
  const raw = readFileSync(join(FIXTURES_DIR, file), "utf8");
  const fx: Fixture = JSON.parse(raw);
  const inputJson = JSON.stringify(fx.input);
  measure(`Encode/${file.replace(/\.json$/, "")}`, () => {
    const tree = JSON.parse(inputJson) as JsonTreeNode;
    encodeJsonTree(tree, fx.context);
  });
}
