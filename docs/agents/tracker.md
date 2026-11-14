# Tracker: README checklist

Work for Overbooked is tracked in the repo's `README.md` (XNullForm/Roblox), not in ROADMAP.md or GitHub issues.

## Layout

- The checklist near the top of `README.md`: one line per request or round, `- [ ]` open, `- [x]` done (`- [x] Round N: ...`).
- Each round gets a `### Round N (date): title` section with the technical notes (what changed, which scripts, live-only vs mirrored).
- Each saved round gets a "Round N: saved for you (version N). Check: ..." line telling the user what to look at.
- Triage state, when needed, goes in brackets at the start of a checklist line, e.g. `- [ ] [needs-info] ...` (strings in `triage-labels.md`).

## When a skill says "publish to the tracker"

Add a `- [ ]` line to the README checklist (a PRD or slice list goes in a `### Plan: <feature>` section of README.md).

## When a skill says "fetch the item"

Read the matching checklist line and its `### Round` / `### Plan` section in README.md.
