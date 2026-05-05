import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import type { EdgeInsetsData, BoxDecorationData, AlignmentValue, Clip } from "../helpers";

export interface ContainerProps {
  child?: Widget;
  padding?: Valueable<EdgeInsetsData>;
  margin?: Valueable<EdgeInsetsData>;
  decoration?: Valueable<BoxDecorationData>;
  width?: Valueable<number>;
  height?: Valueable<number>;
  alignment?: Valueable<AlignmentValue>;
  color?: Valueable<string>;
  clipBehavior?: Valueable<Clip>;
  actions?: ActionMap;
}

export class Container extends SingleChildLayout {
  readonly type = "Container";
  private props: Omit<ContainerProps, "child" | "actions">;

  private constructor(opts: ContainerProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: ContainerProps): Container {
    return new Container(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
