package com.orcagateway.sdk.widgets

import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.constrainHeight
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.style.BoxDecorationProps
import com.orcagateway.sdk.style.Props

/**
 * Flutter's `Table` as the Flutter SDK's builder makes it
 * (layout_builders.dart:646-666): each child its own one-cell row of a
 * single `FlexColumnWidth(1)` column, top-aligned. The column is the
 * parent's maximum width; with none (a horizontal scroll) a flex column has
 * no width of its own and takes the minimum, 0 there
 * (rendering/table.dart `_computeColumnWidths`). Each child is laid out at
 * exactly that width and its own height, the rows stacked from the top; no
 * children is the minimum size. `columnWidths` and `defaultColumnWidth`
 * are never read, as Flutter's builder does not. `border` sent is
 * `TableBorder.all(color ?? black, width ?? 1)`, painted over the cells
 * ([drawTableBorder]); it changes no layout.
 */
@Composable
internal fun TableWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val border = node["border"]?.objectValue?.let { b ->
        BoxDecorationProps.Border(color = Props.color(b["color"]) ?: Color.Black, width = Props.number(b["width"]) ?: 1.0)
    }
    // The rows' top edges and the last one's bottom, from the placement to the border's drawing.
    val rowTops = remember { mutableStateOf(emptyList<Int>()) }
    val drawn = if (border == null) modifier else modifier.drawWithContent {
        drawContent()
        drawTableBorder(border, rowTops)
    }
    Layout(content = { for (id in node.childIds) NodeView(id, model) }, modifier = drawn) { measurables, constraints ->
        if (measurables.isEmpty()) return@Layout layout(constraints.minWidth, constraints.minHeight) { rowTops.value = emptyList() }
        val width = if (constraints.hasBoundedWidth) constraints.maxWidth else constraints.minWidth
        val placeables = measurables.map { it.measure(Constraints.fixedWidth(width)) }
        val tops = placeables.runningFold(0) { top, placeable -> top + placeable.height }
        layout(width, constraints.constrainHeight(tops.last())) {
            rowTops.value = tops
            placeables.forEachIndexed { index, placeable -> placeable.place(0, tops[index]) }
        }
    }
}

/**
 * Flutter's `TableBorder.paint` for one column over rows whose edges are
 * [rowTops]: the lines between rows first, stroked [border]'s width
 * centred on each boundary across the table, then the outer lines filling
 * that width inside the rows' rect (Flutter's `paintBorder`), a hairline
 * on the edges at width 0.
 */
private fun DrawScope.drawTableBorder(border: BoxDecorationProps.Border, rowTops: MutableState<List<Int>>) {
    val tops = rowTops.value
    if (tops.size < 2) return
    val stroke = Props.lengthOf(border.width).toPx()
    val rect = Rect(0f, 0f, size.width, tops.last().toFloat())
    for (top in tops.subList(1, tops.size - 1)) {
        drawLine(border.color, Offset(0f, top.toFloat()), Offset(rect.right, top.toFloat()), strokeWidth = stroke)
    }
    if (stroke == 0f) {
        drawRect(border.color, rect.topLeft, rect.size, style = Stroke(0f))
        return
    }
    val inner = rect.deflate(stroke)
    val ring = Path().apply {
        fillType = PathFillType.EvenOdd
        addRect(rect)
        if (inner.width > 0f && inner.height > 0f) addRect(inner)
    }
    drawPath(ring, border.color)
}
