import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";

export interface ClipOvalProps {
  child?: Widget;
  actions?: ActionMap;
}

export class ClipOval extends SingleChildLayout {
  readonly type = "ClipOval";
  private props: Omit<ClipOvalProps, "child" | "actions">;

  private constructor(opts: ClipOvalProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: ClipOvalProps): ClipOval {
    return new ClipOval(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
