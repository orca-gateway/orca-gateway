#if canImport(SwiftUI) && canImport(MapKit)
import CoreGraphics
import Foundation
import MapKit
import OrcaGateway

/// A map on screen as the plugin drives it: MapKitSurface on MapKit, a fake
/// in the tests.
@MainActor
protocol MapSurface: AnyObject {
    /// Shows `camera`: animated for moveCamera, not for the initial camera.
    func show(_ camera: MapCamera, animated: Bool)
    /// What follows the props: the map type, the user's location, the markers.
    func apply(_ options: GoogleMapOptions)
}

/// A GoogleMap node's props with Flutter's defaults (google_map_plugin.dart
/// :90-123). A prop of the wrong type reads as absent: its default (Flutter's
/// cast throws in the build). `zoomControlsEnabled` is not read: MapKit has no
/// zoom buttons, as google_maps_flutter_ios has none.
struct GoogleMapOptions: Equatable {
    /// Flutter's initialCameraPosition: read when the map is made, not after.
    var camera = MapCamera(latitude: 0, longitude: 0, zoom: 14)
    var mapType = GoogleMapType.normal
    var myLocationEnabled = false
    var markers: [MapMarker] = []
}

extension GoogleMapOptions {
    init(_ node: ResolvedNode) {
        let props = GoogleMapProps(node)
        self.init(
            camera: MapCamera(latitude: props.latitude ?? 0, longitude: props.longitude ?? 0, zoom: props.zoom ?? 14),
            mapType: GoogleMapType(rawValue: props.mapType ?? "") ?? .normal,
            myLocationEnabled: props.myLocationEnabled ?? false,
            markers: MapMarker.read(props.markers))
    }
}

/// Flutter's MapType; any other string is normal.
enum GoogleMapType: String {
    case normal, satellite, terrain, hybrid

    /// MapKit has no relief map: terrain draws the standard one.
    var mapKit: MKMapType {
        switch self {
        case .normal, .terrain: return .standard
        case .satellite: return .satellite
        case .hybrid: return .hybrid
        }
    }
}

/// Google's latitude and longitude as its LatLng keeps them: the latitude
/// clamped to -90...90, the longitude into -180..<180.
private func latLng(_ latitude: Double, _ longitude: Double) -> (Double, Double) {
    let wrapped = (longitude + 180).truncatingRemainder(dividingBy: 360)
    return (min(max(latitude, -90), 90),
            longitude >= -180 && longitude < 180 ? longitude : (wrapped < 0 ? wrapped + 360 : wrapped) - 180)
}

/// Google's camera: a centre and a zoom (the world 256 * 2^zoom points wide).
struct MapCamera: Equatable {
    let latitude: Double
    let longitude: Double
    let zoom: Double

    init(latitude: Double, longitude: Double, zoom: Double) {
        (self.latitude, self.longitude) = latLng(latitude, longitude)
        self.zoom = zoom
    }
}

/// One of the markers prop's entries, read as Flutter reads it.
struct MapMarker: Hashable {
    let id: String
    let latitude: Double
    let longitude: Double
    let title: String
    let snippet: String?

    init(id: String, latitude: Double, longitude: Double, title: String, snippet: String?) {
        self.id = id
        (self.latitude, self.longitude) = latLng(latitude, longitude)
        self.title = title
        self.snippet = snippet
    }

    /// An entry that is not an object, or without both a latitude and a
    /// longitude (a number each), is skipped; the id is the Dart toString of
    /// the entry's (absent: ""), the title "" when absent, the snippet none.
    /// One marker per id, the last: google_maps_flutter keys them by id.
    static func read(_ raw: JSONValue?) -> [MapMarker] {
        var markers: [MapMarker] = []
        for entry in raw?.arrayValue ?? [] {
            guard entry.objectValue != nil, let latitude = entry["latitude"].doubleValue,
                  let longitude = entry["longitude"].doubleValue else { continue }
            let id = entry["id"].isNull ? "" : DartFormat.string(entry["id"])
            markers.removeAll { $0.id == id }
            markers.append(MapMarker(id: id, latitude: latitude, longitude: longitude,
                                     title: entry["title"].stringValue ?? "", snippet: entry["snippet"].stringValue))
        }
        return markers
    }
}

/// What the user did on the map, and the trigger Flutter fires for it.
enum MapEvent: Equatable {
    case tap(latitude: Double, longitude: Double)
    case longPress(latitude: Double, longitude: Double)
    case cameraMove(MapCamera)
    case markerTap(id: String)

    var trigger: String {
        switch self {
        case .tap: return GoogleMapProps.Triggers.onTap
        case .longPress: return GoogleMapProps.Triggers.onLongPress
        case .cameraMove: return GoogleMapProps.Triggers.onCameraMove
        case .markerTap: return GoogleMapProps.Triggers.onMarkerTap
        }
    }

    var eventData: [String: JSONValue] {
        switch self {
        case let .tap(latitude, longitude), let .longPress(latitude, longitude):
            return ["latitude": .double(latitude), "longitude": .double(longitude)]
        case let .cameraMove(camera):
            return ["latitude": .double(camera.latitude), "longitude": .double(camera.longitude),
                    "zoom": .double(camera.zoom)]
        case let .markerTap(id):
            return ["markerId": .string(id)]
        }
    }
}

/// Google's zoom against MapKit's span. At zoom z the world is 256 * 2^z
/// points wide, so a view w points wide spans 360 * w / (256 * 2^z) degrees
/// of longitude; its height spans the latitudes h / 2 points above and below
/// the centre's on the Mercator map.
enum GoogleZoom {
    static func span(zoom: Double, latitude: Double, size: CGSize) -> MKCoordinateSpan {
        let world = 256 * pow(2, zoom)
        // Mercator y, 2π around the world; the map ends at ±85.0511°.
        let phi = min(max(latitude, -85.05112878), 85.05112878) * .pi / 180
        let y = log(tan(.pi / 4 + phi / 2))
        let half = Double(size.height) / 2 / world * 2 * .pi
        func degrees(_ y: Double) -> Double { (2 * atan(exp(y)) - .pi / 2) * 180 / .pi }
        return MKCoordinateSpan(latitudeDelta: degrees(y + half) - degrees(y - half),
                                longitudeDelta: 360 * Double(size.width) / world)
    }

    static func zoom(longitudeDelta: Double, width: Double) -> Double {
        log2(360 * width / (256 * longitudeDelta))
    }
}
#endif
