import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import type { ImageFit, AlignmentValue } from "../helpers";

export interface FittedBoxProps {
  child?: Widget;
  fit?: Valueable<ImageFit>;
  alignment?: Valueable<AlignmentValue>;
  actions?: ActionMap;
}

export class FittedBox extends SingleChildLayout {
  readonly type = "FittedBox";
  private props: Omit<FittedBoxProps, "child" | "actions">;

  private constructor(opts: FittedBoxProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: FittedBoxProps): FittedBox {
    return new FittedBox(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
