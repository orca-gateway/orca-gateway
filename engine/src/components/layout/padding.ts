import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import type { EdgeInsetsData } from "../helpers";

export interface PaddingProps {
  child?: Widget;
  padding: Valueable<EdgeInsetsData>;
  actions?: ActionMap;
}

export class Padding extends SingleChildLayout {
  readonly type = "Padding";
  private props: Omit<PaddingProps, "child" | "actions">;

  private constructor(opts: PaddingProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: PaddingProps): Padding {
    return new Padding(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
