import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface PullToRefreshProps {
  child?: Widget;
  color?: Valueable<string>;
  backgroundColor?: Valueable<string>;
  displacement?: Valueable<number>;
  actions?: ActionMap;
}

export class PullToRefresh extends SingleChildLayout {
  readonly type = "PullToRefresh";
  static readonly triggers = ["onRefresh"] as const;
  private props: Omit<PullToRefreshProps, "child" | "actions">;

  private constructor(opts: PullToRefreshProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: PullToRefreshProps): PullToRefresh {
    return new PullToRefresh(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
