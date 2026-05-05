export type AlignmentValue =
  | "topLeft"
  | "topCenter"
  | "topRight"
  | "centerLeft"
  | "center"
  | "centerRight"
  | "bottomLeft"
  | "bottomCenter"
  | "bottomRight";

export const Alignment = {
  topLeft: "topLeft" as AlignmentValue,
  topCenter: "topCenter" as AlignmentValue,
  topRight: "topRight" as AlignmentValue,
  centerLeft: "centerLeft" as AlignmentValue,
  center: "center" as AlignmentValue,
  centerRight: "centerRight" as AlignmentValue,
  bottomLeft: "bottomLeft" as AlignmentValue,
  bottomCenter: "bottomCenter" as AlignmentValue,
  bottomRight: "bottomRight" as AlignmentValue,
} as const;
