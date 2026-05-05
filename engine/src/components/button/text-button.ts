import { ButtonWidget, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface TextButtonProps {
  child?: Widget;
  enabled?: Valueable<boolean>;
  color?: Valueable<string>;
  splashColor?: Valueable<string>;
  highlightColor?: Valueable<string>;
  autofocus?: Valueable<boolean>;
  actions?: ActionMap;
}

export class TextButton extends ButtonWidget {
  readonly type = "TextButton";
  static readonly triggers = ["onTap", "onLongPress"] as const;
  private props: Omit<TextButtonProps, "child" | "actions">;

  private constructor(opts: TextButtonProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: TextButtonProps): TextButton {
    return new TextButton(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
