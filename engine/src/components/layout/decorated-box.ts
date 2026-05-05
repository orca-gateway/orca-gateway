import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import type { BoxDecorationData } from "../helpers";

export interface DecoratedBoxProps {
  child?: Widget;
  decoration: Valueable<BoxDecorationData>;
  position?: Valueable<"background" | "foreground">;
  actions?: ActionMap;
}

export class DecoratedBox extends SingleChildLayout {
  readonly type = "DecoratedBox";
  private props: Omit<DecoratedBoxProps, "child" | "actions">;

  private constructor(opts: DecoratedBoxProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: DecoratedBoxProps): DecoratedBox {
    return new DecoratedBox(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
