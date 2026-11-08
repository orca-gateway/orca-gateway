package com.orcagateway.core.json

import kotlinx.serialization.DeserializationStrategy
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import kotlinx.serialization.SerializationStrategy
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonEncoder
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.serializer

/**
 * A JSON value as it travels on the wire: props, state, Value payloads.
 *
 * Numbers keep the int/double split Dart's `jsonDecode` makes: an integer
 * literal that fits 64 bits decodes to [Int], anything else (a fraction, an
 * exponent, a bigger integer) to [Double], so `3.0` and `1e2` stay doubles
 * and print as "3.0" and "100.0". Equality follows Dart's `==`: numbers
 * by value (`3 == 3.0`, IEEE comparison for doubles), strings by UTF-16 code
 * units, arrays and objects deeply.
 *
 * The cases are named after Swift's `JSONValue` (`.int`, `.double`, ...), so
 * inside this class `Int`, `Double` and `String` mean the nested cases.
 */
@Serializable(with = JsonValueSerializer::class)
public sealed class JsonValue {
    public data object Null : JsonValue()

    public data class Bool(public val value: Boolean) : JsonValue()

    /** A 64-bit integer (Swift's `Int`, Dart's `int` on the VM). */
    public class Int(public val value: Long) : JsonValue() {
        override fun equals(other: Any?): Boolean = when (other) {
            is Int -> value == other.value
            is Double -> value.toDouble() == other.value
            else -> false
        }

        override fun hashCode(): kotlin.Int = numberHash(value.toDouble())
    }

    public class Double(public val value: kotlin.Double) : JsonValue() {
        override fun equals(other: Any?): Boolean = when (other) {
            is Double -> value == other.value
            is Int -> value == other.value.toDouble()
            else -> false
        }

        override fun hashCode(): kotlin.Int = numberHash(value)
    }

    /**
     * Equal to another string with the same UTF-16 code units, as Dart's
     * `String ==` ("é" precomposed differs from "e" + U+0301; Swift's
     * `String ==` would call them equal).
     */
    public data class String(public val value: kotlin.String) : JsonValue()

    public data class Array(public val items: List<JsonValue>) : JsonValue()

    public data class Object(public val members: Map<kotlin.String, JsonValue>) : JsonValue()

    // MARK: Accessors

    public val isNull: Boolean get() = this is Null

    public val stringValue: kotlin.String? get() = (this as? String)?.value

    public val boolValue: Boolean? get() = (this as? Bool)?.value

    public val intValue: Long? get() = (this as? Int)?.value

    /** The value as a Double when it is any number ([Int] or [Double]). */
    public val doubleValue: kotlin.Double?
        get() = when (this) {
            is Int -> value.toDouble()
            is Double -> value
            else -> null
        }

    /**
     * Dart's `(x as num?)?.toInt()`: truncates a double toward zero, clamping
     * to the Long range; null for non-numbers, NaN and infinity (where Dart
     * throws).
     */
    public val dartInt: Long?
        get() = when (this) {
            is Int -> value
            is Double -> when {
                !value.isFinite() -> null
                value >= 9.223372036854775807e18 -> Long.MAX_VALUE
                value <= -9.223372036854775808e18 -> Long.MIN_VALUE
                else -> value.toLong()
            }
            else -> null
        }

    public val isNumber: Boolean get() = this is Int || this is Double

    public val arrayValue: List<JsonValue>? get() = (this as? Array)?.items

    public val objectValue: Map<kotlin.String, JsonValue>? get() = (this as? Object)?.members

    /**
     * Object member lookup; [Null] when absent or when this is not an object,
     * like a Dart `map[key]` on a `Map<String, dynamic>`.
     */
    public operator fun get(key: kotlin.String): JsonValue = (this as? Object)?.members?.get(key) ?: Null

    // MARK: Encoding

    /**
     * This value as a kotlinx tree. Throws [SerializationException] for NaN
     * and infinity, as Swift's JSONEncoder does.
     */
    public fun toJsonElement(): JsonElement = toElement(sorted = false)

    /** Compact JSON with sorted keys, so the output is stable across runs. */
    public fun encoded(): kotlin.String = toElement(sorted = true).toString()

    /**
     * Decode a model from this tree, as Swift's `json.decode(T.self)`: the
     * tree is written out and read back first, so a non-finite number fails.
     */
    public fun <T> decode(deserializer: DeserializationStrategy<T>): T =
        Json.decodeFromJsonElement(deserializer, toJsonElement())

    private fun toElement(sorted: Boolean): JsonElement = when (this) {
        Null -> JsonNull
        is Bool -> JsonPrimitive(value)
        is Int -> JsonPrimitive(value)
        is Double -> {
            if (!value.isFinite()) throw SerializationException("Unable to encode $value directly in JSON")
            JsonPrimitive(value)
        }
        is String -> JsonPrimitive(value)
        is Array -> JsonArray(items.map { it.toElement(sorted) })
        is Object -> {
            val keys = if (sorted) members.keys.sortedWith(SwiftText.stringOrder) else members.keys
            JsonObject(keys.associateWith { members.getValue(it).toElement(sorted) })
        }
    }

    /** Compact JSON with sorted keys; NaN and infinity print as Kotlin does. */
    final override fun toString(): kotlin.String = buildString { render(this@JsonValue, this) }

