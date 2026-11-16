import { App, Flow, PageDefinition } from "../../engine/src/core";
import {
  Scaffold,
  AppBar,
  Column,
  Text,
  FallbackPrompt,
  Center,
  SizedBox,
  Padding,
  EdgeInsets,
  Divider,
  CustomScrollView,
  SliverToBoxAdapter,
} from "../../engine/src/components";
// Not re-exported by components/index.ts; the primitive barrel has it.
import { UnsupportedWidgetPlaceholder } from "../../engine/src/components/primitive";

// Capability negotiation demo (Epic 25b, foundation slice).
//
// Three pages, each exercising the frozen v1 `FallbackPrompt` primitive at a
// different severity. This example is the *intentional* use case for the
// widget — tenants can emit FallbackPrompt any time they want to surface an
// actionable message to the user. In later Epic 25b slices, the server will
// also emit FallbackPrompt *automatically* under the warn / require fallback
// policies (tasks 25b.3, 25b.4, 25b.6) when a client's capability vector is
// missing a feature. The visual shape is the same either way, which is the
// whole point of pinning it as a frozen contract.
//
// Note: this example cannot demonstrate the "SDK encounters unknown type →
// safe-degrades to FallbackPrompt" path (task 25b.9). The TS encoder
// validates widget types at encode time and refuses to emit unknown ones —
// correctly — so a server-side handler can never produce an unknown-type
// payload. That path is exercised by a Flutter unit test at
// sdk/test/safe_degrade_test.dart which fabricates the wire JSON
// directly and feeds it to the component renderer.

// ── /home: info-severity inline message ─────────────────────

const homePage = PageDefinition.create({
  id: "home",
  title: "Capability Demo",
  state: [],
  render: () =>
    Scaffold.new({
      appBar: AppBar.new({
        title: Text.new({ data: "Capability Demo" }),
        centerTitle: true,
      }),
      body: Padding.new({
        padding: EdgeInsets.all(16),
        child: Column.new({
          mainAxisAlignment: "start",
          crossAxisAlignment: "stretch",
          children: [
            SizedBox.new({ height: 16 }),
            FallbackPrompt.new({
              title: "New features available",
              body:
                "Version 1.1 of this app ships with a richer dashboard. You can update when convenient — the current version will keep working.",
              ctaLabel: "Learn more",
              ctaUrl: "https://example.com/whats-new",
              severity: "info",
            }),
            SizedBox.new({ height: 16 }),
            Text.new({
              data:
                "Above: an inline info-severity FallbackPrompt. This is the same widget the server will emit automatically under a 'graceful' fallback policy in Epic 25b.3.",
            }),
          ],
        }),
      }),

    }),
});

// ── /upgrade: warn-severity page banner ──────────────────────

const upgradePage = PageDefinition.create({
  id: "upgrade",
  title: "Upgrade Recommended",
  state: [],
  render: () =>
    Scaffold.new({
      appBar: AppBar.new({
        title: Text.new({ data: "Upgrade Recommended" }),
        centerTitle: true,
      }),

      body: Padding.new({
        padding: EdgeInsets.all(16),
        child: Column.new({
          children: [
            SizedBox.new({ height: 16 }),
            FallbackPrompt.new({
              title: "Update required for this feature",
              body:
                "The checkout flow on this screen uses a component that your current app version cannot render. Please update to continue checking out.",
              ctaLabel: "Open App Store",
              ctaUrl: "https://apps.apple.com/app/id000000000",
              severity: "warn",
            }),
            SizedBox.new({ height: 16 }),
            Text.new({
              data:
                "Above: a warn-severity FallbackPrompt. A tenant would emit this from a feature-gated route when they want users to upgrade but don't want to hard-block them. Later slice 25b.4 will let tenants configure the 'warn' fallback policy once per feature instead of hand-coding it.",
            }),
          ],
        }),
      }),

    }),
});

// ── /blocked: blocking-severity full-screen prompt ───────────

const blockedPage = PageDefinition.create({
  id: "blocked",
  title: "Update Required",
  state: [],
  render: () =>
    Scaffold.new({
      appBar: AppBar.new({
        title: Text.new({ data: "Update Required" }),
        centerTitle: true,
      }),
      body: Padding.new({
        padding: EdgeInsets.all(16),
        child: Center.new({
          child: FallbackPrompt.new({
            title: "This app needs an update",
            body:
              "We've improved several things that unfortunately require a newer app version. Please update from your app store to continue.",
            ctaLabel: "Update now",
            ctaUrl: "https://apps.apple.com/app/id000000000",
            severity: "blocking",
          }),
        }),
      }),
    }),
});

// ── /negotiation: live capability filtering demo (Epic 25b slice 2) ──
//
// Unlike the three pages above — which statically emit FallbackPrompt as a
// first-class widget — this page emits a real widget (Divider) and relies on
// the engine's capability filter to rewrite the tree when a client advertises
// it can't render Divider.
//
// The filter fires because examples/server/index.ts calls
// `engine.setFallbackPolicy({default: 'graceful', features: {'widget.Divider': 'warn'}})`,
// which tells the filter to wrap the tree in a warn banner whenever a client
// is missing the Divider capability. Clients that DO support Divider see the
// original tree unchanged — no filter, no banner.
//
// To actually see the warn banner on a device/curl, send a request with:
//   X-Orca-Sdk-Version: 0.0.1
//   X-Orca-Caps-Hash:  <64-char hex of a vector WITHOUT Divider>
// The first request gets 412, the retry POST carries the vector in
// _orcaCapsVector, and the server caches it. Subsequent GETs with the same
// hash hit the fast path. This is the same protocol the Flutter SDK uses
// automatically.

