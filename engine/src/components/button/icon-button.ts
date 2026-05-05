import { ButtonWidget, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import type { EdgeInsetsData, AlignmentValue, BoxConstraintsData } from "../helpers";

export interface IconButtonProps {
  child?: Widget;
  enabled?: Valueable<boolean>;
  color?: Valueable<string>;
  size?: Valueable<number>;
  tooltip?: Valueable<string>;
  splashColor?: Valueable<string>;
  highlightColor?: Valueable<string>;
  padding?: Valueable<EdgeInsetsData>;
  alignment?: Valueable<AlignmentValue>;
  constraints?: Valueable<BoxConstraintsData>;
  actions?: ActionMap;
}

export class IconButton extends ButtonWidget {
  readonly type = "IconButton";
  static readonly triggers = ["onTap", "onLongPress"] as const;
  private props: Omit<IconButtonProps, "child" | "actions">;

  private constructor(opts: IconButtonProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: IconButtonProps): IconButton {
    return new IconButton(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
