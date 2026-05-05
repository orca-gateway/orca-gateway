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

## License

BUSL-1.1 — see [LICENSE](LICENSE).
