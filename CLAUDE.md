# slidev-fplean

Slidev decks (in Japanese) for a study group reading *Functional Programming in Lean* (FPIL),
**one deck per book section**, deployed as one site. Every piece of code, `#eval` output and
evaluation trace on a slide comes from Lean code that `lake build` has checked.
Started from the `fplean-4-3-slidev` prototype (4.3 only); `docs/design.md` has the decisions.

## Layout

```
flake.nix, .envrc         devShell: elan, nodejs_24, pnpm   (direnv allow, or nix develop)
book.json                 the pinned book release (tag, commit, its Lean version)
NOTICE                    attribution and which files are CC BY 4.0 / MIT
lean/                     one Lake project for all decks; toolchain in lean/lean-toolchain
  Book/Sec<c>_<s>/        the book's code for section c.s (CC BY 4.0), e.g. Book/Sec4_3/
  Slides/Sec<c>_<s>/      slide-only helpers for section c.s: traces, proofs of the book's laws
  Slides/Sec<c>_<s>/DumpTrace.lean   optional; `lake exe trace-<c>-<s>` prints the deck's traces
  lakefile.toml           libs Book and Slides (globs, no root module), one trace exe per deck
slides/                   one Slidev project shared by all decks
  <c>-<s>.md              the deck of section c.s, e.g. 4-3.md; headmatter `deck: <c>-<s>`
  components/, utils/     shared: TraceView, LeanIntent, LeanCaption, LeanMessages
  utils/deckData.ts       picks generated/<deck>/ for the deck being shown
  generated/<c>-<s>/      OUTPUT ONLY — written by the import script, committed
scripts/import-lean.ts    the import script
```

Section c.s is numbered as in the pinned release (`book.json`). Its deck id is `<c>-<s>`, its
Lean directories `Sec<c>_<s>`, and its URL on the site `/<c>-<s>/`.

**Sections do not see each other's Lean code** unless one imports the other on purpose: the book
reuses names across sections, so no module imports two sections that define the same name.
This is also why the libraries have no root module that imports everything.

## The one command

```sh
cd slides && pnpm lean:import [4-3 …]   # lake build → extract → trace → refill the decks
pnpm dev 4-3.md                         # preview one deck
pnpm build 4-3.md                       # check that it compiles
```

Without arguments the import handles every deck. It checks everything first (all decks) and
changes nothing if any check fails. It also checks that `lean/lean-toolchain` is the Lean
version in `book.json`. It then writes each deck to `slides/generated.next/<id>/` and
`slides/<id>.md.next` and swaps them in with two renames. A failure while writing leaves the
last good output in place, and a failed second rename puts the old `generated/<id>/` back.
Only a process killed *between* the two renames can leave new `generated/<id>/` with an old
`<id>.md`; `slides/generated.old/<id>/` is then left behind, the next run warns about it, and
any successful run repairs both.

## A new deck

1. Book code in `lean/Book/Sec<c>_<s>/`, helpers in `lean/Slides/Sec<c>_<s>/` (see `slide-from-lean`).
2. `slides/<c>-<s>.md` with `deck: <c>-<s>` in its headmatter.
3. Traces only: `lean/Slides/Sec<c>_<s>/DumpTrace.lean` and a `[[lean_exe]] name = "trace-<c>-<s>"`
   in `lean/lakefile.toml` (also in `defaultTargets`).
4. `pnpm lean:import <c>-<s>`.

## Invariants

- **Never edit `slides/generated/` or the inside of a generated block by hand.** Change the
  Lean source and re-run `pnpm lean:import`.
- **The book's code stays as in the book** (identifiers, structure). Only line breaks may
  differ. Slide-only helpers go in `lean/Slides/`, never in `lean/Book/`. Code that differs
  from the pinned release (`book.json`) is a bug.
- **Every `#eval` inside a region is wrapped in `#guard_msgs`.** The script refuses a bare one.
- **Never change a `#guard_msgs` docstring just to make the build pass** without the owner's
  decision: a mismatch means the code's behaviour changed (see `lean-import-debug`).
- Each slide that uses generated blocks ends with its `lean:notes` comment (Slidev treats the
  slide's *last* HTML comment as speaker notes, so `<!-- /lean -->` must not be last). The
  import script refuses a slide that breaks this (including a later comment that would steal the
  notes), an unclosed or malformed `lean:` marker, a `<TraceView run>` with an unknown id, and
  a `<LeanIntent|LeanCaption|LeanMessages name>` with an unknown region.

## How the deck explains (narrative rules)

Goal: **before reading any code, the audience can say what problem it solves and why it
has this shape; after reading it, they know what to take away and why the next step is
needed.**

1. **The deck opens with the section's question** and a roadmap (in the deck's `.md`), and closes
   by answering it.
2. **Every code slide has three layers:** *intent* above the code (`-- intent:`, shown by
   `<LeanIntent>`), the code, and the *takeaway* below it (`-- caption:`, shown by
   `<LeanCaption>`).
   - An intent says "here we do X with Y, because Z": what is being modeled or changed,
     which Lean construct does it, and why.
   - A takeaway says what to notice, often the problem that remains.