const negotiationPage = PageDefinition.create({
  id: "negotiation",
  title: "Live Capability Filter",
  state: [],
  render: () =>
    Scaffold.new({
      appBar: AppBar.new({
        title: Text.new({ data: "Live Capability Filter" }),
        centerTitle: true,
      }),
      body: Padding.new({
        padding: EdgeInsets.all(16),
        child: Column.new({
          crossAxisAlignment: "stretch",
          children: [
            Text.new({
              data:
                "This page authored a Divider widget below. Clients that " +
                "support Divider see it render as a thin horizontal line. " +
                "Clients whose capability vector OMITS Divider will see a " +
                "warn banner above instead (engine.setFallbackPolicy forces " +
                "the 'warn' mode for widget.Divider).",
            }),
            SizedBox.new({ height: 16 }),
            Divider.new({ thickness: 2 }),
            SizedBox.new({ height: 16 }),
            Text.new({
              data:
                "Below the Divider — this Text survives under all three " +
                "fallback modes because Text is in every SDK's vector.",
            }),
          ],
        }),
      }),
    }),
});

// ── /degrade: a widget one SDK lacks ─────────────────────────
//
// The native SDKs do not draw slivers yet, so neither the iOS nor the
// Android vector advertises CustomScrollView or SliverToBoxAdapter. Flutter
// draws the scroll view (shrinkWrap, because it sits in a Column and a bare
// sliver there throws); for the natives the engine applies the fallback
// policy: `graceful` strips both and keeps the Text they hold (the filter
// lifts a dropped node's children into its parent), `warn` prepends a banner
// naming both widgets, `require` replaces the page. examples/server/index.ts
// reads the policy from ORCA_FALLBACK_POLICY, and record-page.ts records each
// one for the Swift and Kotlin tests (`t sdk-swift:record`,
// `t sdk-kotlin:record`).

const degradePage = PageDefinition.create({
  id: "degrade",
  title: "Degrade",
  state: [],
  render: () =>
    Scaffold.new({
      appBar: AppBar.new({
        title: Text.new({ data: "Degrade" }),
        centerTitle: true,
      }),
      body: Padding.new({
        padding: EdgeInsets.all(16),
        child: Column.new({
          crossAxisAlignment: "stretch",
          children: [
            Text.new({ data: "Above the CustomScrollView." }),
            CustomScrollView.new({
              shrinkWrap: true,
              slivers: [SliverToBoxAdapter.new({ child: Text.new({ data: "Inside the CustomScrollView." }) })],
            }),
            Text.new({ data: "Below the CustomScrollView." }),
          ],
        }),
      }),
    }),
});

// ── /placeholder: the "cannot run here" card ─────────────────
//
// UnsupportedWidgetPlaceholder is the grey card for a widget the client
// knows but cannot run on its platform. Flutter web substitutes it for
// plugin widgets that have no web build; every SDK draws it when the server
// sends it, as this page does. The first card carries every prop (fixture
// 17_unsupported_widget_placeholder.json); the second only widgetType, so
// the SDK's defaults show.

const placeholderPage = PageDefinition.create({
  id: "placeholder",
  title: "Placeholder",
  state: [],
  render: () =>
    Scaffold.new({
      appBar: AppBar.new({
        title: Text.new({ data: "Placeholder" }),
        centerTitle: true,
      }),
      body: Padding.new({
        padding: EdgeInsets.all(16),
        child: Column.new({
          crossAxisAlignment: "stretch",
          children: [
            Text.new({ data: "Every prop set (fixture 17):" }),
            SizedBox.new({ height: 8 }),
            UnsupportedWidgetPlaceholder.new({
              widgetType: "OrcaGoogleMap",
              displayName: "Google Maps",
              iconName: "map",
              docsUrl: "https://docs.orcagateway.com/plugins/orca_google_map",
              reason: "Maps render in the compiled mobile app. Open on device to preview.",
            }),
            SizedBox.new({ height: 16 }),
            Text.new({ data: "Only widgetType, so the SDK's defaults show:" }),
            SizedBox.new({ height: 8 }),
            UnsupportedWidgetPlaceholder.new({ widgetType: "OrcaGoogleMap" }),
          ],
        }),
      }),
    }),
});

// ── App ──────────────────────────────────────────────────────

const demoFlow = Flow.create({
  name: "demo",
  routes: [
    { path: "home", page: homePage },
    { path: "upgrade", page: upgradePage },
    { path: "blocked", page: blockedPage },
    { path: "negotiation", page: negotiationPage },
    { path: "degrade", page: degradePage },
    { path: "placeholder", page: placeholderPage },
  ],
});

export const capabilityDemoApp = App.create({
  id: "capability-demo",
  name: "Capability Demo",
  flows: [demoFlow],
});
