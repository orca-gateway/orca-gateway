import { MultiChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";

export interface SliverListProps {
  children: Widget[];
  actions?: ActionMap;
}

export class SliverList extends MultiChildLayout {
  readonly type = "SliverList";
  private props: Omit<SliverListProps, "children" | "actions">;

  private constructor(opts: SliverListProps) {
    super();
    this.children = opts.children;
    this.actions = opts.actions;
    const { children: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: SliverListProps): SliverList {
    return new SliverList(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
