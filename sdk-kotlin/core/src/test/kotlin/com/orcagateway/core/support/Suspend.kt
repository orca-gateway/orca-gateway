package com.orcagateway.core.support

import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference
import kotlin.coroutines.Continuation
import kotlin.coroutines.EmptyCoroutineContext
import kotlin.coroutines.startCoroutine
import kotlin.test.fail

/**
 * Run a suspending test body to completion on this thread (Swift's
 * `async` test methods), with the stdlib only. Everything the core does
 * finishes without suspending when no real network is involved.
 */
fun <T> runSuspend(block: suspend () -> T): T {
    val result = AtomicReference<Result<T>>()
    val done = CountDownLatch(1)
    block.startCoroutine(
        Continuation(EmptyCoroutineContext) {
            result.set(it)
            done.countDown()
        },
    )
    if (!done.await(10, TimeUnit.SECONDS)) fail("suspending test body did not finish")
    return result.get().getOrThrow()
}
