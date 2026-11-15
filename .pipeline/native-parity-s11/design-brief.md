# Design brief · native-parity-s11 · deep links

Source: plan step 11, rows B11.1 to B11.4, and a read of the Flutter SDK (go_router 16.3) on 2026-11-16.

## 1. What Flutter does (the oracle)

1. API: `OrcaApp(onDeeplink: (OrcaDeeplinkEvent) -> void)`; `OrcaDeeplinkEvent { Uri incoming, String resolvedLocation,
   Map pathParameters, Map queryParameters, bool wasRedirected, bool isColdStart }` (`sdk/lib/src/navigation/deeplink_event.dart`).
   No scheme, host or prefix option. Links navigate with or without the callback.
2. The SDK does not listen itself: Flutter's engine hands the link to go_router. Cold start on Android: the link replaces
   the config's `initialRoute`. Warm: a `go`.
3. Matching is on the URL's path only (scheme and host ignored, case-sensitive, empty path is "/", a trailing slash is
   dropped). `app://product/42` has host `product` and path `/42`. Query kept.
4. A link is always a `go`, never a push. No back stack is invented: parents come from the config's nested `children`
   and from the tab the route lives in (fixtures 08, 09, 12 already pin this for `go`).
5. Redirect: the asked route's rule is applied once, the asked query is dropped (fixture 04). `onDeeplink` fires once,
   after the navigation and after `onRouteChanged`; `wasRedirected` compares paths; `queryParameters` are the final ones.
6. Unknown link: go_router's default screen, "Page Not Found" with a "Go to home page" button that does `go('/')`. The
   location stays the asked one, nothing is fetched, `onDeeplink` still fires with `wasRedirected: false`.
7. Nothing in Flutter tests deep links today; the fixture schema has no link field.

Flutter quirks read from the code, not pinned by any test (we do not copy them, section 2):
(q1) `pathParameters` is always empty. (q2) On iOS a cold launch reports `isColdStart: false`. (q3) A link that arrives
during boot, before the router exists, is dropped, and `onDeeplink` then fires for the initial route with
`wasRedirected: true, isColdStart: false`. (q4) Only when the delivered string equals the location on screen character
for character: no callback, and its pending entry leaks into the next navigation (a full URL to the same route does
call back). (q5) `resolvedLocation` is the whole URL when not redirected. (q6) `wasRedirected` compares the raw path,
so a trailing slash or an empty path reads as a redirect.
q3, q4 and q6 are as observed on the real `OrcaApp` by the fixture runner (task T1), not only read from the code.

## 2. Decisions

- D1 Location of a link: path plus query, nothing else (`https://shop.example/account?tab=2#x` is `/account?tab=2`).
  Scheme, host and fragment are dropped; empty path is "/"; a trailing slash is dropped. One pure function per core.
- D2 A link is `router.navigate(location, replace: true)` (a `go`), so the stack and the tab come from the config, as
  the existing fixtures pin. Cold start: the router boots AT the link's location instead of `initialRoute`
  (`initialAppState` seeded first, redirect applied), one page request, no flash of the initial route.
- D3 Event, both SDKs: `DeeplinkEvent { incoming (URL/URI as given), resolvedLocation (final location, D1 form),
  pathParameters (the matched route's real params; differs from q1), queryParameters (final location's),
  wasRedirected (path comparison), isColdStart }`. Fired once per link, after the navigation settled and after
  `onRouteChanged`. `wasRedirected` compares the D1-normalised paths (the link's location path with the final one), so
  a trailing slash or an empty path is not a redirect and it is true only when a redirect rule ran (differs from q6).
- D4 `isColdStart` is true when the link is what opened the app: it arrived before the router showed its first route
  (Android: it is the launch Intent's data, read once and not again after a recreation; iOS: delivered before the
  first route appeared). True on iOS too (differs from q2). A link during boot is held and applied (differs from q3).
- D5 A link to the location already on screen: no navigation, the callback still fires (differs from q4).
- D6 Unknown link: the not-found route (location kept, nothing fetched), callback with `wasRedirected: false`. The
  not-found page gains Flutter's "Go to home page" button, which does a `go` to "/".
- D7 Hosts: Swift `OrcaApp` attaches `.onOpenURL` and `.onContinueUserActivity(NSUserActivityTypeBrowsingWeb)` itself;
  Kotlin `OrcaApp` reads the launch Intent and registers an `OnNewIntentListener` on the `ComponentActivity` itself.
  Both routers also expose `handleDeeplink(url)` for hosts that receive links elsewhere (the plan's `handleIntent`).
  Path mode (an explicit `path`, no config): the same, every path is a page.
- D8 Contract: the navigation fixture schema gains `links` (name, config, `link`, `coldStart`, `appState`, expected
  location / redirected / kind / stack / tabIndex / pageRequested and the event). Flutter runs them through its real
  platform channel path (`defaultRouteNameTestValue` for cold, a `pushRouteInformation` message for warm) and is
  compared on the D1 form of its location; where a quirk (q1, q4, q5, q6) makes Flutter differ, the fixture says so in a
  `flutter` override and the README lists it. Native SDKs must match `expected` exactly.

## 3. Cases

| Id | Case | Row |
|---|---|---|
| L-F | Flutter passes `15_deep_links.json` (with the documented overrides) | B11.3-F, B11.4-F |
| L1 | URL to location (D1): https, custom scheme, query, fragment, trailing slash, empty path | B11.2 |
| L2 | Warm link navigates as a go; stack and tab from the config; event after onRouteChanged, once | B11.2 |
| L3 | Protected route while logged out: redirected, asked query dropped, flags right, cold and warm | B11.3 |
| L4 | Unknown link: not-found route, nothing fetched, event not redirected; "Go to home page" goes to "/" | B11.4 |
| L5 | Cold start: router boots at the link; held during the config fetch; not handled again on recreation | B11.1 |
| L6 | Link to the current location: no navigation, callback fires | B11.2 |
| L7 | Example apps open `orcacounter://…` links (iOS URL type, Android intent filter, singleTop) | B11.1 hand |
