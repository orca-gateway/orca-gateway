package com.orcagateway.core.render

import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.state.StoreState
import com.orcagateway.core.support.TestWidgets
import com.orcagateway.core.support.obj
import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * A node under an AnimatedBuilder resolves its `tween` props by the
 * builder's progress; outside one they sit at the start (Swift's
 * AnimationProgressTests).
 */
class AnimationProgressTest {
    private fun renderer(): PageRenderer = PageRenderer(
        PageResponse(
            "p", "P",
            components = listOf(
                ComponentNode(
                    "t", "Transform", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
                    props = mapOf("transform" to obj("type" to "translate", "dx" to obj("type" to "tween", "begin" to 0, "end" to -100))),
                ),
            ),
        ),
        TestWidgets.registry(),
    )

    private fun dx(progress: Double?): Double? =
        renderer().resolve("t", StoreState(), animationProgress = progress)?.props?.get("transform")?.get("dx")?.doubleValue

    @Test
    fun tweenInsideAPlainMapFollowsTheProgress() {
        assertEquals(-25.0, dx(0.25))
        assertEquals(-100.0, dx(1.0))
    }

    @Test
    fun withoutABuilderTheTweenSitsAtItsBegin() {
        assertEquals(0.0, dx(null))
    }
}
