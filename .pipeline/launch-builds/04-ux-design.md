# 04 · UX design · launch-builds

## Front page

### In one breath
A Todo page that looks the same in the Flutter, iOS and Android example apps: type, tap Add, tap
the dot to tick, tap the cross to delete. A Todo tile in the Flutter selector, README step 1 starts
the demo server by Docker, download or Bun, each engine tag gets a full GitHub release page, and
release.sh gets one notes check. Five screens.

### New for you
nothing new

### Trade-offs
iOS and Android draw no check box and have no empty-ring icon: "not done" is a grey dot (q2).

### Questions for you
1. Where does the Todo tile go in the Flutter selector? (default: second, under Counter; a
   checklist icon; subtitle "Add, tick and delete items, kept in server memory")
2. What marks a todo not done? (default: a light grey dot; done is a green check with grey,
   struck-through text; the mark is the tap area. The other way: an empty ring added to both SDKs)
3. Where does the README's download link go? GitHub's "Latest" release is DevTools. (default: the
   Releases page filtered to engine tags, `/releases?q=engine-v`, as "the newest Engine release")
4. What leads the release notes? (default: the 6-line "Run the demo server" block, then the
   engine/CHANGELOG.md section for the tag)
5. In what order does README step 1 list the ways to start? (default: Docker, download, Bun from
   source, then one line "Ready when it prints ...")

## Appendix

Drawn by the `ui-sketcher` agent from 02 (with its gate-03 edits), 03 and both persona files; trimmed here.
Checked against the repo: `circle`, `check_circle`, `close` and `delete` are in both native icon tables
(sdk-swift `IconNames.swift`, sdk-kotlin `IconNames.kt`), with no empty ring; both draw `lineThrough` text; both
draw GestureDetector and TextField; engine/CHANGELOG.md 0.3.3 lists Checkbox, FloatingActionButton, InkWell and
SnackBar as not drawn on iOS; `gh release list` shows "DevTools devtools-v0.2.1+1" as Latest.

### Wireframes

1. Todo page, the same in all three apps: with items (left), and empty on first open or after a server restart.
```
┌──────────────────────────┐  ┌──────────────────────────┐
│ Todo                     │  │ Todo                     │
├──────────────────────────┤  ├──────────────────────────┤
│ ┌──────────────────┐┌───┐│  │ ┌──────────────────┐┌───┐│
│ │ New todo         ││Add││  │ │ New todo         ││Add││
│ └──────────────────┘└───┘│  │ └──────────────────┘└───┘│
│ ┌──────────────────────┐ │  │                          │
│ │ ●  Buy milk        × │ │  │                          │
│ ├──────────────────────┤ │  │    Nothing to do yet.    │
│ │ ✓  ~Call Sam~      × │ │  │    Add one above.        │
│ ├──────────────────────┤ │  │                          │
│ │ ●  Book the train  × │ │  │                          │
│ │    to Leeds          │ │  │                          │
│ └──────────────────────┘ │  │                          │
│                          │  │                          │
│ Kept on the server until │  │ Kept on the server until │
│ it stops.                │  │ it stops.                │
└──────────────────────────┘  └──────────────────────────┘
 ● grey dot, tap: done    ✓ green, tap: not done
 × tap: delete    ~text~ grey and struck through
```

2. Flutter app selector: one new tile, second in the list. The iOS and Android apps have no selector.
```
┌──────────────────────────────────────┐
│        Orca Gateway Examples         │
├──────────────────────────────────────┤
│ ┌──────────────────────────────────┐ │
│ │ (+)  Counter                   › │ │
│ │      Basic state management with │ │
│ │      increment/decrement         │ │
│ └──────────────────────────────────┘ │
│ ┌──────────────────────────────────┐ │
│ │ [✓]  Todo                      › │ │ ◄ NEW
│ │      Add, tick and delete items, │ │
│ │      kept in server memory       │ │
│ └──────────────────────────────────┘ │
│ ┌──────────────────────────────────┐ │
│ │ (•)  Basic Actions             › │ │
│ │      Navigation, snackbars, ...  │ │
│ └──────────────────────────────────┘ │
│   Server Actions and 6 more,         │
│   unchanged                          │
└──────────────────────────────────────┘
```

3. Step 1 of the app, app-ios and app-android READMEs; examples/server/README.md opens with the same block.
```
## Run it
1. Start the demo server. Pick one:                ◄ NEW
   a. Docker:
   ┌───────────────────────────────────────────┐
   │ docker run --rm -p 8080:8080 \            │
   │   ghcr.io/orca-gateway/demo-server:latest │
   └───────────────────────────────────────────┘
   b. Download it for Linux, Windows or macOS from
      the newest Engine release, then open it.
      First start only. macOS: System Settings ›
      Privacy & Security › Open Anyway.
      Windows: More info › Run anyway.
   c. From source, with Bun: task example:dev:server
   Ready when it prints "Orca demo server on
   http://localhost:8080".
2. (unchanged: open the app and run it)

## Other example apps   (app-ios and app-android only)
| Todo  | todo | home | add, tick, delete |  ◄ NEW row
```

