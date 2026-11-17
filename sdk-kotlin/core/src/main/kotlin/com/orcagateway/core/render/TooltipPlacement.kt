package com.orcagateway.core.render

import kotlin.math.max
import kotlin.math.min

/** The Tooltip's child in the overlay's coordinates, in logical pixels (dp). */
public data class TooltipRect(public val left: Double, public val top: Double, public val width: Double, public val height: Double)

/** A width and a height: the bubble's, or the overlay's the bubble is placed in. */
public data class TooltipSize(public val width: Double, public val height: Double)

/** Where the bubble's top-left corner goes in the overlay. */
public data class TooltipOrigin(public val x: Double, public val y: Double)

/**
 * Flutter's Material Tooltip with its defaults (material_ui tooltip.dart
 * :413-420), the bubble placed by the framework's `positionDependentBox`
 * (painting/geometry.dart:42-68) through Material's position delegate
 * (tooltip.dart:474-496). The UI layer passes the overlay as Flutter lays
 * it out: the full overlay less the keyboard at its bottom
 * (widgets/raw_tooltip.dart:896-897).
 */
public object TooltipPlacement {
    /** `kLongPressTimeout` (gestures/constants.dart:29), the long press that shows the bubble, in ms. */
    public const val LONG_PRESS: Long = 500L

    /**
     * `_defaultShowDuration` (tooltip.dart:416), RawTooltip's touchDelay
     * (:570): the bubble goes this long after the press is released
     * (raw_tooltip.dart:762-767), in ms.
     */
    public const val SHOW_DURATION: Long = 1500L

    /** `_kDefaultAnimationStyle.duration` (raw_tooltip.dart:27-31): the fade in, in ms, on fastOutSlowIn. */
    public const val FADE_IN: Long = 150L

    /** `_kDefaultAnimationStyle.reverseDuration` (raw_tooltip.dart:27-31): the fade out, in ms. */
    public const val FADE_OUT: Long = 75L

    /** `_defaultVerticalOffset` (tooltip.dart:413): from the child's centre to the bubble's near edge. */
    public const val VERTICAL_OFFSET: Double = 24.0

    /** `positionDependentBox`'s default margin (geometry.dart:48): the bubble's least distance from the overlay's edges. */
    public const val MARGIN: Double = 10.0

    /**
     * `positionDependentBox` with preferBelow true (tooltip.dart:414) about
     * the child's centre (raw_tooltip.dart:881-884). Below fits when the
     * bubble's bottom is no lower than the overlay's height less [MARGIN],
     * above when its top is no higher than [MARGIN]; it goes below when
     * both or neither fit, above only when below alone does not. Below,
     * its top is the centre + [VERTICAL_OFFSET] but no lower than the
     * height less [MARGIN]; above, its bottom is the centre less
     * [VERTICAL_OFFSET], its top no higher than [MARGIN]. x centres it on
     * the child, kept [MARGIN] from either edge; when the overlay's width
     * less the bubble's is at most 2 [MARGIN], it is centred in the overlay.
     * Flutter lays the bubble out within the overlay (`constraints.loosen()`,
     * raw_tooltip.dart:993), so x is never below 0: the UI layer must measure
     * [bubble] with the overlay's size as its maximum.
     */
    public fun origin(child: TooltipRect, bubble: TooltipSize, overlay: TooltipSize): TooltipOrigin {
        val targetX = child.left + child.width / 2
        val targetY = child.top + child.height / 2
        val fitsBelow = targetY + VERTICAL_OFFSET + bubble.height <= overlay.height - MARGIN
        val fitsAbove = targetY - VERTICAL_OFFSET - bubble.height >= MARGIN
        val below = if (fitsAbove == fitsBelow) true else fitsBelow
        val y = if (below) {
            min(targetY + VERTICAL_OFFSET, overlay.height - MARGIN)
        } else {
            max(targetY - VERTICAL_OFFSET - bubble.height, MARGIN)
        }
        val flexibleSpace = overlay.width - bubble.width
        val x = if (flexibleSpace <= 2 * MARGIN) {
            flexibleSpace / 2
        } else {
            (targetX - bubble.width / 2).coerceIn(MARGIN, flexibleSpace - MARGIN)
        }
        return TooltipOrigin(x, y)
    }
}
