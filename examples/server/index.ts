import { ConsoleMonitor, Engine } from "../../engine/src/core";
import { counterApp } from "./counter";
import { basicActionsApp } from "./basic-actions";
import { serverActionsApp } from "./server-actions";
import { ecommerceApp } from "./ecommerce";
import { staticFlowsApp } from "./static-flows";
import { animationsApp } from "./animations";
import { customApp } from "./custom";
import { capabilityDemoApp } from "./capability-demo";
import { nativeWidgetsApp } from "./native-widgets";
import { todoApp } from "./todo";
import { recoveryMiddleware } from "../../engine/src/middlewares/recovery";
import { loggingMiddleware } from "../../engine/src/middlewares/logging";
import { corsMiddleware } from "../../engine/src/middlewares/cors";
import { authMiddleware } from "../../engine/src/middlewares/auth";
import { rateLimitMiddleware } from "../../engine/src/middlewares/rate-limit";
// Imported, not read from disk, so `bun build --compile` embeds the version.
import enginePackage from "../../engine/package.json";

// ── Register middleware on each app ──────────────────────────

const apps = [counterApp, basicActionsApp, serverActionsApp, ecommerceApp, staticFlowsApp, animationsApp, customApp, capabilityDemoApp, nativeWidgetsApp, todoApp];

for (const app of apps) {
  app
    .registerMiddleware(recoveryMiddleware())
    .registerMiddleware(loggingMiddleware())
    .registerMiddleware(corsMiddleware({ origins: ["*"] }))
    .registerMiddleware(authMiddleware({
      apiKeys: ["demo-key"],
      exclude: ["/config"],
    }))
    .registerMiddleware(rateLimitMiddleware({ maxPerSecond: 100 }));
}

// ── Start engine ─────────────────────────────────────────────

const engine = new Engine();
for (const app of apps) engine.registerApp(app);
engine.registerMonitor(new ConsoleMonitor());

// Epic 25b slice 2: configure a fallback policy so the /capability-demo/negotiation
// page can demonstrate the live filter. Clients missing the `widget.Divider`
// capability get a warn banner prepended to that page's tree; everything
// else defaults to 'graceful' (silent strip of unsupported features).
//
// Self-hosters configure this once at engine bootstrap. Cloud slice 3 will
// expose the same knobs via dashboard UI backed by Postgres — the internal
// FallbackPolicyResolver interface stays the same either way.
//
// For trying the policies on a device: ORCA_FALLBACK_POLICY=warn|require
// changes the default, and ORCA_MIN_SDK_VERSION=99.0.0 makes every page
// answer 426 with the "Update required" page.
const fallbackDefault = process.env.ORCA_FALLBACK_POLICY ?? "graceful";
if (!["graceful", "warn", "require"].includes(fallbackDefault)) {
  throw new Error(`ORCA_FALLBACK_POLICY must be graceful, warn or require, not "${fallbackDefault}"`);
}
engine.setFallbackPolicy({
  default: fallbackDefault as "graceful" | "warn" | "require",
  features: {
    "widget.Divider": "warn",
  },
});
if (process.env.ORCA_MIN_SDK_VERSION) {
  engine.setMinSdkVersion({ appDefault: process.env.ORCA_MIN_SDK_VERSION });
}

// Stop on SIGINT and SIGTERM and exit 0. The compiled binary runs as PID 1 in
// the distroless image, where a signal without a handler is ignored.
function shutdown(): void {
  engine.stop();
  process.exit(0);
}
process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);

const server = await engine.start();

console.log(`Orca demo server ${enginePackage.version} on http://localhost:${server.port}`);
console.log("  API Key: demo-key (pass via x-api-key header)");
console.log("  - counter:        /api/v1/app/counter/page/home");
console.log("  - basic-actions:  /api/v1/app/basic-actions/page/home");
console.log("  - server-actions: /api/v1/app/server-actions/page/shop");
console.log("  - ecommerce:      /api/v1/app/ecommerce/config");
console.log("  - static-flows:   /api/v1/app/static-flows/version");
console.log("  - animations:     /api/v1/app/animations/page/auto-play");
console.log("  - animations:     /api/v1/app/animations/page/controlled");
console.log("  - custom:         /api/v1/app/custom/page/home");
console.log("  - capability:     /api/v1/app/capability-demo/page/home");
console.log("  - capability:     /api/v1/app/capability-demo/page/upgrade");
console.log("  - capability:     /api/v1/app/capability-demo/page/blocked");
console.log("  - capability:     /api/v1/app/capability-demo/page/negotiation  (Epic 25b slice 2 live filter)");
console.log("  - capability:     /api/v1/app/capability-demo/page/degrade  (a Checkbox iOS lacks)");
console.log("  - native-widgets: /api/v1/app/native-widgets/page/home");
console.log("  - todo:           /api/v1/app/todo/page/home");
