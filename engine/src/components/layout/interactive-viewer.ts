import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface InteractiveViewerProps {
  child?: Widget;
  minScale?: Valueable<number>;
  maxScale?: Valueable<number>;
  panEnabled?: Valueable<boolean>;
  scaleEnabled?: Valueable<boolean>;
  actions?: ActionMap;
}

export class InteractiveViewer extends SingleChildLayout {
  readonly type = "InteractiveViewer";
  private props: Omit<InteractiveViewerProps, "child" | "actions">;

  private constructor(opts: InteractiveViewerProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: InteractiveViewerProps): InteractiveViewer {
    return new InteractiveViewer(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
