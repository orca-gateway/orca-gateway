import type { Valueable } from "../../types/value";

export interface EdgeInsetsData {
  top: Valueable<number>;
  right: Valueable<number>;
  bottom: Valueable<number>;
  left: Valueable<number>;
}

export const EdgeInsets = {
  all(value: number): EdgeInsetsData {
    return { top: value, right: value, bottom: value, left: value };
  },

  symmetric(opts: { horizontal?: number; vertical?: number }): EdgeInsetsData {
    return {
      top: opts.vertical ?? 0,
      right: opts.horizontal ?? 0,
      bottom: opts.vertical ?? 0,
      left: opts.horizontal ?? 0,
    };
  },

  only(opts: { top?: number; right?: number; bottom?: number; left?: number }): EdgeInsetsData {
    return {
      top: opts.top ?? 0,
      right: opts.right ?? 0,
      bottom: opts.bottom ?? 0,
      left: opts.left ?? 0,
    };
  },
} as const;
