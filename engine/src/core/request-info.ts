import type { ClientCapabilitiesRef, RequestInfo } from "../types/context";

// ── Extract RequestInfo from HTTP Request ──────────────────

export function extractRequestInfo(
  req: Request,
  routeParams: Record<string, string>,
): RequestInfo {
  const url = new URL(req.url);
  const headers = req.headers;

  // Parse query params
  const queryParams: Record<string, string> = {};
  url.searchParams.forEach((value, key) => {
    queryParams[key] = value;
  });

  // Parse device info from headers (Flutter SDK sends these)
  const platform = parseHeader(headers, "x-orca-platform", "iOS") as "iOS" | "Android";
  const osVersion = parseHeader(headers, "x-orca-os-version", "");
  const deviceModel = parseHeader(headers, "x-orca-device-model", "");
  const appVersion = parseHeader(headers, "x-orca-app-version", "");
  const buildNumber = parseHeader(headers, "x-orca-build-number", "");

  // Screen
  const screenWidth = parseFloat(parseHeader(headers, "x-orca-screen-width", "0"));
  const screenHeight = parseFloat(parseHeader(headers, "x-orca-screen-height", "0"));
  const pixelDensity = parseFloat(parseHeader(headers, "x-orca-pixel-density", "1"));
  const safeTop = parseFloat(parseHeader(headers, "x-orca-safe-top", "0"));
  const safeBottom = parseFloat(parseHeader(headers, "x-orca-safe-bottom", "0"));
  const safeLeft = parseFloat(parseHeader(headers, "x-orca-safe-left", "0"));
  const safeRight = parseFloat(parseHeader(headers, "x-orca-safe-right", "0"));

  // Localization
  const locale = parseHeader(headers, "x-orca-locale", "en_US");
  const timezone = parseHeader(headers, "x-orca-timezone", "UTC");
  const language = parseHeader(headers, "accept-language", "en").split(",")[0].trim();

  // Network
  const networkType = parseHeader(headers, "x-orca-network", "wifi") as "wifi" | "cellular" | "offline";

  // Auth
  const authHeader = headers.get("authorization");
  const authToken = authHeader?.startsWith("Bearer ") ? authHeader.slice(7) : undefined;
  const userId = parseHeader(headers, "x-orca-user-id", undefined);

  // Capability negotiation (Epic 25b slice 2). The engine will later hydrate
  // `vector` by looking `hash` up in its in-memory vector cache. Headers are
  // optional: a client that omits them is treated as unversioned and sees
  // no filtering, same as pre-25b behavior.
  const sdkVersion = parseHeader(headers, "x-orca-sdk-version", undefined);
  const capsHash = parseHeader(headers, "x-orca-caps-hash", undefined);
  const clientCapabilities: ClientCapabilitiesRef | undefined =
    sdkVersion !== undefined || capsHash !== undefined
      ? { sdkVersion, hash: capsHash }
      : undefined;

  return {
    platform,
    osVersion,
    deviceModel,
    appVersion,
    buildNumber,
    screenSize: { width: screenWidth, height: screenHeight },
    pixelDensity,
    safeAreaInsets: { top: safeTop, bottom: safeBottom, left: safeLeft, right: safeRight },
    locale,
    timezone,
    language,
    networkType,
    ipAddress: parseHeader(headers, "x-forwarded-for", "127.0.0.1"),
    routePath: url.pathname,
    routeParams,
    queryParams,
    authToken,
    userId,
    clientCapabilities,
  };
}

function parseHeader(headers: Headers, name: string, fallback: string): string;
function parseHeader(headers: Headers, name: string, fallback: undefined): string | undefined;
function parseHeader(headers: Headers, name: string, fallback: string | undefined): string | undefined {
  return headers.get(name) ?? fallback;
}
