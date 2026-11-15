# orca_gateway_cli

Command-line companion for [Orca Gateway](https://github.com/orca-gateway/orca-gateway) — manages plugins, patches native config (AndroidManifest, Info.plist, Gradle, Podfile), and scaffolds new server-driven UI projects.

## Install

```sh
dart pub global activate orca_gateway_cli
```

Make sure `~/.pub-cache/bin` is on your `PATH`. The installed executable is `orca`.

## Usage

```sh
orca plugin add <name>         # add an Orca plugin to the current project
orca plugin remove <name>      # remove a plugin
orca plugin create <name>      # scaffold a new plugin package
orca plugin generate           # regenerate plugin glue code
orca plugin doctor             # validate plugin + native config wiring
orca plugin build              # build native plugin artifacts
```

Run `orca --help` or `orca plugin <command> --help` for the full flag surface.

### Native plugin stubs

`orca plugin generate` writes TypeScript types by default. Three flags make it
write a Swift or Kotlin plugin stub instead, from the same `schema:` section:

- `--lang ts|swift|kotlin` picks the output (default `ts`, unchanged). Swift
  writes `<Name>Plugin.swift` for the iOS SDK, Kotlin `<Name>Plugin.kt` for the
  Android SDK (`orca_google_map` gives `OrcaGoogleMapPlugin`): a props type per
  widget, a params type per action, and the plugin with a placeholder builder
  and a no-op handler for each, to fill in.

  ```sh
  orca plugin generate --lang swift
  ```

- `--manifest <path>` reads that one `orca_plugin.yaml`, with no `pubspec.yaml`
  needed, for native hosts. A manifest without `schema:` gives a plugin with
  only its name.

  ```sh
  orca plugin generate --lang swift --manifest ../orca_google_map/orca_plugin.yaml --output Sources/App/Plugins
  ```

- `--package <name>` sets the package of the Kotlin file (default `orca.plugins`).

  ```sh
  orca plugin generate --lang kotlin --manifest orca_plugin.yaml --package com.example.plugins
  ```

## License

BUSL-1.1 — see [LICENSE](LICENSE).
