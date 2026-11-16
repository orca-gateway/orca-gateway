# SubPage fixtures

The executable spec for a page embedded in a page: the `SubPage` widget and the `updateSubPage` action. Given a
page response and a prefix, which nodes and which state land in the host page; how the embedded page is
requested; what a server action fired inside it posts; what a replace and a join leave mounted. It sits beside
`render/` (what a page resolves to), `actions/` (what an action does) and `navigation/` (where a location
lands). Schema: [`../../subpage-fixture.schema.json`](../../subpage-fixture.schema.json).

## The contract is the oracle

Unlike `navigation/`, no value here is recorded from the Flutter SDK. The contract below was written first; the
expected values follow from it, and the Flutter, Swift and Kotlin SDKs are all held to them. Each SDK has a pure
core (JSON in, JSON out, no UI and no network) that its runner drives. The UI layers only fetch and draw.

## Contract

S1. **Prefix.** A SubPage node with id `K` holds a list of mounted pages. Page 0 has prefix `K:`; the j-th page
added by a join (j from 1) has prefix `K#j:`. A nested SubPage composes by itself, since its own id is already
prefixed: `outer:inner:`.

S2. **Merge** is one pure function: a prefix `P` and a page response give nodes and state seeds. It rewrites the
fields in the table below and nothing else. Seeds: each page-scoped state definition gives `P + key = initial`;
app-scoped definitions are ignored.

S3. The merged nodes live in the host page's node store (so component mutations, openDialog and animations
reach them) and the seeds in the host page's page state.

S4. **Fetch.** The normal page route, with the resolved `pageId` as the path and the resolved `params` as the
query string. On mount, and again as a replace when the resolved `pageId` or `params` change.

S5. **Drawing.** The root of each mounted page, oldest first, one below the other.

S6. **Actions fired inside a sub-page.** The source node id starts with a mounted prefix; the longest match
wins. A serverAction posts, as `pageState`, only the keys under that prefix with the prefix removed, and the
actions the server returns are rewritten with the same prefix before they run.

S7. **updateSubPage.** Mode `join` mounts the new page after the current ones under the next `K#j:`. Any other
mode replaces: the mounted pages' nodes and the sub-page's state keys are removed, the new page becomes page 0
and the join count starts again.

## What merge rewrites (normative)

`P` is the prefix. "Literal" means a JSON string: where a Value object sits in an id field, the field is not an
id and only the references inside the Value are rewritten. Every action kind of `action.schema.json` and every
prop of `widget-registry.json` was checked for this table; a field that is not listed is copied as it is.

