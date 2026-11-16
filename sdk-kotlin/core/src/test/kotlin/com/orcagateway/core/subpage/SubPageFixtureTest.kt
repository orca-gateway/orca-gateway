package com.orcagateway.core.subpage

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.support.Fixtures
import com.orcagateway.core.support.assertJsonEqual
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.fail

/**
 * schema/fixtures/subpage through the pure Kotlin core ([SubPage], [SubPageMounts]), as the Flutter runner
 * (sdk/test/conformance/subpage_fixtures_test.dart) runs them through `sub_page_core.dart`. The contract is the
 * oracle of this family: every file and every case runs, an unknown kind fails, and the number of files and of
 * cases is pinned so nothing is skipped in silence.
 */
class SubPageFixtureTest {
    /** B13.4-K: ids, children, slots, state references, state keys, node ids and seeds (files 01 to 06). */
    @Test
    fun b13_4_mergeFixtures() {
        assertEquals(Counts(6, 17), runFiles("merge"))
    }

    /** B13.4-K: the actions a server returns to a sub-page (file 07). */
    @Test
    fun b13_4_actionRewriteFixtures() {
        assertEquals(Counts(1, 9), runFiles("actions"))
    }

    /** B13.4-K: the fetch (path and query) and the posted page state (files 08 and 09). */
    @Test
    fun b13_4_requestFixtures() {
        assertEquals(Counts(2, 35), runFiles("request"))
    }

    /** B13.5-K: mount, replace and join, step by step (files 10 to 12). */
    @Test
    fun b13_5_sequenceFixtures() {
        assertEquals(Counts(3, 11), runFiles("sequence"))
    }

    /** B13.4-K, B13.5-K: all 12 files and all 72 cases pass, every kind among them, none unknown. */
    @Test
    fun b13_4_b13_5_everySubPageFixturePasses() {
        val files = Fixtures.subpageFiles()
        assertEquals(12, files.size, "subpage fixture files")
        val kinds = LinkedHashSet<String>()
        var cases = 0
        for (file in files) {
            val fixture = JsonValue.parse(file.readText())
            kinds += fixture["kind"].stringValue ?: fail("${file.name}: no kind")
            cases += runFile(file.name, fixture)
        }
        assertEquals(72, cases, "subpage fixture cases")
        assertEquals(setOf("merge", "actions", "request", "sequence"), kinds)
    }

    /** B13.4-K: an unknown kind is a failure, never a skip. */
    @Test
    fun b13_4_anUnknownKindFails() {
        val fixture = JsonValue.obj("kind" to "other", "cases" to listOf(mapOf("name" to "x")))
        val error = runCatching { runFile("x.json", fixture) }.exceptionOrNull()
        assertEquals(true, error is AssertionError, "an unknown kind must fail")
    }

    /** B13.4-K: the prefix of page 0 and of a joined page. */
    @Test
    fun b13_4_thePrefixOfPageZeroAndOfAJoinedPage() {
        assertEquals("detail:", SubPage.prefix("detail"))
        assertEquals("detail:", SubPage.prefix("detail", 0))
        assertEquals("detail#1:", SubPage.prefix("detail", 1))
        assertEquals("outer:inner#12:", SubPage.prefix("outer:inner", 12))
    }

    /** B13.4-K: numbers in the query inside the pinned range never take Kotlin's exponent form. */
    @Test
    fun b13_4_queryNumbersArePlain() {
        fun query(value: Any?) = SubPage.request("p", mapOf("n" to JsonValue.of(value))).query
        assertEquals("n=10000000", query(1e7))
        assertEquals("n=9007199254740992", query(9007199254740992.0))
        assertEquals("n=-9007199254740992", query(-9007199254740992.0))
        assertEquals("n=0.0001", query(0.0001))
        assertEquals("n=0.00012", query(0.00012))
        assertEquals("n=12345678.5", query(12345678.5))
        assertEquals("n=0", query(-0.0))
        assertEquals("n=42", query(42))
        assertEquals("p", SubPage.request("p").location)
        assertEquals("p?n=1", SubPage.request("/p", mapOf("n" to JsonValue.of(1))).location)
    }

    // ── The runner ──────────────────────────────────────────────

    private data class Counts(val files: Int, val cases: Int)

    /** Runs every file of one kind. */
    private fun runFiles(kind: String): Counts {
        var files = 0
        var cases = 0
        for (file in Fixtures.subpageFiles()) {
            val fixture = JsonValue.parse(file.readText())
            if (fixture["kind"].stringValue != kind) continue
            files++
            cases += runFile(file.name, fixture)
        }
        return Counts(files, cases)
    }

