package com.orcagateway.core.models

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.json.JsonValueSerializer
import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerializationException
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonElement

/**
 * A model's serializer written by hand over the JSON tree: no reflection, and
 * the same field rules as Swift's Codable (see [Fields]).
 */
internal abstract class JsonTreeSerializer<T>(serialName: String) : KSerializer<T> {
    override val descriptor: SerialDescriptor = SerialDescriptor(serialName, JsonElement.serializer().descriptor)

    abstract fun toTree(value: T): JsonValue

    /** Reads a tree as Swift's JSONDecoder sees it (integral doubles already ints). */
    abstract fun fromTree(tree: JsonValue): T

    override fun serialize(encoder: Encoder, value: T) = JsonValueSerializer.serialize(encoder, toTree(value))

    override fun deserialize(decoder: Decoder): T = fromTree(JsonValueSerializer.deserialize(decoder))
}

/**
 * Keyed reads with Swift Codable's rules: a required key must be present (a
 * JSON null is a value for a `JsonValue` field and an error for any other
 * type); an optional key reads absent and null alike as null; a value of the
 * wrong type is an error either way.
 */
internal class Fields private constructor(private val members: Map<String, JsonValue>, private val owner: String) {
    private fun required(key: String): JsonValue =
        members[key] ?: throw SerializationException("$owner: key '$key' not found")

    private fun present(key: String): JsonValue? = members[key]?.takeUnless { it.isNull }

    private fun mismatch(key: String, expected: String, got: JsonValue): Nothing =
        throw SerializationException("$owner.$key: expected $expected, got $got")

    fun json(key: String): JsonValue = required(key)

    fun jsonOrNull(key: String): JsonValue? = present(key)

    fun string(key: String): String = required(key).let { it.stringValue ?: mismatch(key, "a string", it) }

    fun stringOrNull(key: String): String? = present(key)?.let { it.stringValue ?: mismatch(key, "a string", it) }

    fun long(key: String): Long = required(key).let { it.intValue ?: mismatch(key, "an integer", it) }

    fun longOrNull(key: String): Long? = present(key)?.let { it.intValue ?: mismatch(key, "an integer", it) }

    fun double(key: String): Double = required(key).let { it.doubleValue ?: mismatch(key, "a number", it) }

    fun doubleOrNull(key: String): Double? = present(key)?.let { it.doubleValue ?: mismatch(key, "a number", it) }

    fun boolOrNull(key: String): Boolean? = present(key)?.let { it.boolValue ?: mismatch(key, "a boolean", it) }

    fun obj(key: String): Map<String, JsonValue> = required(key).let { it.objectValue ?: mismatch(key, "an object", it) }

    fun objOrNull(key: String): Map<String, JsonValue>? =
        present(key)?.let { it.objectValue ?: mismatch(key, "an object", it) }

    fun strings(key: String): List<String> = required(key).let { v ->
        (v.arrayValue ?: mismatch(key, "an array", v)).map { it.stringValue ?: mismatch(key, "strings", v) }
    }

    fun <T> decode(key: String, read: (JsonValue) -> T): T = read(required(key))

    fun <T> decodeOrNull(key: String, read: (JsonValue) -> T): T? = present(key)?.let(read)

    fun <T> list(key: String, read: (JsonValue) -> T): List<T> = required(key).let { v ->
        (v.arrayValue ?: mismatch(key, "an array", v)).map(read)
    }

    fun <T> listOrNull(key: String, read: (JsonValue) -> T): List<T>? = present(key)?.let { v ->
        (v.arrayValue ?: mismatch(key, "an array", v)).map(read)
    }

    fun <T> mapOrNull(key: String, read: (JsonValue) -> T): Map<String, T>? = present(key)?.let { v ->
        (v.objectValue ?: mismatch(key, "an object", v)).mapValues { read(it.value) }
    }

    companion object {
        fun of(tree: JsonValue, owner: String): Fields =
            Fields(tree.objectValue ?: throw SerializationException("$owner: expected an object, got $tree"), owner)
    }
}

/** Builds an object in key order, leaving out optional fields that are null. */
internal class TreeBuilder {
    private val members = LinkedHashMap<String, JsonValue>()

    fun put(key: String, value: JsonValue) {
        members[key] = value
    }

    fun put(key: String, value: String) = put(key, JsonValue.String(value))

    fun put(key: String, value: Long) = put(key, JsonValue.Int(value))

    fun putIfPresent(key: String, value: JsonValue?) {
        if (value != null) members[key] = value
    }

    fun putIfPresent(key: String, value: String?) {
        if (value != null) members[key] = JsonValue.String(value)
    }

    fun putIfPresent(key: String, value: Long?) {
        if (value != null) members[key] = JsonValue.Int(value)
    }

    fun putIfPresent(key: String, value: Double?) {
        if (value != null) members[key] = JsonValue.Double(value)
    }

    fun putIfPresent(key: String, value: Boolean?) {
        if (value != null) members[key] = JsonValue.Bool(value)
    }

    fun putIfPresent(key: String, value: Map<String, JsonValue>?) {
        if (value != null) members[key] = JsonValue.Object(value)
    }

    fun build(): JsonValue = JsonValue.Object(members)
}

internal inline fun tree(build: TreeBuilder.() -> Unit): JsonValue = TreeBuilder().apply(build).build()
