import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface BackdropFilterProps {
  child?: Widget;
  blurX?: Valueable<number>;
  blurY?: Valueable<number>;
  actions?: ActionMap;
}

export class BackdropFilter extends SingleChildLayout {
  readonly type = "BackdropFilter";
  private props: Omit<BackdropFilterProps, "child" | "actions">;

  private constructor(opts: BackdropFilterProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: BackdropFilterProps): BackdropFilter {
    return new BackdropFilter(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
