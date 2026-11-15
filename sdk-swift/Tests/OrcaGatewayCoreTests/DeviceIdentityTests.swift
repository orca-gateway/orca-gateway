import Foundation
import XCTest

@testable import OrcaGatewayCore

/// C15.5: a device id is created once, persists, and is sent as
/// x-orca-device-id. The header cases port sdk/test/device_id_header_test.dart
/// at the headers level.
final class DeviceIdentityTests: XCTestCase {
    func testC15_5_aDeviceIdIsCreatedOnce() {
        let store = MemoryKeyValueStore()
        let first = DeviceIdentity.resolve(store)
        let second = DeviceIdentity.resolve(store)
        XCTAssertEqual(first, second)
        XCTAssertEqual(store.string(forKey: "orca_device_id"), first)
        XCTAssertEqual(DeviceIdentity.storageKey, "orca_device_id")
    }

    func testC15_5_theIdPersistsAcrossARestart() {
        let before = MemoryKeyValueStore()
        let id = DeviceIdentity.resolve(before)
        let after = MemoryKeyValueStore(before.values)
        XCTAssertEqual(DeviceIdentity.resolve(after), id)
    }

    func testC15_5_aMissingOrEmptySavedValueGetsANewId() {
        let a = DeviceIdentity.resolve(MemoryKeyValueStore())
        let b = DeviceIdentity.resolve(MemoryKeyValueStore())
        XCTAssertNotEqual(a, b, "each fresh install gets its own id")

        let empty = MemoryKeyValueStore(["orca_device_id": ""])
        let fromEmpty = DeviceIdentity.resolve(empty)
        XCTAssertFalse(fromEmpty.isEmpty)
        XCTAssertEqual(empty.string(forKey: "orca_device_id"), fromEmpty)

        empty.set(nil, forKey: "orca_device_id")
        XCTAssertNil(empty.string(forKey: "orca_device_id"), "nil removes the value")
        let fromMissing = DeviceIdentity.resolve(empty)
        XCTAssertNotEqual(fromMissing, fromEmpty)
        XCTAssertEqual(empty.string(forKey: "orca_device_id"), fromMissing)
    }

    func testC15_5_theIdIsALowercaseUUID() {
        let id = DeviceIdentity.resolve(MemoryKeyValueStore())
        XCTAssertNotNil(UUID(uuidString: id), "\(id) is not a UUID")
        XCTAssertEqual(id, id.lowercased())
    }

    func testC15_5_theClientSendsItAsXOrcaDeviceId() {
        let id = DeviceIdentity.resolve(MemoryKeyValueStore())
        let url = URL(string: "http://localhost:8080")!
        XCTAssertEqual(OrcaClient(baseURL: url, appId: "testapp", deviceId: id).headers["x-orca-device-id"], id)
        XCTAssertNil(OrcaClient(baseURL: url, appId: "testapp").headers["x-orca-device-id"])
        XCTAssertNil(OrcaClient(baseURL: url, appId: "testapp", deviceId: "").headers["x-orca-device-id"])
    }

    /// Dart: absent before setDeviceId, present after, with the given value.
    func testC15_5_theHeaderIsAbsentBeforeTheIdIsSetAndPresentAfter() {
        var client = OrcaClient(baseURL: URL(string: "http://localhost:8080")!, appId: "testapp")
        XCTAssertNil(client.headers["x-orca-device-id"], "no id until OrcaApp resolves one")
        client.deviceId = "vendor-abc-123"
        XCTAssertEqual(client.headers["x-orca-device-id"], "vendor-abc-123")
    }

    /// Dart: setDeviceId(null) clears the header again.
    func testC15_5_clearingTheIdDropsTheHeader() {
        var client = OrcaClient(baseURL: URL(string: "http://localhost:8080")!, appId: "testapp")
        client.deviceId = "vendor-xyz"
        XCTAssertEqual(client.headers["x-orca-device-id"], "vendor-xyz")
        client.deviceId = nil
        XCTAssertNil(client.headers["x-orca-device-id"], "clearing the id drops the header")
    }
}
