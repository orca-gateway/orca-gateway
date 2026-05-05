import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";

export interface SliverToBoxAdapterProps {
  child?: Widget;
  actions?: ActionMap;
}

export class SliverToBoxAdapter extends SingleChildLayout {
  readonly type = "SliverToBoxAdapter";
  private props: Omit<SliverToBoxAdapterProps, "child" | "actions">;

  private constructor(opts: SliverToBoxAdapterProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: SliverToBoxAdapterProps): SliverToBoxAdapter {
    return new SliverToBoxAdapter(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
