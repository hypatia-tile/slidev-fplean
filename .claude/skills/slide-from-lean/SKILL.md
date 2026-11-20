---
name: slide-from-lean
description: Add or change deck content in this repository by writing checked Lean first and importing it — a new code frame, a refactoring step for Magic Move, a click-by-click highlight, an #eval result, a speaker note, or a new trace animation. Use whenever a slide needs Lean code, Lean output or a trace; the owner may ask in Japanese (e.g. "スライドを追加して", "このコードを載せたい").
---

# Slide from Lean

Lean is the source; the deck only shows what `lake build` checked. Read `CLAUDE.md`
for the marker syntax if it is not already in context.

## 1. Decide where the Lean goes

- Book code of section c.s → `lean/Book/Sec<c>_<s>/`. Keep it as in the pinned release
  (`book.json`); the book's own example code is under `examples/` at that tag. A new version of an
  existing definition goes in a new `namespace Vn`, never by editing an earlier version.
- Slide-only helpers (tracing, JSON, extra checks) → `lean/Slides/Sec<c>_<s>/`.
- Region names need only be unique within the deck.

## 2. Write the region

- Wrap the shown code in `-- region: <name> @<n>` … `-- endregion`.
  - Continuing a refactoring sequence: same name, next frame number.
  - Namespace lines go outside the region.
- Add `-- step <k>` to the lines a click should highlight, in teaching order.
- Add `-- note: …` lines (Japanese) for speaker notes: what to say, not what is on screen.
- Add `-- intent: …` (above the code) and `-- caption: …` (the takeaway, below it), in
  Japanese, one or two short sentences each. Follow the narrative rules in `CLAUDE.md`:
  the intent says what is modeled, with which construct, and why; the takeaway says what to
  notice. Take motivations from the book's text, and do not invent one where the book
  gives none.
- A frame that ends one slide and starts the next: `-- region: a @n, b @1`, with
  `-- intent(b): …` etc. for the text that differs between the two.
- If a frame is too tall for the slide, wrap code that is unchanged or unimportant in that
  frame in `-- elide-begin` / `-- elide-end`; it is still checked, but shown as `...`.
- Every `#eval` to show: put it in a region that holds only `#eval`s (several are fine),
  each wrapped as
  ```lean
  /-- info: <expected> -/
  #guard_msgs in
  #eval …
  ```
  If you don't know `<expected>`, write `/-- info: ? -/`, build, and copy the actual output
  from Lean's error **only if it is what the book says or what the owner expects**. If it
  isn't, stop and tell the owner — that is a finding, not a typo.
- A message to show next to code (a hole's goal, as the book does when it "follows the
  types"): wrap the definition itself in `/-- error: … -/` + `#guard_msgs in`. The code stays
  on the slide and the messages go to `<LeanMessages name="<name>" />`. Several messages are
  separated by `---`. If Lean's order differs from the book's, `#guard_msgs (ordering :=
  sorted) in` may help; say so in a comment outside the region.

## 3. A new trace (optional)

For 4.3: add a `run …` entry to `Slides.allRuns` in `lean/Slides/Sec4_3/Trace.lean`, plus two `#guard`s:
one that its result equals `V5.evaluateM` on that input (documents the case; the theorem
`evaluateTraced_result` already covers results), and one that pins its full step sequence.
Steps are **not** proved, so check the sequence by hand against the evaluation order and
show it to the owner.

## 4. Import

```sh
cd slides && pnpm lean:import <c>-<s>
```

On failure, use `lean-import-debug`. Do not touch `slides/generated/`.
A deck's first trace also needs `DumpTrace.lean` and a `trace-<c>-<s>` exe (see `CLAUDE.md`, "A new deck").

## 5. Use it in `slides/<c>-<s>.md`

Write empty blocks; the script fills them on the next import:

```md
<!-- lean:code <name> -->
<!-- /lean -->

<!--
lean:notes <name>
-->
```

Put `<LeanIntent name="<name>" />` before the block and `<LeanCaption name="<name>" />`
after it. `lean:eval <name>` for #eval regions; `<TraceView run="<id>" />` for traces. Keep the
`lean:notes` comment last on the slide (the import refuses otherwise). For captions, add
`<LeanCaption name="<name>" />`, with `:offset` if something before the Magic Move consumes
clicks. Slide prose is Japanese; code stays English.
Run `pnpm lean:import` again after adding blocks.

## 6. Check the narrative

Read only the intents and takeaways (and the deck-level lines in the deck's `.md`) in slide
order. Each takeaway must motivate the next intent, and the summary must answer the
question on the opening slides. Fix a gap before building.

## 7. Check the build

```sh
pnpm build
```

It must succeed. If you can, look at the slide at each frame (headless Chromium on
`pnpm dev`, `/<slide>?clicks=<n>&embedded=true`) to check nothing overflows. Then tell the owner what changed, per slide, and which outputs and
traces are new — they will review in `pnpm dev`. Commit only if asked.
