import { MultiChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface PageViewProps {
  children: Widget[];
  scrollDirection?: Valueable<"horizontal" | "vertical">;
  pageSnapping?: Valueable<boolean>;
  reverse?: Valueable<boolean>;
  actions?: ActionMap;
}

export class PageView extends MultiChildLayout {
  readonly type = "PageView";
  private props: Omit<PageViewProps, "children" | "actions">;

  private constructor(opts: PageViewProps) {
    super();
    this.children = opts.children;
    this.actions = opts.actions;
    const { children: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: PageViewProps): PageView {
    return new PageView(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
