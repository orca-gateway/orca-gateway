import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import type { Value } from "../../types/value";

export interface SubPageProps {
  /**
   * Stable key (REQUIRED). Used as the component ID and as the namespace prefix for all embedded sub-page
   * component IDs. Must not contain `:` or `#`: the prefixes are `key:` and `key#<n>:`.
   */
  key: string;
  /** The page ID to fetch and embed. */
  pageId: Valueable<string>;
  /** Optional parameters passed to the embedded page. */
  params?: Record<string, Value>;
  /** Optional loading placeholder widget displayed while the sub-page is being fetched. */
  child?: Widget;
  actions?: ActionMap;
}

/**
 * Embeds a page inside another page. The SDK fetches the sub-page content
 * at render time and renders it in place. Sub-page component IDs are
 * prefixed with `{key}:` to prevent collisions with the parent page.
 * Sub-page state keys are also prefixed with `{key}:` and merged into
 * the parent's pageState, enabling shared state access.
 *
 * The optional child widget is used as a loading placeholder while the
 * sub-page content is being fetched.
 */
export class SubPage extends SingleChildLayout {
  readonly type = "SubPage";
  static readonly introducedIn = "1.0.0";
  private props: Omit<SubPageProps, "key" | "child" | "actions">;

  private constructor(opts: SubPageProps) {
    super();
    if (!opts.key) {
      throw new Error("SubPage requires a `key` — it is used as the ID namespace prefix for embedded components.");
    }
    this.key = checkedKey(opts.key);
    this.child = opts.child;
    this.actions = opts.actions;
    const { key: _, child: _c, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: SubPageProps): SubPage {
    return new SubPage(opts);
  }

  withKey(key: string): this {
    return super.withKey(checkedKey(key));
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}

/**
 * The SDK mounts the embedded page under `key:` and each joined page under
 * `key#<n>:`. A key with one of those two characters would own another
 * SubPage's ids and state (`feed#1` gives `feed#1:`, join 1 of `feed`).
 */
function checkedKey(key: string): string {
  if (/[:#]/.test(key)) {
    throw new Error(`SubPage key "${key}" must not contain ":" or "#" — they separate the sub-page prefix from the ids and state keys under it.`);
  }
  return key;
}
