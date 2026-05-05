import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface ScrollbarProps {
  child?: Widget;
  thumbVisibility?: Valueable<boolean>;
  thickness?: Valueable<number>;
  actions?: ActionMap;
}

export class Scrollbar extends SingleChildLayout {
  readonly type = "Scrollbar";
  private props: Omit<ScrollbarProps, "child" | "actions">;

  private constructor(opts: ScrollbarProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: ScrollbarProps): Scrollbar {
    return new Scrollbar(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
