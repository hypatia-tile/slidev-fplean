# fplean-4-3-slidev

A Slidev deck explaining FPIL 4.3 "Example: Arithmetic in Monads" (4.3.1–4.3.3, without the exercises),
whose code, `#eval` outputs and evaluation traces all come from Lean code that
`lake build` has checked. This is a prototype for learning what such a workflow needs.

## Layout

```
flake.nix, .envrc         devShell: elan, nodejs_24, pnpm   (direnv allow, or nix develop)
lean/                     Lake project, toolchain in lean/lean-toolchain
  Arith/Expr.lean         4.3.1, the book's code verbatim
  Arith/Evaluate.lean     4.3.2, one namespace per version: V1 … V5
  Arith/Further.lean      4.3.3 intro + 4.3.3.1: Prim, final applyPrim/evaluateM, Empty/Id
  Arith/Many.lean         4.3.3.2 Nondeterministic Search
  Arith/Reader.lean       4.3.3.3 Custom Environments (Reader.bind steps in Hole1 … Hole5)
  Slides/Trace.lean       evaluateTraced + theorem/guards tying it to V5.evaluateM
  Slides/Laws.lean        monad laws of Many and Reader (the book checks them by hand)
  DumpTrace.lean          `lake exe dump-trace`: trace JSON on stdout
slides/                   Slidev project (deck text in Japanese)
  slides.md               the deck; contains generated blocks (below)
  components/TraceView.vue  draws one trace run, one step per click
  components/LeanIntent.vue   `-- intent:` text of the visible frame (above the code)
  components/LeanCaption.vue  `-- caption:` text of the visible frame (below the code)
  components/LeanMessages.vue checked messages of the visible frame, like an infoview
  utils/leanFrame.ts      which frame is visible; shared by the Lean* components
  generated/              OUTPUT ONLY — written by the import script, committed
scripts/import-lean.ts    the import script
```

## The one command

```sh
cd slides && pnpm lean:import   # lake build → extract → dump-trace → refill slides.md
pnpm dev                        # preview;  pnpm build  to check the deck compiles
```

The script checks everything first and changes nothing if any check fails. It then writes
to `slides/generated.next/` and `slides/slides.md.next` and swaps them in with two renames.
A failure while writing leaves the last good output in place, and a failed second rename
puts the old `generated/` back. Only a process killed *between* the two renames can leave
new `generated/` with old `slides.md`; `slides/generated.old/` is then left behind, the next
run warns about it, and any successful run repairs both.

## Invariants

- **Never edit `slides/generated/` or the inside of a generated block by hand.** Change the
  Lean source and re-run `pnpm lean:import`.
- **The book's code stays as in the book** (identifiers, structure). Only line breaks may
  differ. Slide-only helpers go in `lean/Slides/`, never in `lean/Arith/`.
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

1. **The deck opens with the chapter's question** and a roadmap (in `slides.md`), and closes
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
The chapter's question, the roadmap, transitions without code, and the summary →
`slides.md` (a deck-level intent line uses `<div class="lean-intent-static">`).

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
  Math in `slides.md` and in speaker notes is Slidev's own `$…$`/`$$…$$`.
- `-- elide-begin` … `-- elide-end`: shown as a single `...`, indented like the first
  elided line. Use it for code that is unchanged or unimportant in that frame, so the
  frame fits on the slide. No `-- step` inside an elided block.

## Generated blocks in `slides/slides.md`

```md
<!-- lean:code evaluate -->     code of region "evaluate" (Magic Move if several frames)
<!-- /lean -->

<!-- lean:eval eval-v5 -->      #eval commands of the region with their checked outputs
<!-- /lean -->

<!--
lean:notes evaluate
-->                             speaker notes from the region's `-- note:` lines
```

Write the empty block; the script fills it. Everything else in `slides.md` is hand-written.

Intent and takeaway: `<LeanIntent name="<region>" />` before the block and
`<LeanCaption name="<region>" />` after it. If anything on the slide
consumes clicks before the Magic Move, pass `:offset="<that many clicks>"`; in `pnpm dev` a
red line under the code reports a mismatch between the slide's clicks and the frames.

Messages next to code (an infoview): `/-- error: … -/` + `#guard_msgs in` on a definition
(not an `#eval`) keeps the definition on the slide and records its messages for the frame;
`<LeanMessages name="<region>" />` shows those of the visible frame ("No messages" when the
frame has none). Several messages in one docstring are separated by `---`.

Trace animation: `<TraceView run="<id>" />`, where `<id>` is an `id` in
`slides/generated/trace.json` (defined in `Slides.allRuns`, `lean/Slides/Trace.lean`).

## Skills

- `slide-from-lean`: add or change content (Lean frame → import → slide).
- `lean-import-debug`: `pnpm lean:import` failed.

## Git

Commit messages in English. Commit only when the owner asks.