4. The GitHub release page an engine tag creates. Developer and maintainer see the same page (plus Edit for you).
```
┌──────────────────────────────────────────────────────────┐
│ Engine 0.3.5                                             │
│ engine-v0.3.5 · github-actions released this             │
├──────────────────────────────────────────────────────────┤
│ Run the demo server                                      │
│   docker run --rm -p 8080:8080 \                         │
│     ghcr.io/orca-gateway/demo-server:0.3.5               │
│   or download yours below and open it. First start:      │
│   macOS: Privacy & Security › Open Anyway.               │
│   Windows: More info › Run anyway.                       │
│ ──────────────────────────────────────────────────────── │
│ ### Added                  (from engine/CHANGELOG.md)    │
│ - Todo example on the demo server: add, tick, delete.    │
├──────────────────────────────────────────────────────────┤
│ ▾ Assets 5                                               │
│   demo-server-linux-x64                                  │
│   demo-server-windows-x64.exe                            │
│   demo-server-macos-arm64.zip                            │
│   Source code (zip)    Source code (tar.gz)              │
└──────────────────────────────────────────────────────────┘
```

5. scripts/release.sh as the maintainer sees it: one new check after the bump choice, and the stop without notes.
```
$ scripts/release.sh
  1) engine 0.3.4   2) sdk ...   (10 packages)
Select: 1
  ok npm, registry.npmjs.org as <you>
engine 0.3.4  [M]ajor/[m]inor/[P]atch [P]: ⏎
  ok notes, engine/CHANGELOG.md "## 0.3.5"      ◄ NEW
Summary
  engine  0.3.4 -> 0.3.5
          then a GitHub release: notes,         ◄ NEW
          demo image, 3 downloads
Proceed? [y/N] y

── when that section is missing ──────────────────
engine 0.3.4  [M]ajor/[m]inor/[P]atch [P]: ⏎
  stop: engine/CHANGELOG.md has no "## 0.3.5"   ◄ NEW
        section. Write it, merge it, run again.
        Nothing was changed.
```

### Flow per persona
Steps are the stops between "open" and "done".
- trying-developer (Flutter, Docker): open examples/app/README.md → paste the `docker run` line → run the Flutter
  app → tap the Todo tile → type "Buy milk", tap Add → tap the dot, then × → done. 5 steps, 5 taps, 2 commands.
- trying-developer (iOS, macOS download): open examples/app-ios/README.md → download demo-server-macos-arm64.zip
  from the newest Engine release, unzip, open it → System Settings › Privacy & Security › Open Anyway, open it
  again → in Xcode set ORCA_APP_ID=todo and ORCA_PATH=home in the scheme, Run → add "Buy milk", tick it, delete
  it → done. 4 steps, about 21 clicks (4 download and open, 7 first start, 6 Xcode, 4 Todo).
- trying-developer (Android, Docker): open examples/app-android/README.md → paste the `docker run` line → start
  an emulator → `task example:android:run APP=todo PAGE=home` → add, tick, delete → done. 4 steps, 4 taps,
  2 commands.
- maintainer: open engine/CHANGELOG.md → write the "## 0.3.5" section and merge it → run scripts/release.sh,
  answer 1, ⏎ (Patch), y → wait for the tag's run (npm, image, downloads, release, then the Todo check) → open
  Releases and see Engine 0.3.5 with its notes and 3 downloads → done. 4 steps, 4 taps (3 answers, 1 click).

### Left out on purpose
- No editing, filters, item count, clear-done, reordering, swipe-to-delete or due dates: the server change does
  not need them, and each adds state that could drift between the three apps.
- No floating "+" button and no "Added"/"Deleted" snackbar: iOS draws neither (engine/CHANGELOG.md 0.3.3). The tick
  and the × are GestureDetector tap areas, not InkWell.
- No delete confirmation and no undo: the list is a demo kept in memory; a dialog is one more widget for all three.
- No selector in the iOS and Android apps (02): the Todo is one more row in their "Other example apps" table.
- No new "server not running" screen: the apps keep their current error, and "Ready when it prints ..." heads it off.
- No checksums file, signed downloads, arm64 image or releases for past tags (02, out of scope). No drawing of the
  GHCR package page: GitHub draws it.
- The release page does not show the post-release check's result; it lives in Actions.

### Open UX decisions
- Release title "Engine 0.3.5" (DevTools releases read "DevTools devtools-v0.2.1+1").
- Image tag: `:latest` in the READMEs so they never go stale; the exact version in the release notes.
- Downloads: macOS ships as a .zip (a bare program a browser downloads loses its run permission; a Finder-unzipped
  one keeps it); Linux a bare file, its line adds `chmod +x`; Windows a bare .exe.
- The downloads listen on this computer only, so Windows shows nothing beyond SmartScreen; the emulator and the
  simulator still reach it; phones on Wi-Fi are out of scope.
- Docker on Apple-silicon Macs: no `--platform` flag in the run line for now; stage 10's try decides (02's risk).
- Startup line "Orca demo server 0.3.5 on http://localhost:8080", then the app list with todo in it.
- New todos go at the bottom; done items stay where they are.
- A blank Add does nothing and shows nothing; text is trimmed and the field clears after an add.
- Long text wraps; the dot and × stay on the first line.
- Keyboard return adds too, only if all three apps can send it; otherwise only the Add button adds.
- One list per server, shared by every connected app; another app sees a change when it reopens the page.
- iOS and Android keep Counter as the default; the Todo is ORCA_APP_ID=todo, ORCA_PATH=home (Android APP, PAGE).
- Delete is one tap on ×, no confirmation.
- A failed post-release check leaves the release as it is: a red run and GitHub's email; the fix is the next patch.
