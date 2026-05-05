import type { AlignmentValue } from "./alignment";
import type { Valueable } from "../../types/value";

export interface BorderRadiusData {
  topLeft?: Valueable<number>;
  topRight?: Valueable<number>;
  bottomLeft?: Valueable<number>;
  bottomRight?: Valueable<number>;
}

export interface BorderData {
  width?: Valueable<number>;
  color?: Valueable<string>;
  style?: "solid" | "none";
}

export interface BoxShadowData {
  color?: Valueable<string>;
  blurRadius?: Valueable<number>;
  spreadRadius?: Valueable<number>;
  offset?: { dx: Valueable<number>; dy: Valueable<number> };
}

export interface GradientData {
  type: "linear" | "radial";
  colors: Valueable<string>[];
  begin?: AlignmentValue;
  end?: AlignmentValue;
  stops?: number[];
}

export interface BoxDecorationData {
  color?: Valueable<string>;
  borderRadius?: Valueable<number> | BorderRadiusData;
  border?: BorderData;
  boxShadow?: BoxShadowData[];
  gradient?: GradientData;
}

export function BoxDecoration(opts: BoxDecorationData): BoxDecorationData {
  return opts;
}

export const BorderRadius = {
  all(value: number): BorderRadiusData {
    return { topLeft: value, topRight: value, bottomLeft: value, bottomRight: value };
  },

  circular(radius: number): BorderRadiusData {
    return BorderRadius.all(radius);
  },

  only(opts: { topLeft?: number; topRight?: number; bottomLeft?: number; bottomRight?: number }): BorderRadiusData {
    return opts;
  },
} as const;