| Where | Field | Rewritten to | Why |
|---|---|---|---|
| node | `id` | `P + id` | the node's address in the host's node store |
| node | each entry of `children` | `P + id` | child addresses |
| node `props`, top level | a string equal to one of that node's own `children` ids (`appBar`, `body`, `title`, `leading`, `action_N`, `flexibleSpace`, ...) | `P + id` | a slot: structure widgets name their slot nodes in props |
| node `props`, top level | `animationId`, literal | `P + id` | AnimatedBuilder registers its controller under this id |
| node `props`, top level | `stateKey`, literal | `P + key` | the page-state key an input is bound to (read and written by the client) |
| anywhere in `props` and in actions | state Value `{type: "state", scope: "page"}`: `key` | `P + key` | a page-state read; covers a transform's `input`, `by` and template or regex `params`, a conditional's `when`, `then` and `else`, every BoolExpr operand, values inside maps and lists, `SubPage.pageId` and `SubPage.params`, `navigate.params`, `serverAction.params`, `updateSubPage.params`, a message or a route given as a Value |
| anywhere in `props` and in actions | `tween` and `tweenSequence` Value: `animationId`, literal | `P + id` | the tween reads the progress of that controller |
| node | each entry of `watches` | `P + key` when the node's props hold a page-scoped reference with that key | `watches` carries bare keys with no scope; a key read in both scopes gives two entries, `P + key` then `key`, in the place of the one |
| action `setState` | `key` when `scope` is `page` | `P + key` | page-state write |
| action `clearState` | `key` when `scope` is `page` | `P + key` | page-state write |
| action `persistState` | `key` when `scope` is `page` | `P + key` | names the page-state key to persist |
| action `openDialog` | `dialogId`, literal | `P + id` | looked up in the node store |
| action `animateForward`, `animateReverse` | `animationId`, literal | `P + id` | the controller's id |
| action `updateComponent` | `id`, literal | `P + id` | mutation target |
| action `updateComponent` | `props` | as node props (`animationId`, `stateKey`, Values) | the new props of a node of this page; a slot cannot be recognised here, the node's children are not known |
| action `deleteComponent` | `id`, literal | `P + id` | mutation target |
| action `addComponent` | `parentId`, literal | `P + id` | mutation parent |
| action `addComponent` | each node of `components` (and `node`, the schema's name for it) | merged as a node | new nodes of this page |
| action `replaceComponent` | `targetId`, literal | `P + id` | mutation target |
| action `replaceComponent` | each node of `components` | merged as a node | new nodes of this page |
| action `updateSubPage` | `subPageId`, literal | `P + id` | the nested SubPage's node id |
| actions that hold actions | `actionGroup.actions`, `conditionalAction.branches[].then` and `else`, `lifecycle.action`, `onLoading`, `onSuccess`, `onError`, `onComplete`, `once.action`, `always.action`, any field of a custom action | walked | nested actions follow the same rules |

Left alone, on purpose: `type`, `kind`, `childMode`; an app-scoped reference or action (`scope: "app"`); the
payload of a static Value (`{type: "static", value}` is data, whatever it looks like); a Hero `tag` (a hero
flies between pages); `navigate.route`, `switchTab.tabId`, `serverAction.id`; `SubPage.pageId` and
`updateSubPage.pageId` and `mode` as literals; `info`, `request` and `event` Values; a widget written inline in
props (`ListView.separator`) apart from the references inside it. A reference or a state action with no `scope`
counts as page-scoped.

A rewritten list or map is a copy: the response and the action list passed in are not changed.

## Shapes

One `kind` per file, several cases per file, numbered in reading order. Every case is independent.

```jsonc
// kind "merge"
{ "name": "...", "prefix": "detail:",
  "response": { "pageId": "...", "title": "...", "state": [/* definitions */], "components": [/* nodes */] },
  "expected": { "nodes": [/* same order */], "state": { "detail:count": 0 } } }

// kind "actions"
{ "name": "...", "prefix": "detail:", "actions": [/* actions */], "expected": [/* same order */] }

// kind "request", a fetch
{ "name": "...", "fetch": { "pageId": "profile", "params": { "userId": "u-42" } },
  "expected": { "path": "profile", "query": "userId=u-42" } }

// kind "request", a posted page state
{ "name": "...",
  "action": { "prefixes": ["detail:", "detail#1:"], "sourceId": "detail:3", "pageState": { /* whole */ } },
  "expected": { "prefix": "detail:", "pageState": { /* what is posted */ } } }

// kind "sequence"
{ "name": "...", "subPageKey": "detail", "pageState": { /* host page state before step 0 */ },
  "steps": [
    { "op": "mount", "response": { /* page */ }, "expected": { /* below */ } },
    { "op": "update", "mode": "join", "response": { /* page */ }, "expected": { } },
    { "op": "set", "key": "detail:count", "value": 13, "expected": { } }
  ] }
// expected after each step
{ "prefixes": ["detail:", "detail#1:"],     // mounted pages, oldest first
  "roots": ["detail:0", "detail#1:0"],      // drawn roots, top to bottom
  "nodeIds": ["detail#1:0", "detail:0"],    // every node of this SubPage in the store, sorted by code point
  "removedNodeIds": [],                     // what the step took out before it put its nodes in, sorted
  "state": { }                              // the host page's whole page state
}
```

The input nodes of the `merge` and `actions` files were produced by the engine encoder from widget code, so
slots, watches and inline widgets have the shape a real page has.

## Fetch: path and query

- `path` is the resolved `pageId`, character for character. The request is `path` when the query is empty,
  else `path?query`.
- Keys are sorted by code point, which is the order of their UTF-8 bytes. A sort by UTF-16 unit differs for
  characters outside the basic plane; one case pins it.
- Keys and values are percent-encoded the same way: every UTF-8 byte except `A-Z a-z 0-9 - . _ ~` becomes
  `%XX` with upper-case hex. A space is `%20`, never `+`.
- A value is sent as text:

| Resolved value | Sent as |
|---|---|
| string | the string; an empty string gives `key=` |
| `true`, `false` | `true`, `false` |
| a whole number | its digits, no fraction and no exponent: `42`, `-7`, `3` for 3.0 |
| any other number | the shortest decimal that reads back the same: `1.5`, `0.1`, `-2.25` |
| `null` | nothing: the param is left out |
| list, map | compact JSON: no spaces, map keys sorted by code point, numbers as above, strings with only `"`, `\` and the control characters escaped (`\b \f \n \r \t`, else `\u00xx` in lower-case hex); `/` and non-ASCII characters are written as they are |

Numbers that need an exponent or more than 15 digits are outside the contract: no fixture pins them.

On the server a page reads a param from the request, as any query parameter:
`ctx.requestInfo.queryParams.userId`, or `V.request("queryParams.userId")` in a prop. A cached page must list
the param in its cache policy (`requestInfo: ["queryParams.userId"]`), or one render serves every value.

## Posted page state

`prefixes` are the prefixes of every page mounted in the host page, nested ones included. The prefix of a
source node is the longest one its id starts with. With a prefix, the posted `pageState` is every key that
starts with it, with it removed; so a page also sees the keys of the sub-pages nested in it, under their own
prefix, as a host does. Without one (a host node, the SubPage node itself, no source) the whole page state is
posted.

## Sequences

The first load (`mount`) is a replace. A step gives a change that the host applies in this order: remove the
listed nodes, remove the listed state keys, add the new nodes, write the seeds.

- Replace removes the nodes of every page mounted in this SubPage and every page-state key under `K:` or
  `K#<digits>:`, whoever wrote it. A key that only starts like that (`K`, `Kx:...`, `K#:...`, `K#x:...`,
  `K#1`) is a host key and stays. The nodes of a SubPage nested in a removed page are not listed: that SubPage
  goes away with its node and removes its own.
