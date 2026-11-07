package com.orcagateway.sdk.client

import com.orcagateway.core.client.HttpRequest
import com.sun.net.httpserver.HttpServer
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Before
import org.junit.Test
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.net.InetSocketAddress
import java.net.URI
import java.util.zip.GZIPOutputStream
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

/**
 * The OkHttp transport against the JDK's own HTTP server on a loopback port
 * the OS picks: what goes out (method, headers, body) and what comes back
 * (status, lowercased headers, gzip decoded). Plain JVM, no Robolectric.
 */
class OkHttpTransportTest {
    private lateinit var server: HttpServer
    private val seen = mutableListOf<Triple<String, Map<String, String>, ByteArray>>()

    @Before
    fun start() {
        server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
        server.createContext("/") { exchange ->
            val headers = exchange.requestHeaders.entries.associate { it.key.lowercase() to it.value.joinToString(",") }
            seen += Triple(exchange.requestMethod, headers, exchange.requestBody.readBytes())
            when (exchange.requestURI.path) {
                "/caps" -> {
                    val body = """{"error":"caps_vector_unknown"}""".toByteArray()
                    exchange.responseHeaders.add("Content-Type", "application/json")
                    exchange.responseHeaders.add("X-Orca-Trace", "t1")
                    exchange.sendResponseHeaders(412, body.size.toLong())
                    exchange.responseBody.use { it.write(body) }
                }
                "/gzip" -> {
                    val zipped = ByteArrayOutputStream().also { out -> GZIPOutputStream(out).use { it.write("hello".toByteArray()) } }
                    exchange.responseHeaders.add("Content-Encoding", "gzip")
                    exchange.sendResponseHeaders(200, zipped.size().toLong())
                    exchange.responseBody.use { it.write(zipped.toByteArray()) }
                }
                else -> {
                    exchange.sendResponseHeaders(204, -1)
                    exchange.close()
                }
            }
        }
        server.start()
    }

    @After
    fun stop() = server.stop(0)

    private fun url(path: String) = URI("http://127.0.0.1:${server.address.port}$path")

    @Test
    fun aStatusAboveFourHundredIsAResponseWithLowercasedHeaders() = runTest {
        val response = OkHttpTransport().send(
            HttpRequest("GET", url("/caps"), mapOf("x-orca-caps-hash" to "abc", "x-orca-platform" to "Android")),
        )
        assertEquals(412, response.status)
        assertEquals("caps_vector_unknown", response.errorField)
        assertEquals("t1", response.headers["x-orca-trace"])
        assertEquals("application/json", response.headers["content-type"])
        val (method, headers) = seen.single()
        assertEquals("GET", method)
        assertEquals("abc", headers["x-orca-caps-hash"])
        assertEquals("Android", headers["x-orca-platform"])
    }

    @Test
    fun aPostCarriesItsBodyAndContentType() = runTest {
        val body = """{"_orcaCapsVector":{}}""".toByteArray()
        val response = OkHttpTransport().send(
            HttpRequest("POST", url("/page"), mapOf("content-type" to "application/json"), body),
        )
        assertEquals(204, response.status)
        val (method, headers, received) = seen.single()
        assertEquals("POST", method)
        // The client's own header goes out as it set it.
        assertEquals("application/json", headers["content-type"])
        assertContentEquals(body, received)
    }

    @Test
    fun aGzipBodyArrivesDecoded() = runTest {
        val response = OkHttpTransport().send(HttpRequest("GET", url("/gzip")))
        assertEquals("hello", response.body.decodeToString())
    }

    @Test
    fun noResponseThrows() = runTest {
        val port = server.address.port
        server.stop(0)
        assertFailsWith<IOException> {
            OkHttpTransport().send(HttpRequest("GET", URI("http://127.0.0.1:$port/")))
        }
        start()
    }
}
