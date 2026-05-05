import { PrimitiveWidget } from "../../types/widget";
import type { Valueable } from "../../types/value";
import { MaterialIcons } from "../../types/icons";

export interface BottomNavItemProps {
  icon: Valueable<string | MaterialIcons>;
  activeIcon?: Valueable<string>;
  label: Valueable<string>;
  tooltip?: Valueable<string>;
  backgroundColor?: Valueable<string>;
}

export class BottomNavItem extends PrimitiveWidget {
  readonly type = "BottomNavItem";
  private props: BottomNavItemProps;

  private constructor(opts: BottomNavItemProps) {
    super();
    this.props = opts;
  }

  static new(opts: BottomNavItemProps): BottomNavItem {
    return new BottomNavItem(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
