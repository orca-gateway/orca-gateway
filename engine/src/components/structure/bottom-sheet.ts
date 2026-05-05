import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface BottomSheetProps {
  child?: Widget;
  dismissible?: Valueable<boolean>;
  backgroundColor?: Valueable<string>;
  borderRadius?: Valueable<number>;
  actions?: ActionMap;
}

export class BottomSheet extends SingleChildLayout {
  readonly type = "BottomSheet";
  private props: Omit<BottomSheetProps, "child" | "actions">;

  private constructor(opts: BottomSheetProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: BottomSheetProps): BottomSheet {
    return new BottomSheet(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
