import { MultiChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import type { StackFit, AlignmentValue, Clip } from "../helpers";
import type { TextDirection } from "../helpers";

export interface StackProps {
  children: Widget[];
  fit?: Valueable<StackFit>;
  alignment?: Valueable<AlignmentValue>;
  textDirection?: Valueable<TextDirection>;
  clipBehavior?: Valueable<Clip>;
  actions?: ActionMap;
}

export class Stack extends MultiChildLayout {
  readonly type = "Stack";
  private props: Omit<StackProps, "children" | "actions">;

  private constructor(opts: StackProps) {
    super();
    this.children = opts.children;
    this.actions = opts.actions;
    const { children: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: StackProps): Stack {
    return new Stack(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
