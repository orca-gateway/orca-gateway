package com.orcagateway.core.support

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.json.decode
import com.orcagateway.core.json.encoding
import kotlin.test.fail

/** Swift's JSON literals: a Kotlin value as JSON (see [JsonValue.of]). */
fun j(value: Any?): JsonValue = JsonValue.of(value)

/** `["k": v, ...]` */
fun obj(vararg members: Pair<String, Any?>): JsonValue = JsonValue.obj(*members)

/** `[a, b, ...]` */
fun arr(vararg items: Any?): JsonValue = JsonValue.arr(*items)

/** A string-keyed map of JSON values, for props, state and params. */
fun props(vararg members: Pair<String, Any?>): Map<String, JsonValue> = members.associate { (k, v) -> k to j(v) }

/** Encode a model and read it back as JSON, for JSON-equal checks. */
inline fun <reified T> jsonOf(value: T): JsonValue = JsonValue.encoding(value)

inline fun <reified T> decodeModel(json: JsonValue): T = json.decode()

/** JSON-equal with a readable failure: both sides printed with sorted keys. */
fun assertJsonEqual(actual: JsonValue, expected: JsonValue, message: String = "") {
    if (actual == expected) return
    fail("$message\n  actual:   $actual\n  expected: $expected")
}
