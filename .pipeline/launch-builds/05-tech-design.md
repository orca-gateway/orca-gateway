# 05 · Technical design · launch-builds

## Front page

### In one breath
The design in two sentences: the parts, and how the main flow goes through them.
End with `n resolved, m open`.

### New for you
1. <the technique or pattern the design leans on> → learning/<topic>.md   (or: nothing new)

### Trade-offs
`n needs you: <issue>, <option> vs <option> (recommended: <option>)`
· `n auto-decided: <chosen> (your call, <date>)` · none

### Questions for you
The open trade-offs, numbered, each with the recommended default you will use on silence.

## Appendix

### Components
v0 first, as the naive architect wrote it, never edited; then one bullet per part an issue added, as
`- <name> (issue n): <what it does>`.

### Data
Stores and the shape of what they hold: one line per table, file or key;
new columns marked `(issue n)`.

### Sequences
The main flows, one per line: `actor → part → part → result`;
a failure path when an issue added one.

### Not handled, on purpose
What v0 leaves out and why that is fine at this size; it shrinks as issues are resolved.

### Issues resolved
| # | Issue | Change | Trade-off |
|---|---|---|---|

### Open issues
What the challenger would have raised next, beyond the cap of 5 per round, one line each;
`X` runs another pass.
