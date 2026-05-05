import { MultiChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import type { EdgeInsetsData } from "../helpers";

export interface ReorderableListViewProps {
  children: Widget[];
  scrollDirection?: Valueable<"horizontal" | "vertical">;
  padding?: Valueable<EdgeInsetsData>;
  actions?: ActionMap;
}

export class ReorderableListView extends MultiChildLayout {
  readonly type = "ReorderableListView";
  private props: Omit<ReorderableListViewProps, "children" | "actions">;

  private constructor(opts: ReorderableListViewProps) {
    super();
    this.children = opts.children;
    this.actions = opts.actions;
    const { children: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: ReorderableListViewProps): ReorderableListView {
    return new ReorderableListView(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