- Join removes nothing, so what the user wrote under an earlier page's prefix survives. A join with nothing
  mounted mounts page 0.
- Only the string `join` joins. `JOIN`, an empty string and any other mode replace.
- A page without components is mounted (it has a prefix and seeds) and has no root.

## What the files pin

| File | Kind | Behaviour |
|---|---|---|
| `01_merge_ids_children` | merge | ids and children; the `K:`, `K#1:` and nested prefix forms |
| `02_merge_slots` | merge | slot props of a Scaffold and an AppBar; a string that only looks like an id; an inline separator |
| `03_merge_state_refs` | merge | page-state references in transforms, conditions, maps, a nested SubPage's props; app scope and static payloads untouched; watches |
| `04_merge_state_keys` | merge | setState, clearState, persistState, `stateKey`, references inside nested actions and serverAction params |
| `05_merge_node_ids` | merge | animation, dialog, mutation and sub-page ids; a Value where an id goes; Hero tag untouched; a nested SubPage node |
| `06_merge_seeds` | merge | seeds of every JSON type; app scope ignored; no definitions; no components |
| `07_actions_rewrite` | actions | the actions a server returns: state, mutations with whole nodes, nested actions, an empty list |
| `08_request_fetch` | request | path and query: sorting, encoding, numbers, booleans, null, lists and maps |
| `09_request_posted_state` | request | prefix lookup and the posted page state: page 0, joined, nested, host |
| `10_sequence_mount_replace` | sequence | mount; replace; a refresh of the same page; leftovers cleared on the first load |
| `11_sequence_join` | sequence | join twice; join, replace, join; a nested SubPage's own joins |
| `12_sequence_edges` | sequence | unknown modes; join on nothing; a page with no root; host keys that look alike |

## Running it

| SDK | Runner | Command |
|---|---|---|
| Flutter | `sdk/test/conformance/subpage_fixtures_test.dart` against `sdk/lib/src/state/sub_page_core.dart` | `cd sdk && flutter test test/conformance/subpage_fixtures_test.dart` |
| Swift | the core's fixture tests, same calls | `cd sdk-swift && swift test` |
| Kotlin | the core's fixture tests, same calls | `cd sdk-kotlin && ./gradlew :core:test` |

Each runner walks up from its working directory to `schema/fixtures/subpage`, runs every file and every case,
and checks how many files it found (at least twelve, every kind among them) so an empty or missing directory
fails the build. The Flutter runner also validates every file against the schema.

The calls, which the three cores share by name:

| Call | Gives |
|---|---|
| `subPagePrefix(subPageKey, join = 0)` | `K:` or `K#j:` |
| `mergeSubPage(prefix, response)` | `nodes`, `state` (kind `merge`) |
| `rewriteSubPageActions(prefix, actions)` | the rewritten list (kind `actions`) |
| `subPageRequest(pageId, params)` | `path`, `query`, and `location` (the two joined) (kind `request`, `fetch`) |
| `subPagePrefixOf(prefixes, sourceId)` | the prefix or null (kind `request`, `action`) |
| `subPagePostedState(prefix, pageState)` | the posted page state (kind `request`, `action`) |
| `SubPageMounts(subPageKey).apply(mode, response, pageStateKeys)` | a change: `prefix`, `nodes`, `seeds`, `removedNodeIds`, `removedStateKeys`; the mounts then answer `prefixes`, `roots`, `nodeIds` (kind `sequence`) |

## Adding a fixture

Write the input and the expected output from the contract and the table above, by hand. Run the Flutter
runner, then the Swift and Kotlin ones. A difference is a bug in that core or a hole in the contract: settle
which in the contract first, then change the file or the core. Never record an SDK's output as the expectation.
