import type { Widget } from "../types/widget";
import type { StateDefinition } from "../types/state";
import type { PageContext } from "../types/context";
import { Page, type PageResponse } from "./page";
import type { CachePolicy } from "./cache";

// ── PageDefinition Builder ─────────────────────────────────

export interface PageDefinitionConfig {
  id: string;
  title: string;
  appState?: string[];
  cachePolicy?: CachePolicy;
  cacheTtl?: number;
  state?: StateDefinition[] | ((ctx: PageContext) => StateDefinition[]);
  getInfoData?: (ctx: PageContext) => Promise<unknown> | unknown;
  render: (ctx: PageContext, infoData: unknown) => Widget;
  postRender?: (ctx: PageContext, response: PageResponse) => void;
}

export class PageDefinition {
  static create(config: PageDefinitionConfig): Page {
    return new InlinePage(config);
  }
}

class InlinePage extends Page {
  readonly id: string;
  readonly title: string;
  readonly cachePolicy: CachePolicy;
  readonly cacheTtl: number;
  private config: PageDefinitionConfig;

  constructor(config: PageDefinitionConfig) {
    super();
    this.id = config.id;
    this.title = config.title;
    this.cachePolicy = config.cachePolicy ?? "none";
    this.cacheTtl = config.cacheTtl ?? 60;
    this.config = config;
  }

  requiredAppState(): string[] {
    return this.config.appState ?? [];
  }

  async getInfoData(context: PageContext): Promise<unknown> {
    if (this.config.getInfoData) {
      return this.config.getInfoData(context);
    }
    return undefined;
  }

  getState(context: PageContext): StateDefinition[] {
    if (!this.config.state) return [];
    if (typeof this.config.state === "function") {
      return this.config.state(context);
    }
    return this.config.state;
  }

  render(context: PageContext, infoData: unknown): Widget {
    return this.config.render(context, infoData);
  }

  postRender(context: PageContext, response: PageResponse): void {
    this.config.postRender?.(context, response);
  }
}
