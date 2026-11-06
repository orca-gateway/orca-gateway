/**
 * Client platforms an Orca SDK can run on (Epic 23b).
 *
 * Used in two places: `static readonly targets` on a widget class (which
 * platforms render it natively, surfaced in `widget-registry.json`) and
 * `targets` on a page definition (which platforms the author expects the
 * page to be served to). The pipeline compares the two and warns, once per
 * page in development, about widgets a declared target cannot render.
 */
export type Platform = "flutter" | "web" | "android" | "ios";

export const ALL_PLATFORMS: readonly Platform[] = ["flutter", "web", "android", "ios"];
