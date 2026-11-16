package com.orcagateway.core.render

import com.orcagateway.core.json.JsonValue

/**
 * Where item [index] of a list lies along the list's axis: from [start],
 * [size] long. The unit is the caller's, the same for every span.
 */
public data class ItemSpan(public val index: Int, public val start: Double, public val size: Double) {
    /** The middle of the item. */
    public val centre: Double get() = start + size / 2
}

/**
 * The arithmetic of a drop on a ReorderableListView, so the view holds
 * none. A slot is a gap between items: slot `s` is before item `s`, slot
 * `count` after the last one.
 *
 * What `onReorder` reports is Flutter's raw `newIndex`
 * (layout_builders.dart:707-712): the insertion index before the dragged
 * item is removed, which is the slot itself. Item 0 dropped at the end of
 * three gives 3, below item 1 gives 2, the last one at the top gives 0.
 * The Swift twin (`ReorderDrop.swift`) pins the same table.
 */
public object ReorderDrop {
    /**
     * The raw newIndex of item [from] dropped in [slot] of a list of
     * [count]; null when nothing moved (the slot before the item or the one
     * after it), when [from] or [slot] is outside the list, and for a list
     * of none or one.
     */
    public fun newIndex(from: Int, slot: Int, count: Int): Int? {
        if (count < 2 || from !in 0 until count || slot !in 0..count) return null
        if (slot == from || slot == from + 1) return null
        return slot
    }

    /** The payload `V.event` reads for that drop, `{oldIndex, newIndex}`; null when [newIndex] is. */
    public fun event(from: Int, slot: Int, count: Int): Map<String, JsonValue>? {
        val to = newIndex(from, slot, count) ?: return null
        return mapOf("oldIndex" to JsonValue.Int(from.toLong()), "newIndex" to JsonValue.Int(to.toLong()))
    }

    /**
     * The slot item [from] is over when its dragged middle is at [centre]:
     * it has passed every other item whose middle is before [centre].
     * [spans] are the items the list has laid out, where they lie with
     * nothing dragged, in [centre]'s unit and origin; a lazy list gives
     * only the ones in view, and the items before the first of them count
     * as passed. The span of [from] itself is not needed and not counted.
     * With no other item known, the item stays ([from]).
     */
    public fun slot(spans: List<ItemSpan>, from: Int, centre: Double): Int {
        val others = spans.filter { it.index != from }
        val lowest = others.minOfOrNull { it.index } ?: return from
        val scrolledAway = if (from < lowest) lowest - 1 else lowest
        val passed = scrolledAway + others.count { it.centre < centre }
        return if (passed <= from) passed else passed + 1
    }

    /**
     * How item [index] makes room while item [from] is held over [slot]: -1
     * one dragged item's length toward the start, 1 toward the end, 0 where
     * it is. The dragged item itself is 0 (it follows the finger).
     */
    public fun displacement(index: Int, from: Int, slot: Int): Int = when {
        from < 0 || index == from -> 0
        index in (from + 1) until slot -> -1
        index in slot until from -> 1
        else -> 0
    }

    /**
     * How far to scroll the list this frame while a dragged item lies from
     * [start], [size] long, in a view from [viewportStart] to
     * [viewportEnd]: by what sticks out, [step] at most; negative toward
     * the start, 0 when the item is inside.
     */
    public fun autoScroll(start: Double, size: Double, viewportStart: Double, viewportEnd: Double, step: Double): Double {
        val before = start - viewportStart
        val after = start + size - viewportEnd
        return when {
            before < 0 -> before.coerceAtLeast(-step)
            after > 0 -> after.coerceAtMost(step)
            else -> 0.0
        }
    }
}
