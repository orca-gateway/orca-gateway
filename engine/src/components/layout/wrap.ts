import { MultiChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import type { MainAxisAlignment, CrossAxisAlignment } from "../helpers";

export interface WrapProps {
  children: Widget[];
  spacing?: Valueable<number>;
  runSpacing?: Valueable<number>;
  alignment?: Valueable<MainAxisAlignment>;
  crossAxisAlignment?: Valueable<CrossAxisAlignment>;
  actions?: ActionMap;
}

export class Wrap extends MultiChildLayout {
  readonly type = "Wrap";
  private props: Omit<WrapProps, "children" | "actions">;

  private constructor(opts: WrapProps) {
    super();
    this.children = opts.children;
    this.actions = opts.actions;
    const { children: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: WrapProps): Wrap {
    return new Wrap(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