    public companion object {
        /** Decode any JSON document (object, array or scalar). */
        public fun parse(text: kotlin.String): JsonValue = fromJsonElement(Json.parseToJsonElement(text))

        /** Decode any JSON document from UTF-8 bytes. */
        public fun parse(bytes: ByteArray): JsonValue = parse(bytes.toString(Charsets.UTF_8))

        /** Read a kotlinx tree; numbers follow the int/double rule above. */
        public fun fromJsonElement(element: JsonElement): JsonValue = when (element) {
            is JsonNull -> Null
            is JsonPrimitive -> when {
                element.isString -> String(element.content)
                element.content == "true" -> Bool(true)
                element.content == "false" -> Bool(false)
                else -> parseNumber(element.content)
            }
            is JsonArray -> Array(element.map { fromJsonElement(it) })
            is JsonObject -> Object(element.mapValues { fromJsonElement(it.value) })
        }

        /**
         * Re-read a model as a JsonValue tree (Swift `JSONValue(encoding:)`),
         * through its JSON form; a Double field stays a double.
         */
        public fun <T> encoding(serializer: SerializationStrategy<T>, value: T): JsonValue =
            fromJsonElement(Json.encodeToJsonElement(serializer, value))

        /**
         * A Kotlin value as JSON: null, Boolean, Int/Long/Short/Byte,
         * Double/Float, String, a Map with String keys, an Iterable or Array,
         * or a JsonValue. Anything else throws [IllegalArgumentException].
         */
        public fun of(value: Any?): JsonValue = when (value) {
            null -> Null
            is JsonValue -> value
            is Boolean -> Bool(value)
            is Long -> Int(value)
            is kotlin.Int -> Int(value.toLong())
            is Short -> Int(value.toLong())
            is Byte -> Int(value.toLong())
            is kotlin.Double -> Double(value)
            is Float -> Double(value.toDouble())
            is kotlin.String -> String(value)
            is Map<*, *> -> Object(
                value.entries.associate { (k, v) ->
                    (k as? kotlin.String ?: throw IllegalArgumentException("JSON keys are strings, not $k")) to of(v)
                },
            )
            is Iterable<*> -> Array(value.map { of(it) })
            is kotlin.Array<*> -> Array(value.map { of(it) })
            else -> throw IllegalArgumentException("Not a JSON value: ${value::class.qualifiedName}")
        }

        /** An object from pairs, each value converted with [of]. */
        public fun obj(vararg members: Pair<kotlin.String, Any?>): JsonValue =
            Object(members.associate { (k, v) -> k to of(v) })

        /** An array of items, each converted with [of]. */
        public fun arr(vararg items: Any?): JsonValue = Array(items.map { of(it) })

        /**
         * Dart `jsonDecode`'s reading of a number: an integer literal that
         * fits Int64 is an int (`-0` too); everything else, `4.0`, `1e2` and
         * an integer past Int64 included, a double. A number beyond the Double
         * range fails.
         */
        internal fun parseNumber(text: kotlin.String): JsonValue {
            if (isIntegerLiteral(text)) text.toLongOrNull()?.let { return Int(it) }
            val d = text.toDoubleOrNull() ?: throw SerializationException("Not a JSON number: $text")
            if (d.isInfinite()) throw SerializationException("Number $text does not fit in a Double")
            return Double(d)
        }

        private fun isIntegerLiteral(text: kotlin.String): Boolean {
            val digits = if (text.startsWith("-")) text.substring(1) else text
            return digits.isNotEmpty() && digits.all { it in '0'..'9' }
        }

        /** Equal numbers hash alike, whichever case holds them (0.0 and -0.0 too). */
        private fun numberHash(d: kotlin.Double): kotlin.Int = if (d == 0.0) 0 else d.hashCode()

        private fun render(value: JsonValue, out: StringBuilder) {
            when (value) {
                Null -> out.append("null")
                is Bool -> out.append(value.value)
                is Int -> out.append(value.value)
                is Double -> out.append(value.value)
                is String -> out.append(JsonPrimitive(value.value).toString())
                is Array -> {
                    out.append('[')
                    value.items.forEachIndexed { i, item ->
                        if (i > 0) out.append(',')
                        render(item, out)
                    }
                    out.append(']')
                }
                is Object -> {
                    out.append('{')
                    value.members.keys.sortedWith(SwiftText.stringOrder).forEachIndexed { i, key ->
                        if (i > 0) out.append(',')
                        out.append(JsonPrimitive(key).toString()).append(':')
                        render(value.members.getValue(key), out)
                    }
                    out.append('}')
                }
            }
        }
    }
}

/** Decode a model from this tree (see [JsonValue.decode]). */
public inline fun <reified T> JsonValue.decode(): T = decode(serializer<T>())

/** A model as a JsonValue tree (see [JsonValue.Companion.encoding]). */
public inline fun <reified T> JsonValue.Companion.encoding(value: T): JsonValue = encoding(serializer<T>(), value)

/**
 * Reads and writes [JsonValue] through the Json format's tree, so it works
 * only with kotlinx `Json`.
 */
public object JsonValueSerializer : KSerializer<JsonValue> {
    override val descriptor: SerialDescriptor =
        SerialDescriptor("com.orcagateway.core.json.JsonValue", JsonElement.serializer().descriptor)

    override fun serialize(encoder: Encoder, value: JsonValue) {
        val json = encoder as? JsonEncoder ?: throw SerializationException("JsonValue can only be written as JSON")
        json.encodeJsonElement(value.toJsonElement())
    }

    override fun deserialize(decoder: Decoder): JsonValue {
        val json = decoder as? JsonDecoder ?: throw SerializationException("JsonValue can only be read from JSON")
        return JsonValue.fromJsonElement(json.decodeJsonElement())
    }
}
