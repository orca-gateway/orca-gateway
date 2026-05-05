import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface PositionedProps {
  child?: Widget;
  top?: Valueable<number>;
  right?: Valueable<number>;
  bottom?: Valueable<number>;
  left?: Valueable<number>;
  width?: Valueable<number>;
  height?: Valueable<number>;
  actions?: ActionMap;
}

export class Positioned extends SingleChildLayout {
  readonly type = "Positioned";
  private props: Omit<PositionedProps, "child" | "actions">;

  private constructor(opts: PositionedProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: PositionedProps): Positioned {
    return new Positioned(opts);
  }

  static fill(opts: PositionedProps): Positioned {
    return new Positioned({
      ...opts,
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
    })
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
