package com.orcagateway.core

import com.orcagateway.core.support.Fixtures
import kotlin.test.Test
import kotlin.test.assertEquals

class FixturePathsTest {
    @Test
    fun theConformanceFixturesAreReachable() {
        assertEquals(38, Fixtures.renderFiles().size)
        assertEquals(15, Fixtures.actionFiles().size)
    }
}
