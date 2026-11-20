---
name: lean-import-debug
description: Diagnose a failed `pnpm lean:import` in this repository — Lean build errors, #guard_msgs mismatches, #guard failures, marker errors, unknown regions in a deck, deck and toolchain checks — and fix the cause in the Lean source, asking the owner whenever the fix would change what the deck claims. Use whenever the import script exits non-zero; the owner may say it in Japanese (e.g. "importが失敗した").
---

# When `pnpm lean:import` fails

Every check runs before anything is written, and writing goes through staging paths
(`slides/generated.next/<id>/`, `slides/<id>.md.next`) that are swapped in with two renames.
So after a failure, `slides/generated/<id>/` and `slides/<id>.md` still hold the last good state,
unless the process was killed between the two renames: then `slides/generated.old/<id>/` is
left behind and the script warns on the next run. Re-running the import repairs both.
If a `*.next` or `slides/generated.old/` path is left over, the write itself was
interrupted (disk, permissions): the next successful import removes it.
**Never fix a failure by editing `slides/generated/` or a generated block.**

Read the message after `✗` and classify it:

## `lake build failed` with `Docstring on #guard_msgs does not match`

Lean prints `- info: <expected>` / `+ info: <actual>`. The code now behaves differently from
what the deck says. Find out why (`git diff lean/`), then **ask the owner** which is right:

- the code is wrong → fix the code;
- the new output is right (e.g. the book's text was updated) → update the docstring.

Do not pick one yourself. The deck's claim is the point of the check.

## `lake build failed` with a `#guard` failure (in `lean/Slides/Sec<c>_<s>/Trace.lean`)

Two kinds of guard live there:

- **Result guards** (`.1 == V5.evaluateM …`): the theorem `evaluateTraced_result` makes a
  failure impossible for the result, so the likely cause is a guard comparing the wrong
  things, or a change to `V5`. Fix the cause, not the guard.
- **Step guards** (`.2 == …`): the step sequence the animation shows changed. Steps are not
  proved, only pinned. Show the owner the old and new sequences and **ask** whether the new
  one is right before updating the expected array.

## `lake build failed` with an ordinary Lean error

Type error, unknown identifier, etc. Fix it like any Lean error. If the error is in
`lean/Book/`, compare with the book at the pinned release (`book.json`) first: that code should match the book.

If the proof `evaluateTraced_result` breaks after `evaluateTraced` or `V5.evaluateM` changed,
restore the two to the same `>>=` shape rather than weakening the theorem.

## Marker errors (`region … never closed`, `duplicate region`, `frames … without gaps`, `malformed marker`, `#eval … must be wrapped`, `marker outside any region`)

The message names the file and line. Fix the marker as `CLAUDE.md` describes.

## `KaTeX cannot render $…$` or `unmatched `$``

A `-- caption:` or `-- intent:` of the named region has bad TeX, or a lone `$`. The
message names the region (`file:line` is its `-- region` line). Fix the TeX; write `\$`
for a literal dollar, or put code containing `$` in backticks.

## `slides/<id>.md: … refers to unknown region`

The block's name has no `-- region:` in `lean/`. Either the name has a typo, or the region
was renamed; fix whichever side is wrong.

## `<LeanIntent|LeanCaption|LeanMessages name="…"> — no region`

Same as above, for a component on the slide: fix the `name` or the `-- region:` line.

## `opens before … is closed`, `never closed`, `without an opening`, `malformed lean marker`

A generated block in the deck lost its `<!-- /lean -->` or has a typo in its opening
line. Restore the pair as `CLAUDE.md` shows (an empty block is fine; the import fills it).

## `a comment after "lean:notes …" would become the speaker notes`

Slidev shows a slide's last comment as its notes. Move the later comment above the
`lean:notes` comment, or put its text into a `-- note:` in Lean.

## `the slide ends with "<!-- /lean -->"`

Slidev would turn that closing marker into the slide's speaker notes. End the slide with
its `lean:notes` comment (or any other comment) after the block.

## `<TraceView run="…"> — no such run`

The id is not among the runs the deck's `trace-<id>` executable prints (for 4.3: `Slides.allRuns`, `lean/Slides/Sec4_3/Trace.lean`). Fix the typo, or add the run
there together with a `#guard` pinning its steps.

## `lake exe trace-<id> failed` or a JSON parse error

`lean/Slides/Sec<c>_<s>/DumpTrace.lean` must print exactly one JSON value and nothing else on stdout.

## Deck and layout checks

- `the headmatter must contain "deck: <id>"`: the deck's first `---` block needs
  `deck: <c>-<s>`, matching its file name. The shared components find the deck's data with it.
- `lean/lean-toolchain is …, but book.json pins …`: the Lean version and the pinned book
  release disagree. Moving to a newer book release is a deliberate change for all decks
  (see `docs/design.md`); do not edit either file to make the import pass without the owner.
- `everything under lean/Book/ must be in a section directory`: move the file into
  `Sec<c>_<s>/`. Files outside one would have their markers silently ignored.
- `no deck "<id>"`: the argument to `pnpm lean:import` names a deck file that does not exist.

## After the fix

Re-run `pnpm lean:import`, then `pnpm build`. Report to the owner what failed, the cause,
and what you changed — and, for a `#guard_msgs` mismatch, which side they chose.
