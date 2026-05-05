import { PrimitiveWidget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import type { TextStyleData } from "../helpers";

export interface SelectableTextProps {
  data: Valueable<string>;
  style?: Valueable<TextStyleData>;
  textAlign?: Valueable<"left" | "right" | "center" | "justify" | "start" | "end">;
  maxLines?: Valueable<number>;
  actions?: ActionMap;
}

export class SelectableText extends PrimitiveWidget {
  readonly type = "SelectableText";
  private props: Omit<SelectableTextProps, "actions">;

  private constructor(opts: SelectableTextProps) {
    super();
    this.actions = opts.actions;
    const { actions: _, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: SelectableTextProps): SelectableText {
    return new SelectableText(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
