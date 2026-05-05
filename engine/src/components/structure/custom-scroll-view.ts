import { MultiChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface CustomScrollViewProps {
  slivers: Widget[];
  scrollDirection?: Valueable<"horizontal" | "vertical">;
  reverse?: Valueable<boolean>;
  shrinkWrap?: Valueable<boolean>;
  actions?: ActionMap;
}

export class CustomScrollView extends MultiChildLayout {
  readonly type = "CustomScrollView";
  static readonly triggers = ["onScrollBegin", "onScrolling", "onScrollEnd"] as const;
  private props: Omit<CustomScrollViewProps, "slivers" | "actions">;

  private constructor(opts: CustomScrollViewProps) {
    super();
    this.children = opts.slivers;
    this.actions = opts.actions;
    const { slivers: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: CustomScrollViewProps): CustomScrollView {
    return new CustomScrollView(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
