package com.orcagateway.sdk.client

import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import kotlinx.coroutines.suspendCancellableCoroutine
import okhttp3.Call
import okhttp3.Callback
import okhttp3.Headers.Companion.toHeaders
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import java.io.IOException
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * The production [HttpTransport]: OkHttp, asynchronous, cancellable. OkHttp
 * asks for gzip and decodes it itself, as the engine compresses when asked.
 * Every status is a response; only a failure to get one (no network, DNS,
 * timeout) throws, as an [IOException].
 *
 * Share one [OkHttpClient] across the app (its connection pool and threads);
 * pass yours to reuse an existing one.
 */
public class OkHttpTransport(private val http: OkHttpClient = OkHttpClient()) : HttpTransport {
    override suspend fun send(request: HttpRequest): HttpResponse {
        val contentType = request.headers.entries.firstOrNull { it.key.equals("content-type", ignoreCase = true) }?.value
        val body = request.body?.toRequestBody(contentType?.toMediaTypeOrNull())
            ?: if (request.method == "POST" || request.method == "PUT") ByteArray(0).toRequestBody() else null
        val call = http.newCall(
            Request.Builder()
                .url(request.url.toString())
                .headers(request.headers.toHeaders())
                .method(request.method, body)
                .build(),
        )
        return suspendCancellableCoroutine { continuation ->
            continuation.invokeOnCancellation { call.cancel() }
            call.enqueue(
                object : Callback {
                    override fun onFailure(call: Call, e: IOException) {
                        if (continuation.isActive) continuation.resumeWithException(e)
                    }

                    override fun onResponse(call: Call, response: Response) {
                        val result = response.use {
                            try {
                                HttpResponse(
                                    status = it.code,
                                    headers = it.headers.associate { (name, value) -> name.lowercase() to value },
                                    body = it.body?.bytes() ?: ByteArray(0),
                                )
                            } catch (e: IOException) {
                                if (continuation.isActive) continuation.resumeWithException(e)
                                return
                            }
                        }
                        continuation.resume(result)
                    }
                },
            )
        }
    }
}
