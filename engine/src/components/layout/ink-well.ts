import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface InkWellProps {
  child?: Widget;
  borderRadius?: Valueable<number>;
  splashColor?: Valueable<string>;
  highlightColor?: Valueable<string>;
  actions?: ActionMap;
}

export class InkWell extends SingleChildLayout {
  readonly type = "InkWell";
  static readonly triggers = ["onTap", "onLongPress", "onDoubleTap"] as const;
  private props: Omit<InkWellProps, "child" | "actions">;

  private constructor(opts: InkWellProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: InkWellProps): InkWell {
    return new InkWell(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
