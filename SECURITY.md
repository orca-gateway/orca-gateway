# Security Policy

## Supported Versions

| Version | Supported |
| ------- | --------- |
| 0.1.x   | Yes       |

## Reporting a Vulnerability

**Please do NOT open public GitHub issues for security vulnerabilities.**

Instead, report vulnerabilities by emailing **admin@orcagateway.com** with:

1. A description of the vulnerability
2. Steps to reproduce (if applicable)
3. Affected component (engine, SDK, plugins, CLI, devtools)
4. Any potential impact assessment

## What to Expect

- **Acknowledgment** within 48 hours of your report
- **Status update** within 7 days with our assessment and planned timeline
- **Fix or mitigation** as soon as practical, prioritized by severity

## Scope

The following components are in scope:

- `engine/` — SDUI engine and HTTP API
- `sdk/` — Flutter SDK
- `plugins/` — Official plugin packages
- `cli/` — CLI tooling
- `schema/` — Wire format schemas

Out of scope: `docs-site/`, `examples/`, and `devtools/` (development tooling).

## Server Action Trust Model (important for app authors)

Server actions (`POST /api/v1/app/:appId/action`) are invoked directly by
clients, and the engine echoes the request body into the action's context.
This means:

- **`pageState`, `appState`, and `actionParams` are fully attacker-controlled.**
  A malicious client can call any action id with arbitrary values for all
  three — the schema only validates types, not trustworthiness.
- **Actions are not bound to the page that rendered them.** Knowing (or
  guessing) an action id is enough to invoke it; "the button is only on
  page X" is not an access control.
- **Never make pricing, quantity, or permission decisions from client state.**
  Re-derive anything sensitive server-side (database lookup, verified
  session) using `requestInfo.authToken` / `requestInfo.userId` — and verify
  that token yourself; the engine does not.

Use the `authorize` hook on `ServerActionDefinition.create({ ... })` to
reject unauthorized calls with HTTP 403 before `execute` runs, and deploy
the auth middleware so unauthenticated clients never reach the action
endpoint at all.

## Deployment Hardening Checklist

- Set `trustProxy: true` in `EngineConfig` **only** when the engine runs
  behind a reverse proxy you control; otherwise the client IP (which keys
  rate-limit buckets) comes from the socket peer address.
- Keep `enableDebugEndpoint` off in production — it gates both the
  `/api/v1/debug/last-requests` endpoint and the `X-Orca-Timing` response
  header.
- Serve the API over HTTPS; the SDK sends the API key as a bearer header.

## Coordinated Disclosure

We ask that you give us a reasonable window (typically 90 days) to address the vulnerability before public disclosure. We will credit reporters in the fix advisory unless you prefer to remain anonymous.

## Contact

Email: admin@orcagateway.com
