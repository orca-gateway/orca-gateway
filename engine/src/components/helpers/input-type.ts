export type InputType = "text" | "number" | "email" | "password" | "phone" | "url" | "multiline";

// The keyboard's action button label / intent. Mirrors a common subset of
// Flutter's TextInputAction enum; extend if a missing variant is needed.
export type TextInputAction =
  | "done"
  | "go"
  | "newline"
  | "next"
  | "previous"
  | "search"
  | "send"
  | "join"
  | "route"
  | "emergencyCall"
  | "continueAction"
  | "unspecified";
