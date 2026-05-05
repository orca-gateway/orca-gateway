import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import type { AlignmentValue } from "../helpers";

export interface TransformMatrix {
  type: "rotate" | "scale" | "translate";
  angle?: number;
  scaleX?: number;
  scaleY?: number;
  dx?: number;
  dy?: number;
}

export interface TransformProps {
  child?: Widget;
  transform?: Valueable<TransformMatrix>;
  alignment?: Valueable<AlignmentValue>;
  actions?: ActionMap;
}

export class Transform extends SingleChildLayout {
  readonly type = "Transform";
  private props: Omit<TransformProps, "child" | "actions">;

  private constructor(opts: TransformProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: TransformProps): Transform {
    return new Transform(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
