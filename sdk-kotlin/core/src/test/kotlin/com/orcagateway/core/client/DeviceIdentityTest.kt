package com.orcagateway.core.client

import com.orcagateway.core.support.Fixtures
import com.orcagateway.core.support.StubEngine
import com.orcagateway.core.support.runSuspend
import java.net.URI
import java.util.UUID
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * C15.5 on the Kotlin core: a device id is created once, persists, and is
 * sent as `x-orca-device-id`. The header cases port
 * sdk/test/device_id_header_test.dart at the level of the client's headers
 * and the request it sends.
 */
class DeviceIdentityTest {
    private val base = URI("http://localhost:8080")

    private fun counterPage(): ByteArray = Fixtures.text("sdk-swift/Tests/Pages/counter-home.json").encodeToByteArray()

    @Test
    fun c15_5_resolveTwiceOverOneStoreGivesOneId() {
        val store = MemoryKeyValueStore()
        val first = DeviceIdentity.resolve(store)
        assertEquals(first, DeviceIdentity.resolve(store))
        assertEquals(first, store.getString(DeviceIdentity.STORAGE_KEY))
        assertEquals("orca_device_id", DeviceIdentity.STORAGE_KEY)
    }

    @Test
    fun c15_5_aRestartOverTheSameSavedContentsKeepsTheId() {
        val before = MemoryKeyValueStore()
        val id = DeviceIdentity.resolve(before)
        val after = MemoryKeyValueStore(before.snapshot())
        assertEquals(id, DeviceIdentity.resolve(after))
        assertEquals(mapOf("orca_device_id" to id), after.snapshot())
    }

    @Test
    fun c15_5_aSavedIdIsKeptAsGiven() {
        val store = MemoryKeyValueStore(mapOf("orca_device_id" to "saved-id"))
        assertEquals("saved-id", DeviceIdentity.resolve(store))
    }

    @Test
    fun c15_5_aMissingOrEmptySavedValueGetsANewId() {
        val empty = MemoryKeyValueStore(mapOf("orca_device_id" to ""))
        val fromEmpty = DeviceIdentity.resolve(empty)
        assertTrue(fromEmpty.isNotEmpty())
        assertEquals(fromEmpty, empty.getString("orca_device_id"))

        val missing = MemoryKeyValueStore(mapOf("other" to "x"))
        val fromMissing = DeviceIdentity.resolve(missing)
        assertNotEquals(fromEmpty, fromMissing)
        assertEquals(mapOf("other" to "x", "orca_device_id" to fromMissing), missing.snapshot())

        missing.putString("orca_device_id", null)
        assertNull(missing.getString("orca_device_id"))
        assertNotEquals(fromMissing, DeviceIdentity.resolve(missing))
    }

    @Test
    fun c15_5_theIdIsALowercaseUuid() {
        val id = DeviceIdentity.resolve(MemoryKeyValueStore())
        assertTrue(Regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$").matches(id), id)
        assertEquals(id, UUID.fromString(id).toString())
    }

    /** Dart: absent before setDeviceId, present after, with the given value. */
    @Test
    fun c15_5_theHeaderIsAbsentWithoutAnIdAndCarriesTheResolvedOne() = runSuspend {
        val stub = StubEngine(counterPage())
        val without = OrcaClient(base, "counter", transport = stub)
        assertNull(without.headers["x-orca-device-id"])
        without.fetchPage("home")
        assertNull(stub.requests.last().headers["x-orca-device-id"])

        val id = DeviceIdentity.resolve(MemoryKeyValueStore())
        val withId = OrcaClient(base, "counter", deviceId = id, transport = stub)
        assertEquals(id, withId.headers["x-orca-device-id"])
        withId.fetchPage("home")
        assertEquals(id, stub.requests.last().headers["x-orca-device-id"])
    }

    /** Dart: setDeviceId(null) clears the header again; an empty id is not sent either. */
    @Test
    fun c15_5_clearingTheIdDropsTheHeader() {
        val id = DeviceIdentity.resolve(MemoryKeyValueStore())
        val withId = OrcaClient(base, "counter", deviceId = id, transport = StubEngine(ByteArray(0)))
        assertEquals(id, withId.headers["x-orca-device-id"])
        assertNull(withId.copy(deviceId = null).headers["x-orca-device-id"])
        assertNull(withId.copy(deviceId = "").headers["x-orca-device-id"])
    }
}
