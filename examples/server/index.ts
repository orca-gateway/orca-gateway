import { ConsoleMonitor, Engine } from "../../engine/src/core";
import { counterApp } from "./counter";
import { basicActionsApp } from "./basic-actions";
import { serverActionsApp } from "./server-actions";
import { ecommerceApp } from "./ecommerce";
import { staticFlowsApp } from "./static-flows";
import { animationsApp } from "./animations";
import { customApp } from "./custom";
import { capabilityDemoApp } from "./capability-demo";
import { recoveryMiddleware } from "../../engine/src/middlewares/recovery";
import { loggingMiddleware } from "../../engine/src/middlewares/logging";
import { corsMiddleware } from "../../engine/src/middlewares/cors";
import { authMiddleware } from "../../engine/src/middlewares/auth";
import { rateLimitMiddleware } from "../../engine/src/middlewares/rate-limit";

// ── Register middleware on each app ──────────────────────────

const apps = [counterApp, basicActionsApp, serverActionsApp, ecommerceApp, staticFlowsApp, animationsApp, customApp, capabilityDemoApp];

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
engine.setFallbackPolicy({
  default: "graceful",
  features: {
    "widget.Divider": "warn",
  },
});

engine.start();

console.log("Orca Gateway Examples running on http://localhost:8080");
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
