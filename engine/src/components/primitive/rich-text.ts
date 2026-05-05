import { PrimitiveWidget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import type { TextStyleData } from "../helpers";

export interface TextSpanData {
  text?: Valueable<string>;
  style?: Valueable<TextStyleData>;
  children?: TextSpanData[];
}

export interface RichTextProps {
  text: Valueable<TextSpanData>;
  textAlign?: Valueable<"left" | "right" | "center" | "justify" | "start" | "end">;
  maxLines?: Valueable<number>;
  overflow?: Valueable<"clip" | "fade" | "ellipsis" | "visible">;
  actions?: ActionMap;
}

export class RichText extends PrimitiveWidget {
  readonly type = "RichText";
  private props: Omit<RichTextProps, "actions">;

  private constructor(opts: RichTextProps) {
    super();
    this.actions = opts.actions;
    const { actions: _, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: RichTextProps): RichText {
    return new RichText(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