3. **Each takeaway motivates the next intent.** The deck is a chain of problem → solution.
   Check it by reading only the intents and takeaways in slide order.
4. **Talk about what is being modeled, not the syntax** ("an expression is a tree whose
   leaves are constants", not "an inductive with two constructors").
5. **Claim only what the source supports.** Motivations come from the book's text; where the
   book gives no reason, the intent does not invent one. Outputs are never written in prose:
   they come from `#guard_msgs`.

Where text lives: intent and takeaway of a piece of code → Lean markers next to it.
The section's question, the roadmap, transitions without code, and the summary →
the deck's `.md` (a deck-level intent line uses `<div class="lean-intent-static">`).

## Markers in Lean files

```lean
namespace V2                         -- outside the region: not shown

-- region: evaluate @2               -- frame 2 of the sequence "evaluate"
-- note: 演算子の適用を切り出す。       -- speaker note (removed from the code)
-- caption: `applyPrim` に切り出す。    -- on-slide text, shown by <LeanCaption>
def applyPrim : Arith → Int → Int → Option Int   -- step 1
  -- elide-begin                     -- lines up to elide-end are checked by Lean
  | Arith.plus, x, y => pure (x + y) --   but shown as one `...` line
  -- elide-end

def evaluateOption : Expr Arith → Option Int
  ...                                -- (rest of the definition, omitted in this example)
    applyPrim p v1 v2                -- step 2   (highlighted on the 2nd click)
-- endregion

-- region: eval-v2 @1
/-- info: none -/
#guard_msgs in
#eval evaluateOption fourteenDivided   -- shown as the #eval line + "none"
-- endregion
```

- `-- region: <name> @<n>` … `-- endregion`: regions do not nest; frames of one name are
  `@1, @2, …` without gaps, in any files. Several frames → one Magic Move block.
  A frame shared by two sequences: `-- region: a @2, b @1` (e.g. the last frame of one
  slide is the first frame of the next).
- `-- intent: …`: shown above the code by `<LeanIntent name="…" />` (narrative rule 2). A frame
  without its own intent keeps showing the latest earlier one.
- `-- step <k>` at a line's end: on click `k` those lines are highlighted (after an
  "all lines" state). Several lines may share a step.
- `-- note: …`: speaker notes, one line per comment.
- `-- note(b): …`, `-- caption(b): …`, `-- intent(b): …`: text for sequence `b` only, replacing
  the unqualified text there. Use it for a shared frame that plays a different role in
  each sequence.
- `-- caption: …`: text shown on the slide under the code by `<LeanCaption name="…" />`,
  which follows the visible Magic Move frame (the Magic Move must be the slide's first
  click consumer).
- Caption and intent text: plain text with `inline code` and `$inline math$` (KaTeX);
  `\$` is a literal dollar, and a `$` inside backticks stays code. The import script
  renders the math and fails on bad TeX or an unmatched `$`. Use math for what the code
  means (e.g. $\lambda x.\, x + 1$ next to `fun x => x + 1`); the code itself stays Lean.
  Math in the deck's `.md` and in speaker notes is Slidev's own `$…$`/`$$…$$`.
- `-- elide-begin` … `-- elide-end`: shown as a single `...`, indented like the first
  elided line. Use it for code that is unchanged or unimportant in that frame, so the
  frame fits on the slide. No `-- step` inside an elided block.

## Generated blocks in `slides/<c>-<s>.md`

```md
<!-- lean:code evaluate -->     code of region "evaluate" (Magic Move if several frames)
<!-- /lean -->

<!-- lean:eval eval-v5 -->      #eval commands of the region with their checked outputs
<!-- /lean -->

<!--
lean:notes evaluate
-->                             speaker notes from the region's `-- note:` lines
```

Write the empty block; the script fills it. Everything else in the deck is hand-written.

Intent and takeaway: `<LeanIntent name="<region>" />` before the block and
`<LeanCaption name="<region>" />` after it. If anything on the slide
consumes clicks before the Magic Move, pass `:offset="<that many clicks>"`; in `pnpm dev` a
red line under the code reports a mismatch between the slide's clicks and the frames.

Messages next to code (an infoview): `/-- error: … -/` + `#guard_msgs in` on a definition
(not an `#eval`) keeps the definition on the slide and records its messages for the frame;
`<LeanMessages name="<region>" />` shows those of the visible frame ("No messages" when the
frame has none). Several messages in one docstring are separated by `---`.

Trace animation: `<TraceView run="<id>" />`, where `<id>` is an `id` in
the deck's `slides/generated/<c>-<s>/trace.json` (for 4.3: `Slides.allRuns` in
`lean/Slides/Sec4_3/Trace.lean`).

## Skills

- `slide-from-lean`: add or change content (Lean frame → import → slide).
- `lean-import-debug`: `pnpm lean:import` failed.

## Git

Commit messages in English. Commit only when the owner asks.
