import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface AspectRatioProps {
  child?: Widget;
  aspectRatio: Valueable<number>;
  actions?: ActionMap;
}

export class AspectRatio extends SingleChildLayout {
  readonly type = "AspectRatio";
  private props: Omit<AspectRatioProps, "child" | "actions">;

  private constructor(opts: AspectRatioProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: AspectRatioProps): AspectRatio {
    return new AspectRatio(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
