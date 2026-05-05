import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import type { BorderRadiusData } from "../helpers";

export interface ClipRRectProps {
  child?: Widget;
  borderRadius?: Valueable<number | BorderRadiusData>;
  actions?: ActionMap;
}

export class ClipRRect extends SingleChildLayout {
  readonly type = "ClipRRect";
  private props: Omit<ClipRRectProps, "child" | "actions">;

  private constructor(opts: ClipRRectProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: ClipRRectProps): ClipRRect {
    return new ClipRRect(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
