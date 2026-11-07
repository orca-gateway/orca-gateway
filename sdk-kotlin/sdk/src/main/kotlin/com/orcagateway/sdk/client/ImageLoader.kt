package com.orcagateway.sdk.client

import android.graphics.BitmapFactory
import android.util.LruCache
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.asImageBitmap
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.IOException

/**
 * Network images for the Image widget and an Icon's `src`: fetched over
 * OkHttp and decoded with [BitmapFactory] off the main thread, then kept in
 * memory by URL, in an LRU bounded by the bitmaps' bytes, so a page that
 * shows one URL many times, or again on the way back, fetches it once.
 *
 * Loads of one URL share one request while it runs. The request runs in the
 * loader's own scope, not the caller's: a caller that goes away (its
 * coroutine cancelled) gets its CancellationException and leaves the load to
 * the others and to the cache. A failure (no response, an HTTP error status,
 * a body that is not an image) is `null` and is not kept: the next load of
 * that URL tries again. Only http and https URLs are fetched; anything else
 * is `null`.
 *
 * Use [shared]: one [OkHttpClient] (its connection pool and threads) and one
 * cache for the app, as OkHttp advises.
 */
internal class ImageLoader(
    private val client: OkHttpClient = OkHttpClient(),
    maxBytes: Int = defaultMaxBytes(),
) {
    private val cache = object : LruCache<String, ImageBitmap>(maxBytes) {
        override fun sizeOf(key: String, value: ImageBitmap): Int = value.asAndroidBitmap().byteCount
    }

    /** The loads running now, by URL; guarded by itself. */
    private val inFlight = HashMap<String, Deferred<ImageBitmap?>>()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    /**
     * The image at [url]: from memory, or from one request shared with any
     * other load of it; `null` when it cannot be had.
     */
    suspend fun load(url: String): ImageBitmap? {
        val httpUrl = url.toHttpUrlOrNull() ?: return null
        val running = synchronized(inFlight) {
            cache.get(url)?.let { return it }
            inFlight.getOrPut(url) { scope.async { fetch(url, httpUrl) } }
        }
        return running.await()
    }

    /**
     * One request and its decode. A success goes into the cache before the
     * load leaves [inFlight] (which waits for [load] to have put it there), so
     * a later load finds one or the other.
     */
    private fun fetch(key: String, url: HttpUrl): ImageBitmap? = try {
        download(url)?.let { BitmapFactory.decodeByteArray(it, 0, it.size) }
            ?.asImageBitmap()
            ?.also { cache.put(key, it) }
    } finally {
        synchronized(inFlight) { inFlight.remove(key) }
    }

    /** The body of a 2xx response, or `null` for another status or no response. */
    private fun download(url: HttpUrl): ByteArray? = try {
        client.newCall(Request.Builder().url(url).build()).execute().use { response ->
            if (response.isSuccessful) response.body?.bytes() else null
        }
    } catch (_: IOException) {
        null
    }

    companion object {
        /** The app's loader, for the Image widget and an Icon's `src`. */
        val shared: ImageLoader by lazy { ImageLoader() }

        /** An eighth of the heap, as Android's bitmap caching guide suggests. */
        private fun defaultMaxBytes(): Int =
            (Runtime.getRuntime().maxMemory() / 8).coerceAtMost(Int.MAX_VALUE.toLong()).toInt()
    }
}
