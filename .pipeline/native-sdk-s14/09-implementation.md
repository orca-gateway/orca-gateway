# 09 · Implementation · native-sdk-s14

## Front page

### In one breath
`group g of n · tasks: a green, b blocked · cases: k of m green · <command>: <summary>`,
then one line per task of this group: `<id> <title>: <what changed, in a clause>`.

### New for you
nothing new, or the concepts the digests' decisions lean on → learning/<topic>.md

### Trade-offs
`n needs you: <a review finding or a priced decision>`
· `n auto-decided: <what> (your call, <date>)` · none

### Questions for you
1. Each blocked task: retry with your words, or `skip task <id> <why>`? (default: retry once)
2. Next: group g+1? (default: go; `A` starts it). On the last group, `A` approves the stage.
then any priced decision from a digest, with its default.

## Appendix

### Group g
One digest per task, in dependency order, in the shape of `templates/digest.md` (at most 12 lines,
at most 3 decisions, both review verdicts). Earlier groups keep their section above; the newest
is last.

### Test run
`<command>` · `<summary line>` · failures one per line (`<file> › <name>: <first line>`),
or `none`.

### Blocked
Tasks not green after their rework pass: `<id> · <the finding or the last red line> · what was
tried`. Or `none`.

### Not done
Tasks skipped on your word, each with the 07 cases it leaves uncovered. Or `none`.

### For ship (stage 10) to know
Migrations, config, env or data a deploy needs; what still runs by hand. Or `nothing`.
