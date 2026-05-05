import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface TooltipProps {
  child?: Widget;
  message: Valueable<string>;
  actions?: ActionMap;
}

export class Tooltip extends SingleChildLayout {
  readonly type = "Tooltip";
  private props: Omit<TooltipProps, "child" | "actions">;

  private constructor(opts: TooltipProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: TooltipProps): Tooltip {
    return new Tooltip(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
