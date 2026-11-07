package com.orcagateway.sdk.client

import android.graphics.Bitmap
import android.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asAndroidBitmap
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.async
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.yield
import okhttp3.mockwebserver.Dispatcher
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.RecordedRequest
import okhttp3.mockwebserver.SocketPolicy
import okio.Buffer
import org.junit.After
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.GraphicsMode
import java.io.ByteArrayOutputStream
import java.net.InetAddress
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertSame

/**
 * I1: the image loader against a MockWebServer on 127.0.0.1, serving a 2x2
 * red PNG made here. Robolectric's native graphics decode real bytes (the
 * legacy shadows hand back a bitmap for anything), so garbage is garbage.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ImageLoaderTest {
    private val server = MockWebServer().apply { start(InetAddress.getByName("127.0.0.1"), 0) }

    @After
    fun stop() = server.shutdown()

    private val png: ByteArray by lazy {
        val bitmap = Bitmap.createBitmap(2, 2, Bitmap.Config.ARGB_8888).apply { eraseColor(Color.RED) }
        ByteArrayOutputStream().also { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }.toByteArray()
    }

    private fun image() = MockResponse().setBody(Buffer().write(png))

    private fun url(path: String) = server.url(path).toString()

    private fun assertRedSquare(image: ImageBitmap?) {
        val bitmap = assertNotNull(image).asAndroidBitmap()
        assertEquals(2 to 2, bitmap.width to bitmap.height)
        assertEquals(Color.RED, bitmap.getPixel(1, 1))
    }

    /** Holds every response until [release], so loads overlap. */
    private fun holdResponses(): CountDownLatch {
        val release = CountDownLatch(1)
        server.dispatcher = object : Dispatcher() {
            override fun dispatch(request: RecordedRequest): MockResponse {
                release.await(5, TimeUnit.SECONDS)
                return image()
            }
        }
        return release
    }

    @Test
    fun i1_aUrlIsFetchedOnceAndTheNextLoadComesFromMemory() = runTest {
        server.enqueue(image())
        val loader = ImageLoader()
        val first = loader.load(url("/a.png"))
        assertRedSquare(first)
        assertSame(first, loader.load(url("/a.png")))
        assertEquals(1, server.requestCount)
    }

    @Test
    fun i1_concurrentLoadsOfOneUrlShareOneRequest() = runTest {
        val release = holdResponses()
        val loader = ImageLoader()
        val loads = List(3) { async { loader.load(url("/a.png")) } }
        yield() // the loads start and wait on the request
        assertNotNull(server.takeRequest(5, TimeUnit.SECONDS))
        release.countDown()
        val images = loads.map { it.await() }
        images.forEach { assertSame(images.first(), it) }
        assertRedSquare(images.first())
        assertEquals(1, server.requestCount)
    }

    @Test
    fun i1_anHttpErrorGivesNullAndIsNotCached() = runTest {
        server.enqueue(MockResponse().setResponseCode(404))
        server.enqueue(image())
        val loader = ImageLoader()
        assertNull(loader.load(url("/a.png")))
        assertRedSquare(loader.load(url("/a.png")))
        assertEquals(2, server.requestCount)
    }

    @Test
    fun i1_anUndecodableBodyGivesNullAndIsNotCached() = runTest {
        server.enqueue(MockResponse().setBody("not an image"))
        server.enqueue(image())
        val loader = ImageLoader()
        assertNull(loader.load(url("/a.png")))
        assertRedSquare(loader.load(url("/a.png")))
        assertEquals(2, server.requestCount)
    }

    @Test
    fun i1_anIoFailureGivesNullAndIsNotCached() = runTest {
        server.enqueue(image().setSocketPolicy(SocketPolicy.DISCONNECT_DURING_RESPONSE_BODY))
        server.enqueue(image())
        val loader = ImageLoader()
        assertNull(loader.load(url("/a.png")))
        assertRedSquare(loader.load(url("/a.png")))
        assertEquals(2, server.requestCount)
    }

    @Test
    fun i1_onlyHttpAndHttpsUrlsAreFetched() = runTest {
        server.enqueue(image())
        val loader = ImageLoader()
        assertNull(loader.load("file:///sdcard/a.png"))
        assertNull(loader.load("ftp://127.0.0.1:${server.port}/a.png"))
        assertNull(loader.load("logo.png"))
        assertEquals(0, server.requestCount)
        assertRedSquare(loader.load(url("/a.png")))
    }

    @Test
    fun i1_aCancelledCallerRethrowsAndTheOthersStillGetTheImage() = runTest {
        val release = holdResponses()
        val loader = ImageLoader()
        var cancelledCallerWentOn = false
        val cancelled = async {
            loader.load(url("/a.png"))
            cancelledCallerWentOn = true
        }
        val other = async { loader.load(url("/a.png")) }
        yield() // the loads start and wait on the request
        assertNotNull(server.takeRequest(5, TimeUnit.SECONDS))
        cancelled.cancel()
        release.countDown()
        assertRedSquare(other.await())
        assertFailsWith<CancellationException> { cancelled.await() }
        assertFalse(cancelledCallerWentOn)
        assertSame(other.await(), loader.load(url("/a.png")))
        assertEquals(1, server.requestCount)
    }

    @Test
    fun i1_theMemoryCacheIsBoundedByBytes() = runTest {
        repeat(3) { server.enqueue(image()) }
        // One 2x2 ARGB_8888 bitmap is 16 bytes: the cache holds one image.
        val loader = ImageLoader(maxBytes = 16)
        assertRedSquare(loader.load(url("/a.png")))
        assertRedSquare(loader.load(url("/b.png")))
        assertRedSquare(loader.load(url("/a.png")))
        assertEquals(3, server.requestCount)
    }
}
