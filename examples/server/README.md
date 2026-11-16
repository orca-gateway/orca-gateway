# Example Servers

Working server implementations demonstrating Orca Gateway engine features.

## Running

Start the demo server. Pick one:

a. Docker:

```bash
docker run --rm -p 8080:8080 ghcr.io/orca-gateway/demo-server:latest
```

b. Download it for Linux, Windows or macOS from
[the newest Engine release](https://github.com/orca-gateway/orca-gateway/releases?q=engine-v),
then open it. Linux: `chmod +x demo-server-linux-x64` first, then run `./demo-server-linux-x64`.
macOS: it comes as `demo-server-macos-arm64.zip`; unzip it in Finder. First start only, macOS:
System Settings › Privacy & Security › Open Anyway. Windows: More info › Run anyway.

c. From source, with Bun:

```bash
task example:dev:server
```

Ready when it prints `Orca demo server <version> on http://localhost:8080`.

To start all examples from source (server + Flutter app):

```bash
task example:dev
```

The server runs on `http://localhost:8080` by default.

## Examples

| File                  | Description                                                  |
| --------------------- | ------------------------------------------------------------ |
| `counter.ts`          | Basic counter with page state and increment/decrement actions |
| `ecommerce.ts`        | Product listing with cart, checkout flow, and server actions   |
| `animations.ts`       | Tween animations, sequences, and animated transitions         |
| `basic-actions.ts`    | Navigate, SetState, CopyToClipboard, OpenUrl, ShowSnackbar    |
| `server-actions.ts`   | Server-side action handlers with request round-trips          |
| `static-flows.ts`     | Offline-capable static flow definitions with versioning       |
| `capability-demo.ts`  | Capability negotiation and safe degradation fallbacks         |
| `custom.ts`           | Custom widget types and custom action handlers                |
| `navigation.ts`       | Config-driven navigation: initial route, tabs, a nested route, a login redirect, shared app state |
| `tabs.ts`             | Two apps, `tabs` and `tabs-server`, over the same pages. `tabs`: the SDK's own tab bar and drawer; each tab keeps its page (a counter, a scroll position, typed text), `SwitchTab`, `OpenDrawer`, the `_tabIndex` app state, routes over the tabs, a page with its own drawer, end drawer and bottom bar. `tabs-server`: the same with the tab bar and the drawer sent by the server |
| `reorder.ts`          | App `reorder`: one `ReorderableListView` of five rows. The order is a list in page state; a drop sends `oldIndex` and `newIndex` to a server action, which answers with the moved list |
| `subpage.ts`          | App `subpage`: a host page with a `SubPage` showing `detail/a`. Both have a page state `count` that do not clash, the sub-page shows a param it was sent, a server action inside it answers with a setState, and the host replaces it with `detail/b` or joins `detail/c` below it (`updateSubPage`) |
| `slivers.ts`          | App `slivers`: three tabs (`/pinned`, `/floating`, `/plain`), each one `CustomScrollView` whose first sliver is a `SliverAppBar` (pinned with `expandedHeight` 200, floating, neither with `expandedHeight` 120) over the same content: a `SliverToBoxAdapter` heading, a `SliverGrid` of 6 cells, a `SliverList` of 40 rows and a closing `SliverToBoxAdapter`. On the iOS and Android example apps, start it with `ORCA_APP_ID=slivers` |
| `saved-state.ts`      | App `saved-state`: `PersistState` and `ClearState`. A page-state count saved on the device (kept after a relaunch) or for the session (kept until the app process ends), or forgotten; an app-state visits count saved on the device; a second page to leave to and come back from |
| `orca_google_map.ts`  | Google Maps integration via the map plugin                    |
| `orca_voice_recorder.ts` | The voice recorder plugin's widget and actions, generated from its `orca_plugin.yaml`; `custom.ts`'s `/voice` page records, stops into page state and plays |
| `index.ts`            | Entry point — registers all examples into a single engine     |

## Settings for trying SDK features

The server reads these when it starts; restart it to change them. With Docker, pass each as
`-e NAME=value`.

| Variable | Effect |
| --- | --- |
| `ORCA_FALLBACK_POLICY` | What a client gets for a widget it lacks: `graceful` (left out, the default), `warn` (a notice) or `require` (a blocking prompt). |
| `ORCA_MIN_SDK_VERSION` | With `99.0.0`, every page of every app answers 426 and the app draws the "Update required" page. |
| `ORCA_FORCE_UPDATE` | With `1`, the `static-flows` app answers `"forceUpdate": true` on `GET /api/v1/app/static-flows/version`; an SDK started with offline mode on shows its force-update screen. |

```bash
ORCA_FALLBACK_POLICY=warn task example:dev:server      # or =require
ORCA_MIN_SDK_VERSION=99.0.0 task example:dev:server
ORCA_FORCE_UPDATE=1 task example:dev:server
```
