package com.orcagateway.core

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.NavConfig
import com.orcagateway.core.support.Fixtures
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class FixturePathsTest {
    @Test
    fun theConformanceFixturesAreReachable() {
        assertEquals(56, Fixtures.renderFiles().size)
        assertEquals(32, Fixtures.actionFiles().size)
    }

    /** B9.1-CK: the navigation fixture family is reachable, all 15 files of it (11 of cases, 3 of sessions, 1 of links). */
    @Test
    fun b9_1_ck_theNavigationFixturesAreReachable() {
        assertEquals(15, Fixtures.navigationFiles().size)
    }

    /** B13.4-K: the SubPage fixture family is reachable, all 12 files of it. */
    @Test
    fun b13_4_theSubPageFixturesAreReachable() {
        assertEquals(12, Fixtures.subpageFiles().size)
    }

    /** B9.1-CK: the `config` of every navigation fixture is a real /config body and decodes. */
    @Test
    fun b9_1_ck_everyNavigationFixtureConfigDecodesIntoNavConfig() {
        for (file in Fixtures.navigationFiles()) {
            val raw = JsonValue.parse(file.readText())["config"]
            val config = NavConfig.fromJson(raw)
            assertEquals(raw, config.raw, file.name)
            assertEquals(raw["initialRoute"].stringValue, config.initialRoute, file.name)
            assertEquals(raw["flows"].arrayValue.orEmpty().size, config.flows.size, file.name)
            assertEquals(raw["tabs"].arrayValue.orEmpty().size, config.tabs.size, file.name)
            assertEquals(raw["drawerItems"].arrayValue.orEmpty().size, config.drawerItems.size, file.name)
            assertEquals(raw["initialAppState"].objectValue.orEmpty(), config.initialAppState, file.name)
            assertTrue(config.flows.all { it.routes.isNotEmpty() }, file.name)
        }
    }
}
