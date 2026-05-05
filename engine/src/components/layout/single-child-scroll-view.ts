import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import type { EdgeInsetsData } from "../helpers";

export interface SingleChildScrollViewProps {
  child?: Widget;
  scrollDirection?: Valueable<"horizontal" | "vertical">;
  reverse?: Valueable<boolean>;
  padding?: Valueable<EdgeInsetsData>;
  primary?: Valueable<boolean>;
  shrinkWrap?: Valueable<boolean>;
  actions?: ActionMap;
}

export class SingleChildScrollView extends SingleChildLayout {
  readonly type = "SingleChildScrollView";
  static readonly triggers = ["onScrollBegin", "onScrolling", "onScrollEnd"] as const;
  private props: Omit<SingleChildScrollViewProps, "child" | "actions">;

  private constructor(opts: SingleChildScrollViewProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: SingleChildScrollViewProps): SingleChildScrollView {
    return new SingleChildScrollView(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
