#if canImport(SwiftUI) && canImport(MapKit)
import MapKit
import OrcaGateway
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// The GoogleMap widget: an MKMapView filling the box its parent gives it,
/// as Flutter's platform view does. Made at the props' camera and registered
/// under the node id; the props after that move all but the camera; removed
/// from the registry when it leaves. A tap off any marker fires onTap, a long
/// press onLongPress (once, as it begins), a tap on a marker onMarkerTap (as
/// MapKit selects it, or on the one already selected), the visible region
/// changing onCameraMove.
@MainActor
struct MapKitView {
    let id: String
    let options: GoogleMapOptions
    let maps: GoogleMaps
    /// Fires one of the node's triggers; the task ends when its action does.
    let fire: @MainActor (MapEvent) -> Task<Void, Never>?

    func makeCoordinator() -> Coordinator {
        Coordinator(id: id, maps: maps, fire: fire)
    }

    private func make(_ coordinator: Coordinator) -> MapKitSurface {
        let map = MapKitSurface()
        map.delegate = coordinator
        coordinator.listen(to: map)
        maps.create(map, id: id, options: options)
        return map
    }

    private func update(_ map: MapKitSurface, _ coordinator: Coordinator) {
        coordinator.fire = fire
        maps.update(map, options: options)
    }

