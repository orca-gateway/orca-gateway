import { Engine } from "./core";

export const engine = new Engine();

// Register apps here (see examples/counter.ts for a full example)

export const ready = engine.start();

ready.catch(console.error);
