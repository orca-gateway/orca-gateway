import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import type { EdgeInsetsData, Clip } from "../helpers";

export interface CardProps {
  child?: Widget;
  elevation?: Valueable<number>;
  padding?: Valueable<EdgeInsetsData>;
  margin?: Valueable<EdgeInsetsData>;
  color?: Valueable<string>;
  shadowColor?: Valueable<string>;
  surfaceTintColor?: Valueable<string>;
  borderRadius?: Valueable<number>;
  clipBehavior?: Valueable<Clip>;
  actions?: ActionMap;
}

export class Card extends SingleChildLayout {
  readonly type = "Card";
  private props: Omit<CardProps, "child" | "actions">;

  private constructor(opts: CardProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: CardProps): Card {
    return new Card(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
