import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface DialogProps {
  child?: Widget;
  title?: Widget;
  dismissible?: Valueable<boolean>;
  backgroundColor?: Valueable<string>;
  borderRadius?: Valueable<number>;
  actions?: ActionMap;
}

export class Dialog extends SingleChildLayout {
  readonly type = "Dialog";
  private props: Omit<DialogProps, "child" | "actions">;

  private constructor(opts: DialogProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: DialogProps): Dialog {
    return new Dialog(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
