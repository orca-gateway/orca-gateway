# 08 · Tasks · native-parity-s19

## Front page

### In one breath
`tasks: n in g groups · widest group: k · cases: m of m placed`, then what runs in parallel
and what waits, one sentence each; a case that is not planned is named here.

### New for you
nothing new, or the one concept → learning/<topic>.md

### Trade-offs
`n needs you: <what was serialised or split, and why>` · `n auto-decided` · none

### Questions for you
1. Commands: test `<cmd>` · lint `<cmd>` · typecheck `<cmd>`, from <where>. (default: as found)
2. Commits by the plugin? (default: none; you commit)
3. One gate per group? (default: yes; `all` runs every group in one turn)
then any case or task you must place yourself, each with a default.

## Appendix

### Groups
| Group | Task | Title | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|---|
Groups run in order; the tasks of one group run in parallel and touch disjoint files. `Files` lists
every path a task may change or create; `Cases` the 07 ids it turns green; `Size` is `S` or `M`
(at most five files); `Depends on` names tasks of earlier groups only.
A plan of one-task groups is fully sequential.

### Order, and why each boundary
One line per boundary between groups: what the later group needs from the earlier one.

### Seams
A seam is a file more than one task would touch (a barrel, `package.json`, a routes table,
a migrations index); it belongs to one task in a group of its own. Each seam with its task,
or `none`.

### Done when
`test: <command>` · `lint: <command>` · `typecheck: <command>` (or `none`), then
`baseline: <summary line>` from one run before any change. Green at 09 means the task's cases
pass and nothing that passed here fails.

### Not planned
07 cases no task turns green, each with the reason (uncovered on purpose in 07, another repo,
later).
