import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";

export interface FormProps {
  child?: Widget;
  actions?: ActionMap;
}

export class Form extends SingleChildLayout {
  readonly type = "Form";
  private props: Omit<FormProps, "child" | "actions">;

  private constructor(opts: FormProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: FormProps): Form {
    return new Form(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
