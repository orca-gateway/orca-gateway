import { ButtonWidget, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface FloatingActionButtonProps {
  child?: Widget;
  enabled?: Valueable<boolean>;
  backgroundColor?: Valueable<string>;
  elevation?: Valueable<number>;
  mini?: Valueable<boolean>;
  tooltip?: Valueable<string>;
  splashColor?: Valueable<string>;
  focusColor?: Valueable<string>;
  hoverColor?: Valueable<string>;
  heroTag?: Valueable<string>;
  isExtended?: Valueable<boolean>;
  actions?: ActionMap;
}

export class FloatingActionButton extends ButtonWidget {
  readonly type = "FloatingActionButton";
  static readonly triggers = ["onTap", "onLongPress"] as const;
  private props: Omit<FloatingActionButtonProps, "child" | "actions">;

  private constructor(opts: FloatingActionButtonProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: FloatingActionButtonProps): FloatingActionButton {
    return new FloatingActionButton(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
