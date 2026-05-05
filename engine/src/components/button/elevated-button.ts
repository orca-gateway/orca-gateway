import { ButtonWidget, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import type { EdgeInsetsData } from "../helpers";

export interface ElevatedButtonProps {
  child?: Widget;
  enabled?: Valueable<boolean>;
  color?: Valueable<string>;
  backgroundColor?: Valueable<string>;
  foregroundColor?: Valueable<string>;
  elevation?: Valueable<number>;
  borderRadius?: Valueable<number>;
  padding?: Valueable<EdgeInsetsData>;
  splashColor?: Valueable<string>;
  highlightColor?: Valueable<string>;
  autofocus?: Valueable<boolean>;
  actions?: ActionMap;
}

export class ElevatedButton extends ButtonWidget {
  readonly type = "ElevatedButton";
  static readonly triggers = ["onTap", "onLongPress"] as const;
  private props: Omit<ElevatedButtonProps, "child" | "actions">;

  private constructor(opts: ElevatedButtonProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: ElevatedButtonProps): ElevatedButton {
    return new ElevatedButton(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
