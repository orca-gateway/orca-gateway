import type { Widget } from "../types/widget";
import type { ComponentNode } from "../types/node";
import type { StateDefinition } from "../types/state";
import type { RequestInfo, PageContext } from "../types/context";
import type { CachePolicy } from "./cache";

// ── Page Response (wire format sent to client) ─────────────

export interface PageResponse {
  pageId: string;
  title: string;
  state: StateDefinition[];
  components: ComponentNode[];
  [key: string]: unknown;
}

// ── Page Abstract Class ────────────────────────────────────
//
// `Page<TInfo>` is generic over the `infoData` shape its `getInfoData` stage
// produces. Binding `TInfo` lets author-defined composites (`CompositeWidget<TInfo>`)
// share the same type, giving end-to-end compile-time safety from
// `getInfoData` through `render(ctx, info)` into composite `build(ctx, info)`.
//
// Backward compatibility: `TInfo` defaults to `unknown`, so every existing
// `extends Page` continues to compile with no annotation — their `infoData`
// and `render` signatures stay exactly as before.

export abstract class Page<TInfo = unknown> {
  abstract readonly id: string;
  abstract readonly title: string;

  /** Cache policy for this page. Default: "none" (no caching). */
  readonly cachePolicy: CachePolicy = "none";

  /** Cache TTL in seconds. Default: 60. */
  readonly cacheTtl: number = 60;

  /**
   * Declares which app state keys this page needs from the client.
   * The client only sends these keys in the request body.
   * Override to specify keys (e.g. ["user.name", "theme"]).
   */
  requiredAppState(): string[] {
    return [];
  }

  /**
   * Stage 1: Fetch any external/async data needed for this page.
   * Runs before state initialization. Return value is passed as `infoData` to render.
   */
  async getInfoData(_context: PageContext): Promise<TInfo> {
    return undefined as TInfo;
  }

  /**
   * Stage 2: Define the initial page state.
   * Return state definitions with keys and initial values.
   */
  getState(_context: PageContext): StateDefinition[] {
    return [];
  }

  /**
   * Stage 3: Build the widget tree for this page.
   * Has access to infoData from stage 1 and state from stage 2.
   */
  abstract render(context: PageContext, infoData: TInfo): Widget;

  /**
   * Stage 4 (optional): Post-render hook that receives the full mutable PageResponse.
   * Can modify components, state, title, or add arbitrary fields.
   * This stage is never cached — it runs fresh on every request.
   */
  postRender(_context: PageContext, _response: PageResponse): void {}
}
