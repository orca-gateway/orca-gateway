import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import type { TextStyleData } from "../helpers";

export interface DefaultTextStyleProps {
  child?: Widget;
  style: Valueable<TextStyleData>;
  textAlign?: Valueable<"left" | "right" | "center" | "justify" | "start" | "end">;
  maxLines?: Valueable<number>;
  overflow?: Valueable<"clip" | "fade" | "ellipsis" | "visible">;
  actions?: ActionMap;
}

export class DefaultTextStyle extends SingleChildLayout {
  readonly type = "DefaultTextStyle";
  private props: Omit<DefaultTextStyleProps, "child" | "actions">;

  private constructor(opts: DefaultTextStyleProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: DefaultTextStyleProps): DefaultTextStyle {
    return new DefaultTextStyle(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
