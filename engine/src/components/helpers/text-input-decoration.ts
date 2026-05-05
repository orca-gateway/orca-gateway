import type { EdgeInsetsData } from "./edge-insets";
import type { TextStyleData } from "./text-style";

// Serializable subset of Flutter's InputDecoration — the visual configuration
// applied to a TextField. All fields are optional; omit what you don't need.
// Complex Flutter-side types like `prefixIcon` (a Widget) live outside the
// wire format — authors place icons via separate TextField children/slots
// if/when that work lands (Phase 2b follow-up).
export interface TextInputDecorationData {
  /** Floating label shown above the input when focused or non-empty. */
  labelText?: string;
  /** Hint shown inside the field when empty. */
  hintText?: string;
  /** Helper text shown below the field. */
  helperText?: string;
  /** Error text shown below the field; overrides helperText when set. */
  errorText?: string;
  /** Short text shown at the leading edge of the field. */
  prefixText?: string;
  /** Short text shown at the trailing edge of the field. */
  suffixText?: string;
  /** Whether the field is filled with `fillColor`. */
  filled?: boolean;
  /** Background fill color when `filled` is true. */
  fillColor?: string;
  /** Inner content padding. */
  contentPadding?: EdgeInsetsData;
  /** Style for label text when not floating. */
  labelStyle?: TextStyleData;
  /** Style for hint text. */
  hintStyle?: TextStyleData;
  /** Style for helper text. */
  helperStyle?: TextStyleData;
  /** Style for error text. */
  errorStyle?: TextStyleData;
  /** Border style: "outline" | "underline" | "none". Default is underline. */
  border?: "outline" | "underline" | "none";
  /** Hide the enclosed border on the enabled, non-focused state. */
  isDense?: boolean;
  /** Accessibility-only alternative to labelText — not visible. */
  semanticCounterText?: string;
}