    /// The map's delegate and the target of its gestures.
    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate {
        let id: String
        let maps: GoogleMaps
        var fire: @MainActor (MapEvent) -> Task<Void, Never>?

        init(id: String, maps: GoogleMaps, fire: @escaping @MainActor (MapEvent) -> Task<Void, Never>?) {
            self.id = id
            self.maps = maps
            self.fire = fire
        }

        func leave(_ map: MapKitSurface) {
            maps.leave(map, id: id)
        }

        /// The markers selected as the touch that is now a tap began. MapKit
        /// selects a marker once (didSelect); Google fires onMarkerTap on
        /// every tap, so a tap on one of these is the tap's to fire.
        private var selectedAsTouchBegan: [MarkerAnnotation] = []

        func touchBegan(on map: MKMapView) {
            selectedAsTouchBegan = map.selectedAnnotations.compactMap { $0 as? MarkerAnnotation }
        }

        /// Off any annotation view, onTap; on the pin of a marker selected
        /// before this tap, onMarkerTap; on its callout (Google's info window)
        /// nothing.
        func tapped(at point: CGPoint, on map: MapKitSurface) {
            guard let view = map.annotationView(at: point) else {
                let tapped = map.convert(point, toCoordinateFrom: map)
                _ = fire(.tap(latitude: tapped.latitude, longitude: tapped.longitude))
                return
            }
            guard let marker = view.annotation as? MarkerAnnotation,
                  selectedAsTouchBegan.contains(where: { $0 === marker }),
                  view.bounds.contains(view.convert(point, from: map)) else { return }
            _ = fire(.markerTap(id: marker.marker.id))
        }

        func longPressed(at point: CGPoint, on map: MapKitSurface) {
            let pressed = map.convert(point, toCoordinateFrom: map)
            _ = fire(.longPress(latitude: pressed.latitude, longitude: pressed.longitude))
        }

        /// A marker: a red pin with its title and snippet in a callout
        /// (MKMarkerAnnotationView takes no callout: it writes them under
        /// its balloon).
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is MarkerAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: "marker")
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: "marker")
            view.annotation = annotation
            view.image = Self.pin
            view.canShowCallout = true
            return view
        }

        #if canImport(UIKit)
        private static let pin = UIImage(
            systemName: "mappin.circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 28)
                .applying(UIImage.SymbolConfiguration(paletteColors: [.white, .systemRed])))
        #elseif canImport(AppKit)
        private static let pin = NSImage(systemSymbolName: "mappin.circle.fill", accessibilityDescription: "Marker")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 28, weight: .regular)
                .applying(NSImage.SymbolConfiguration(paletteColors: [.white, .systemRed])))
        #endif

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let marker = view.annotation as? MarkerAnnotation else { return }
            _ = fire(.markerTap(id: marker.marker.id))
        }

        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            guard let camera = (mapView as? MapKitSurface)?.movingCamera else { return }
            _ = fire(.cameraMove(camera))
        }

        #if canImport(UIKit)
        /// A tap that waits out a double tap (MapKit's zoom), as Google's
        /// onTap does, and a long press; beside MapKit's own gestures.
        func listen(to map: MapKitSurface) {
            let double = UITapGestureRecognizer()
            double.numberOfTapsRequired = 2
            let tap = UITapGestureRecognizer(target: self, action: #selector(tap(_:)))
            let press = UILongPressGestureRecognizer(target: self, action: #selector(press(_:)))
            for gesture in [double, tap, press] {
                gesture.delegate = self
                gesture.cancelsTouchesInView = false
                map.addGestureRecognizer(gesture)
            }
        }

        @objc func tap(_ gesture: UITapGestureRecognizer) {
            guard let map = gesture.view as? MapKitSurface else { return }
            tapped(at: gesture.location(in: map), on: map)
        }

        @objc func press(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began, let map = gesture.view as? MapKitSurface else { return }
            longPressed(at: gesture.location(in: map), on: map)
        }
        #elseif canImport(AppKit)
        /// A click that waits out a double click (MapKit's zoom), as Google's
        /// onTap does, and a press; beside MapKit's own gestures.
        func listen(to map: MapKitSurface) {
            let double = NSClickGestureRecognizer()
            double.numberOfClicksRequired = 2
            let tap = NSClickGestureRecognizer(target: self, action: #selector(tap(_:)))
            let press = NSPressGestureRecognizer(target: self, action: #selector(press(_:)))
            for gesture in [double, tap, press] {
                gesture.delegate = self
                gesture.delaysPrimaryMouseButtonEvents = false
                map.addGestureRecognizer(gesture)
            }
        }

        @objc func tap(_ gesture: NSClickGestureRecognizer) {
            guard let map = gesture.view as? MapKitSurface else { return }
            tapped(at: gesture.location(in: map), on: map)
        }

        @objc func press(_ gesture: NSPressGestureRecognizer) {
            guard gesture.state == .began, let map = gesture.view as? MapKitSurface else { return }
            longPressed(at: gesture.location(in: map), on: map)
        }
        #endif
    }
}

#if canImport(UIKit)
extension MapKitView: UIViewRepresentable {
    func makeUIView(context: Context) -> MapKitSurface { make(context.coordinator) }

    func updateUIView(_ map: MapKitSurface, context: Context) { update(map, context.coordinator) }

    static func dismantleUIView(_ map: MapKitSurface, coordinator: Coordinator) { coordinator.leave(map) }
}

extension MapKitView.Coordinator: UIGestureRecognizerDelegate {
    /// A touch begins: before MapKit selects anything with it.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if let map = gestureRecognizer.view as? MKMapView { touchBegan(on: map) }
        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        true
    }

    /// The single tap waits for the double tap to fail.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf other: UIGestureRecognizer
    ) -> Bool {
        (gestureRecognizer as? UITapGestureRecognizer)?.numberOfTapsRequired == 1
            && (other as? UITapGestureRecognizer)?.numberOfTapsRequired == 2 && other.delegate === self
    }
}
#elseif canImport(AppKit)
extension MapKitView: NSViewRepresentable {
    func makeNSView(context: Context) -> MapKitSurface { make(context.coordinator) }

    func updateNSView(_ map: MapKitSurface, context: Context) { update(map, context.coordinator) }

    static func dismantleNSView(_ map: MapKitSurface, coordinator: Coordinator) { coordinator.leave(map) }
}

extension MapKitView.Coordinator: NSGestureRecognizerDelegate {
    /// A click begins (its mouse down): before MapKit selects anything with it.
    func gestureRecognizer(
        _ gestureRecognizer: NSGestureRecognizer, shouldAttemptToRecognizeWith event: NSEvent
    ) -> Bool {
        if event.type == .leftMouseDown, let map = gestureRecognizer.view as? MKMapView { touchBegan(on: map) }
        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: NSGestureRecognizer, shouldRecognizeSimultaneouslyWith other: NSGestureRecognizer
    ) -> Bool {
        true
    }

