package com.orcagateway.core.support

import java.io.File

/** Paths into the monorepo the tests read at run time (schema/fixtures). */
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
}
