package com.orcagateway.core.support

import com.orcagateway.core.json.JsonValue
import java.io.File

/**
 * Paths into the monorepo the tests read at run time (schema/fixtures), so
 * the Kotlin SDK runs exactly the files the engine, the Flutter SDK and the
 * Swift SDK run.
 */
object Fixtures {
    val repoRoot: File = File(
        System.getProperty("orca.repoRoot")
            ?: error("orca.repoRoot is not set; run the tests through Gradle"),
    )
    val schema: File = File(repoRoot, "schema")
    val render: File = File(schema, "fixtures/render")
    val actions: File = File(schema, "fixtures/actions")

    fun renderFiles(): List<File> = render.listFiles { f -> f.extension == "json" }!!.sortedBy { it.name }
    fun actionFiles(): List<File> = actions.listFiles { f -> f.extension == "json" }!!.sortedBy { it.name }

    /** A file under open-source/, as text. */
    fun text(relative: String): String = File(repoRoot, relative).readText()

    /** A JSON file under open-source/. */
    fun json(relative: String): JsonValue = JsonValue.parse(text(relative))

    /** Fixture files of one set (`render` or `actions`), sorted by name. */
    fun files(set: String): List<Pair<String, JsonValue>> {
        val dir = File(schema, "fixtures/$set")
        return dir.listFiles { f -> f.extension == "json" }!!.sortedBy { it.name }
            .map { it.name to JsonValue.parse(it.readText()) }
    }
}
