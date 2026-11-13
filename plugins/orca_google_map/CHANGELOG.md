# Changelog

## Unreleased

### Changed

- Takes `Icons` from the standalone `material_ui` package instead of the framework's Material library (`material.dart`), which Flutter 3.50 deprecates. The icons look the same: both use the `MaterialIcons` font.
- Now needs Dart 3.13 and Flutter 3.47 or later, the floor that `material_ui` 1.11.0 sets.

## 0.2.0 - 2026-05-06

### Added

- Initial release.
- `OrcaGoogleMapPlugin` registers a server-driven `GoogleMap` widget.
- Marker, polyline, and circle support.
- Camera control (move / animate) via server actions.
- Gesture events (tap, long-press, camera-idle) routed to the engine.
