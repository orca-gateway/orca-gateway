import { MultiChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import type { EdgeInsetsData } from "../helpers";

export interface GridViewProps {
  children: Widget[];
  crossAxisCount: Valueable<number>;
  mainAxisSpacing?: Valueable<number>;
  crossAxisSpacing?: Valueable<number>;
  childAspectRatio?: Valueable<number>;
  scrollDirection?: Valueable<"horizontal" | "vertical">;
  padding?: Valueable<EdgeInsetsData>;
  shrinkWrap?: Valueable<boolean>;
  primary?: Valueable<boolean>;
  actions?: ActionMap;
}

export class GridView extends MultiChildLayout {
  readonly type = "GridView";
  static readonly triggers = ["onScrollBegin", "onScrolling", "onScrollEnd"] as const;
  private props: Omit<GridViewProps, "children" | "actions">;

  private constructor(opts: GridViewProps) {
    super();
    this.children = opts.children;
    this.actions = opts.actions;
    const { children: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: GridViewProps): GridView {
    return new GridView(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