    /** Runs every case of one file; gives how many ran. */
    private fun runFile(fileName: String, fixture: JsonValue): Int {
        val kind = fixture["kind"].stringValue
        val cases = fixture["cases"].arrayValue ?: fail("$fileName: no cases")
        for (c in cases) {
            val at = "$fileName · ${c["name"].stringValue}"
            when (kind) {
                "merge" -> merge(c, at)
                "actions" -> actions(c, at)
                "request" -> request(c, at)
                "sequence" -> sequence(c, at)
                else -> fail("$at: unknown kind \"$kind\"")
            }
        }
        return cases.size
    }

    private fun merge(c: JsonValue, at: String) {
        val input = c["response"].toString()
        val merged = SubPage.merge(c["prefix"].stringValue!!, c["response"])
        assertJsonEqual(JsonValue.Array(merged.nodes), c["expected"]["nodes"], "$at: nodes")
        assertJsonEqual(JsonValue.Object(merged.state), c["expected"]["state"], "$at: state")
        assertEquals(input, c["response"].toString(), "$at: the response is not changed in place")
    }

    private fun actions(c: JsonValue, at: String) {
        val rewritten = SubPage.rewriteActions(c["prefix"].stringValue!!, c["actions"].arrayValue!!)
        assertJsonEqual(JsonValue.Array(rewritten), c["expected"], at)
    }

    private fun request(c: JsonValue, at: String) {
        val expected = c["expected"]
        val fetch = c["fetch"].objectValue
        val action = c["action"].objectValue
        if (fetch != null) {
            val request = SubPage.request(fetch.getValue("pageId").stringValue!!, fetch["params"]?.objectValue)
            val path = expected["path"].stringValue!!
            val query = expected["query"].stringValue!!
            assertEquals(path, request.path, "$at: path")
            assertEquals(query, request.query, "$at: query")
            assertEquals(if (query.isEmpty()) path else "$path?$query", request.location, "$at: location")
        } else if (action != null) {
            val prefixes = action.getValue("prefixes").arrayValue!!.map { it.stringValue!! }
            val prefix = SubPage.prefixOf(prefixes, action["sourceId"]?.stringValue)
            if (expected["prefix"].isNull) assertNull(prefix, "$at: prefix") else assertEquals(expected["prefix"].stringValue, prefix, "$at: prefix")
            val posted = SubPage.postedState(prefix, action.getValue("pageState").objectValue!!)
            assertJsonEqual(JsonValue.Object(posted), expected["pageState"], "$at: pageState")
        } else {
            fail("$at: a request case has a fetch or an action")
        }
    }

    private fun sequence(c: JsonValue, at: String) {
        val mounts = SubPageMounts(c["subPageKey"].stringValue!!)
        val state = LinkedHashMap(c["pageState"].objectValue!!)
        c["steps"].arrayValue!!.forEachIndexed { i, step ->
            val op = step["op"].stringValue
            val here = "$at: step $i ($op)"
            var removed = emptyList<String>()
            when (op) {
                "set" -> state[step["key"].stringValue!!] = step["value"]
                "mount", "update" -> {
                    val mode = if (op == "mount") "replace" else step["mode"].stringValue!!
                    val change = mounts.apply(mode, step["response"], state.keys)
                    change.removedStateKeys.forEach { state.remove(it) }
                    state.putAll(change.seeds)
                    removed = change.removedNodeIds
                    // What the step adds is the merge of its response.
                    val merged = SubPage.merge(change.prefix, step["response"])
                    assertEquals(merged.nodes, change.nodes, "$here: nodes")
                    assertEquals(merged.state, change.seeds, "$here: seeds")
                }
                else -> fail("$here: unknown op")
            }
            val expected = step["expected"]
            fun strings(key: String) = expected[key].arrayValue!!.map { it.stringValue!! }
            assertEquals(strings("prefixes"), mounts.prefixes, "$here: prefixes")
            assertEquals(strings("roots"), mounts.roots, "$here: roots")
            assertEquals(strings("nodeIds"), mounts.nodeIds.sortedWith(SubPage.codePointOrder), "$here: nodeIds")
            assertEquals(strings("removedNodeIds"), removed.sortedWith(SubPage.codePointOrder), "$here: removedNodeIds")
            assertJsonEqual(JsonValue.Object(state), expected["state"], "$here: state")
        }
    }
}