    /// The single click waits for the double click to fail.
    func gestureRecognizer(
        _ gestureRecognizer: NSGestureRecognizer, shouldRequireFailureOf other: NSGestureRecognizer
    ) -> Bool {
        (gestureRecognizer as? NSClickGestureRecognizer)?.numberOfClicksRequired == 1
            && (other as? NSClickGestureRecognizer)?.numberOfClicksRequired == 2 && other.delegate === self
    }
}
#endif

/// A marker on the map: its id, and its title and snippet in the callout.
final class MarkerAnnotation: NSObject, MKAnnotation {
    let marker: MapMarker
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?

    init(_ marker: MapMarker) {
        self.marker = marker
        coordinate = CLLocationCoordinate2D(latitude: marker.latitude, longitude: marker.longitude)
        title = marker.title
        subtitle = marker.snippet
    }
}

/// The MKMapView the plugin drives. Google's zoom needs the view's size, so
/// a camera shown before the view is laid out waits for its first layout;
/// MapKit fits a region inside the view's safe area, so the span is that
/// area's.
final class MapKitSurface: MKMapView, MapSurface {
    private var pending: MapCamera?
    /// Placing a camera without animation is not a move.
    private var placing = false

    var markerAnnotations: [MarkerAnnotation] { annotations.compactMap { $0 as? MarkerAnnotation } }

    func show(_ camera: MapCamera, animated: Bool) {
        guard bounds.width > 0, bounds.height > 0 else {
            pending = camera
            return
        }
        pending = nil
        let insets = safeAreaInsets
        let safe = CGSize(width: bounds.width - insets.left - insets.right,
                          height: bounds.height - insets.top - insets.bottom)
        var span = GoogleZoom.span(zoom: camera.zoom, latitude: camera.latitude,
                                   size: safe.width > 0 && safe.height > 0 ? safe : bounds.size)
        // MapKit raises on a span wider than the world.
        span.latitudeDelta = min(span.latitudeDelta, 180)
        span.longitudeDelta = min(span.longitudeDelta, 360)
        placing = !animated
        setRegion(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: camera.latitude, longitude: camera.longitude), span: span),
                  animated: animated)
        placing = false
    }

    func apply(_ options: GoogleMapOptions) {
        if mapType != options.mapType.mapKit { mapType = options.mapType.mapKit }
        if showsUserLocation != options.myLocationEnabled { showsUserLocation = options.myLocationEnabled }
        let shown = markerAnnotations
        let wanted = Set(options.markers)
        removeAnnotations(shown.filter { !wanted.contains($0.marker) })
        let kept = Set(shown.map(\.marker))
        addAnnotations(options.markers.filter { !kept.contains($0) }.map(MarkerAnnotation.init))
    }

    /// The camera now, in Google's terms; nil until it is placed and while it
    /// is placed.
    var movingCamera: MapCamera? {
        guard !placing, pending == nil, bounds.width > 0 else { return nil }
        return MapCamera(
            latitude: region.center.latitude, longitude: region.center.longitude,
            zoom: GoogleZoom.zoom(longitudeDelta: region.span.longitudeDelta, width: Double(bounds.width)))
    }

    /// The annotation view at `point`, if any: its pin, or the callout MapKit
    /// puts in it.
    func annotationView(at point: CGPoint) -> MKAnnotationView? {
        #if canImport(UIKit)
        var view = hitTest(point, with: nil)
        #elseif canImport(AppKit)
        var view = superview.flatMap { hitTest(convert(point, to: $0)) }
        #endif
        while let current = view {
            if let pin = current as? MKAnnotationView { return pin }
            view = current.superview
        }
        return nil
    }

    #if canImport(UIKit)
    override func layoutSubviews() {
        super.layoutSubviews()
        if let pending { show(pending, animated: false) }
    }
    #elseif canImport(AppKit)
    override func layout() {
        super.layout()
        if let pending { show(pending, animated: false) }
    }
    #endif
}
#endif
