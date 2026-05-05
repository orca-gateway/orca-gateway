import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import type { AlignmentValue } from "../helpers";

export interface AlignProps {
  child?: Widget;
  alignment?: Valueable<AlignmentValue>;
  widthFactor?: Valueable<number>;
  heightFactor?: Valueable<number>;
  actions?: ActionMap;
}

export class Align extends SingleChildLayout {
  readonly type = "Align";
  private props: Omit<AlignProps, "child" | "actions">;

  private constructor(opts: AlignProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: AlignProps): Align {
    return new Align(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
