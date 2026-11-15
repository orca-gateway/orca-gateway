import { PrimitiveWidget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import type { ImageFit } from "../helpers";

export interface VideoProps {
  /** Network URL of the video (mp4 or HLS .m3u8). */
  src: Valueable<string>;
  /** Image shown until the first frame is ready, and when playback fails. */
  poster?: Valueable<string>;
  fit?: Valueable<ImageFit>;
  width?: Valueable<number>;
  height?: Valueable<number>;
  /**
   * Play while at least `visibleFraction` of the video is on screen and pause
   * when it scrolls away (default true). False plays only when tapped.
   */
  autoplay?: Valueable<boolean>;
  /** Fraction (0..1) of the video that must be visible for autoplay; default 0.5. */
  visibleFraction?: Valueable<number>;
  /** Default true: feeds and reels play silently. */
  muted?: Valueable<boolean>;
  /** Default true. */
  loop?: Valueable<boolean>;
  actions?: ActionMap;
}

/**
 * A muted, looping video that plays while it is on screen, the way feed and
 * reel previews do. Native clients only (AVPlayer on iOS, MediaPlayer on
 * Android); Flutter and web degrade it to their fallback, so a page that must
 * show it everywhere needs another path for them.
 */
export class Video extends PrimitiveWidget {
  readonly type = "Video";
  static readonly introducedIn = "1.1.0";
  static readonly targets = ["android", "ios"];
  private props: Omit<VideoProps, "actions">;

  private constructor(opts: VideoProps) {
    super();
    this.actions = opts.actions;
    const { actions: _, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: VideoProps): Video {
    return new Video(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
