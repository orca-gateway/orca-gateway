import { PrimitiveWidget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import type { TextStyleData } from "../helpers";

export interface TextProps {
  data: Valueable<string>;
  style?: Valueable<TextStyleData>;
  textAlign?: Valueable<"left" | "right" | "center" | "justify" | "start" | "end">;
  maxLines?: Valueable<number>;
  overflow?: Valueable<"clip" | "fade" | "ellipsis" | "visible">;
  softWrap?: Valueable<boolean>;
  semanticsLabel?: Valueable<string>;
  actions?: ActionMap;
}

export class Text extends PrimitiveWidget {
  readonly type = "Text";
  private props: Omit<TextProps, "actions">;

  private constructor(opts: TextProps) {
    super();
    this.actions = opts.actions;
    const { actions: _, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: TextProps): Text {
    return new Text(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
