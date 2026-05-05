import { MultiChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface SliverGridProps {
  children: Widget[];
  crossAxisCount: Valueable<number>;
  mainAxisSpacing?: Valueable<number>;
  crossAxisSpacing?: Valueable<number>;
  childAspectRatio?: Valueable<number>;
  actions?: ActionMap;
}

export class SliverGrid extends MultiChildLayout {
  readonly type = "SliverGrid";
  private props: Omit<SliverGridProps, "children" | "actions">;

  private constructor(opts: SliverGridProps) {
    super();
    this.children = opts.children;
    this.actions = opts.actions;
    const { children: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: SliverGridProps): SliverGrid {
    return new SliverGrid(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
