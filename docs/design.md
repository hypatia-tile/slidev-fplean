# Design decisions

Sections 1–18 come from the `fplean-4-3-slidev` prototype (one deck, FPIL 4.3), copied here
unchanged as the record of why the tooling looks the way it does. Their paths are the
prototype's (`lean/Arith/`, `slides/slides.md`, …); §19 maps them to this repository and
records the decisions for covering the whole book. Where §19 changes an earlier decision,
§19 wins.

## Prototype

This repository is a **prototype**. Its purpose is to find out, by building a small
deck that actually works, what a "write Lean, present it in Slidev" workflow needs.
Each decision below records what was chosen, what else was considered, and why.
Where a decision is expected to be revisited, it says so.

The deck covers FPIL 4.3.1–4.3.3, without the exercises of 4.3.3.4. It started as a
prototype of 4.3.1–4.3.2 (§5); §18 records the extension.

## 1. Goal: Lean checks, Slidev presents

Everything on a slide that claims something about Lean — code, `#eval` output, an
evaluation trace — must come from Lean code that `lake build` has checked. Nothing is
hand-copied into `slides.md`.

**Why:** hand-copied code and output drift from the real behaviour silently. Making
the build the single gate means a deck that builds is a deck whose claims hold.

## 2. What "infoview" data to capture

**Chosen:** compiler messages (`#eval` results, errors) attached to marked regions of
the source, plus a trace computed in Lean. **Not chosen:** LeanDojo's
`ExtractData.lean`, as is or adapted.

**Why:** `ExtractData.lean` records goal states only for *tactic* blocks, plus premise
references and syntax trees. FPIL 4.3 has no tactics or proofs; what the reader sees in
the infoview there is `#eval` output, hole/expected-type errors, and hover types. The
extractor would have produced almost empty `tactics` arrays.

**Revisit when:** a chapter with tactic proofs is covered, or hover types are wanted.
A custom `Lean.Elab.Frontend` metaprogram (or a fork of `ExtractData.lean`) is the
natural next step then.

## 3. Lean and Slidev in one repository

**Chosen:** `lean/` (a Lake project) and `slides/` (a Slidev project) side by side.
**Not chosen:** using the existing code in the separate `lean-read-books` repository
and pinning one of its commits; a separate Lean repository.

**Why:** the prototype should be self-contained and quick to change on both sides at
once. Pinning another repository would put slide-driven constraints (markers, version
layout) on a repository with its own conventions, before we know what those
constraints should be. The cost is a second copy of the chapter's code.

## 4. Several versions of one definition

The book redefines `evaluateOption`, `applyPrim` and `evaluateM` several times.

**Chosen:** one file per topic, one `namespace V1` … `V5` per version
(`lean/Arith/Evaluate.lean`). **Not chosen:** one git commit per version; one file per
version.

**Why:** with one commit per version, fixing an early step means rewriting history and
re-extracting every later commit. Namespaces keep every version buildable at once, the
history stays ordinary, and the file reads top to bottom in slide order. Changes
between versions are shown by Magic Move, not by `git diff`.

## 5. Scope of the prototype

*Historical: superseded by §18, which extends the deck to all of 4.3.3. Kept as the record
of how the prototype started.*

**Chosen (at the time):** 4.3.1–4.3.2 only. **Not chosen:** all of 4.3.3 (`Many`, `Reader`), or a
single refactoring step.

**Why:** 4.3.2 already exercises every kind of data the pipeline needs: several
versions of one function (Magic Move), outputs that differ by monad (`none` vs
`Except.error …`), and one expression (`fourteenDivided`) worth animating. The
`Reader.bind` construction from holes in 4.3.3 is the best showcase for error messages
and is a good second iteration.

## 6. Two kinds of animation

**Chosen:** Slidev's built-in Shiki Magic Move for code changes between versions,
plus a trace of the evaluation computed by Lean and drawn by `TraceView.vue`.
**Not chosen:** a hand-written evaluation animation.

**Why:** Magic Move needs only the code of each version, which we extract anyway. The
evaluation animation is where "Lean checks, Slidev presents" pays off most, and it is
the part Slidev cannot do out of the box, so it is the part the prototype most needed
to test.

## 7. The traced evaluator and why it can be trusted

**Chosen:** a separate `Slides.evaluateTraced` (`lean/Slides/Trace.lean`) that returns
the same monadic result as `V5.evaluateM` plus a list of steps. The book's code stays
untouched.

- The result is built with the same `>>=` chain as `V5.evaluateM`.
- `theorem evaluateTraced_result` proves the two results are equal **for every monad
  and every expression** (structural induction + `simp`).
- `#guard` lines check concrete cases too, for readability.

**Not chosen:** adding a tracing hook to `evaluateM` (the slides would no longer show
the book's code); running the unmodified `evaluateM` in a logging monad (in 4.3.2 only
division has a hook, so the trace would be too sparse to animate).

**Limits:** the theorem covers the *result*. The *steps* are produced by a separate
branch on `observe` and are not proved to match the evaluation order. Instead, the full
step sequence of every run shown in the deck is reviewed by hand and pinned with a
`#guard`, so any change to how steps are built fails the build and must be reviewed
(the `lean-import-debug` skill asks the owner before an expected sequence is updated).

## 8. Pipeline: one command, nothing written on failure

`pnpm lean:import` (`scripts/import-lean.ts`):

1. `lake build` — every `#guard` / `#guard_msgs` must pass.
2. Extract marked regions → `slides/generated/snippets/*.lean`, `regions.json`,
   `evals.json`.
3. `lake exe dump-trace` → `slides/generated/trace.json`.
4. Refill the generated blocks in `slides/slides.md`.

All output is computed and checked first; nothing is touched if any step fails. It is
then written to staging paths (`slides/generated.next/`, `slides/slides.md.next`) and
swapped in with renames, so even a failure while writing (disk full, permissions) leaves
the last good deck in place. The two renames are not one atomic operation, but the window
between them is only the renames themselves.

**Choices inside it:**

- **Trace through an executable, not `#eval` output.** Parsing JSON out of message text
  is fragile; `dump-trace` prints exactly one JSON value.
- **`slides/generated/` is committed.** The deck builds without a Lean toolchain, and
  diffs of generated output show what a Lean change did to the slides.
- **Only standard tools** (`lake`, Node). A Lean metaprogram would be more powerful but
  was more to build before anything worked.

## 9. `#eval` output comes from `#guard_msgs`

**Chosen:** every `#eval` shown on a slide is written as
`/-- info: … -/ #guard_msgs in #eval …`; the script takes the shown output from that
docstring and refuses a bare `#eval` inside a region. **Not chosen:** collecting
messages from `lean --json`.

**Why:** the expected output then lives in the source and is checked on every build;
the text on the slide is exactly the text Lean verified. `#guard_msgs` also consumes the
messages it matches, so they would not appear in `lean --json` anyway.

A mismatch is treated as a finding, not a typo: the `lean-import-debug` skill asks the
owner whether the code or the expected output is wrong.

## 10. Comments in Lean drive the slides

All slide-related metadata lives in Lean comments, so the Lean file stays valid Lean
and is the single source:

| Marker | Effect |
|---|---|
| `-- region: <name> @<n>` … `-- endregion` | a snippet; frames `@1, @2, …` of one name become one Magic Move |
| `-- step <k>` (line end) | the line is highlighted on click `k` |
| `-- note: …` | speaker notes |
| `-- intent: …` | on-slide text above the code: what it is for and why (§16) |
| `-- caption: …` | on-slide explanation under the code |
| `-- elide-begin` … `-- elide-end` | checked, but shown as one `...` line |

**Why comments rather than a separate mapping file:** the information sits next to the
code it describes, survives edits that move lines, and an agent editing Lean sees it.
Slides refer to regions by name, never by line number.

**Why commit order was not used for animation order:** see §4; frame numbers in
comments replace it.

Slide *prose* stays in `slides.md`; Lean files carry only what is tied to specific code.

## 11. Getting generated content into `slides.md`

Slidev 53's Magic Move expands `<<< @/file {ranges}` imports inside the block, so the
script writes plain snippet files and the deck imports them. To place them, `slides.md`
contains empty marker blocks (`<!-- lean:code NAME -->`, `lean:eval`, `lean:notes`)
that the script refills in place; everything outside them is hand-written.

**Known wrinkle:** Slidev treats a slide's *last* HTML comment as its speaker notes, so a
slide must not end with `<!-- /lean -->`. Each such slide ends with its `lean:notes`
comment, which shows a `lean:notes NAME` header line in presenter view. The import script
enforces this, and also refuses a `<TraceView run>` whose id is not a Lean-generated run,
so neither mistake waits until the talk to show up.

## 12. Fitting frames and explaining them

Two later additions, after frames 4–5 of the refactoring slide overflowed:

- **`elide` markers** hide code that is unchanged or unimportant *in that frame*
  (e.g. the bodies of `applyPrimOption`/`applyPrimExcept`). The full code is still
  checked by Lean. Only the display changes.
- **`caption` + `LeanCaption.vue`** show a short explanation under the code for the
  visible frame. The component registers no clicks of its own; it computes the frame
  from the click count and the frames' highlight ranges in `regions.json`.
  Slidev does not expose which click range belongs to which Magic Move, so the
  component assumes the Magic Move starts after `offset` clicks (default 0, i.e. it is the
  first click consumer). After mounting it compares the slide's total clicks with what
  the frames imply and reports a mismatch in the console and, in `pnpm dev`, on the slide,
  so a wrong assumption does not drift silently.

## 13. Trace view

**Chosen:** the expression tree drawn once, with one click per step: `enter` highlights
a node, `return` shows its value, `fail` turns it red. The same tree for `Option` and
`Except` makes the only difference — what a failure carries — visible.
**Not chosen (for now):** a call-stack view. It can be built later from the same steps.

The component registers its clicks with Slidev's clicks context the same way the
built-in `ShikiMagicMove` does: `calculateSince` + `register`, in `onMounted`, so its
click range is allocated in document order together with `v-click` and Magic Move.

## 14. Environment

- A Nix flake devShell with `elan`, `nodejs_24`, `pnpm`, entered with direnv.
- Toolchain `leanprover/lean4:v4.33.0`, the same as the owner's FPIL reading project.
- Slidev pinned to an exact release at least two weeks old (`53.0.0`).
- No CI: the local `pnpm lean:import` + `pnpm build` is the whole check for a prototype.

## 15. Working with an agent

The deck is written with an agent, so the conventions above live in the repository:

- `CLAUDE.md`: layout, markers, invariants, the one command.
- `.claude/skills/slide-from-lean`: Lean frame → import → slide → build → visual check.
- `.claude/skills/lean-import-debug`: classify a failed import; ask the owner on a
  `#guard_msgs` mismatch rather than editing the expectation.

**Invariants an agent must keep:** never edit `slides/generated/` or the inside of a
generated block; keep the book's code as in the book; wrap shown `#eval`s in
`#guard_msgs`.

## 16. How the deck explains

Slide 2 originally showed `Expr` with no lead-in. The goal, as a rule: **before reading
any code, the audience can say what problem it solves and why it has this shape; after
reading it, they know what to take away and why the next step is needed.** It breaks
down into the narrative rules in `CLAUDE.md`: the deck opens with the chapter's question
and closes by answering it; every code slide has an intent, the code, and a takeaway;
each takeaway motivates the next intent; and intents talk about what is being modeled,
not the syntax.

**Where the text lives (chosen: split by scope).** Intent and takeaway of a piece of code
are Lean markers next to that code (`-- intent:`, `-- caption:`), so they change together
with it and each Magic Move frame has its own. The chapter's question, the roadmap,
transitions without code and the summary are not tied to code and stay in `slides.md`.
**Not chosen:** everything in `slides.md` (intents drift from the code, and frames cannot
each have one) or everything in Lean.

**Consequence: the refactoring is split in two slides.** Rule 3 exposed a gap: the book's
"`none` is not a useful error message" comes *between* the `applyPrim` refactor and the
switch to `Except`, but the deck showed all five versions in one Magic Move and the `none`
only afterwards. The deck now follows the book's order: `evaluate-option` (V1 → V2), the
`#eval`, then `evaluate-generic` (V2 → V5). To keep the V2 → V3 animation, a region can be
a frame of two sequences (`-- region: evaluate-option @2, evaluate-generic @1`), and text
markers can be qualified by sequence (`-- intent(evaluate-generic): …`) where the shared
frame plays a different role.

**Claims stay sourced.** Motivations come from the book's text. The book gives no reason in
4.3.1 for parameterizing `Expr` over `op`, so the deck says only that the shape of an
expression and the set of operators are separate types.

## 17. Math notation (KaTeX)

Lean code and math notation explain each other: the code is what is checked, the
formula is what it means. Slidev already renders `$…$` in `slides.md` and in speaker
notes. Intent and takeaway text, though, reaches the slide through `regions.json` and
`v-html`, which Slidev's Markdown pipeline never sees.

**Chosen: render at import time.** The import script renders `$…$` in `-- caption:` and
`-- intent:` text with KaTeX (`strict: "error"`, `throwOnError: true`) and stores the HTML
next to the raw text (`captionsHtml`, `intentsHtml`). A typo in TeX or a stray `$` fails
the import with the region's location, like every other check, instead of showing up as
red text during the talk. `` `…` `` is parsed first, so `$` in code (`f $ x`) is not math.
KaTeX is a direct dependency of `slides/` at the version Slidev already uses.

**A trap found on the way.** Slidev imports the KaTeX stylesheet only when `slides.md`
contains math (`features.katex`). Formulas that come only from `regions.json` would render
unstyled, so `utils/leanFrame.ts` imports `katex/dist/katex.min.css` itself.

**Not chosen:** rendering in the browser with KaTeX (errors appear only on screen), and
display math in markers (one marker is one line; a display formula belongs in `slides.md`).

## 18. Extending to 4.3.3

The prototype stopped at 4.3.2 (§5). The owner then asked for the rest of 4.3. The
exercises (4.3.3.4) are left out: solving them is the reader's job, and the book gives no
solutions to check against.

**The pipeline held.** Most of 4.3.3 needed nothing new: book code in `lean/Arith/`
(`Further`, `Many`, `Reader`), `#guard_msgs` for every output (including the 20 lines of
`addsTo`), KaTeX for the book's evaluation rules. Three small extensions were needed:

- **Messages next to code.** The book writes `Reader.bind` by filling one `_` at a time and
  reading Lean's "don't know how to synthesize placeholder" message. This is the infoview
  data the project set out to track. A `#guard_msgs` on a definition now keeps the
  definition as code and records its messages for the frame; `<LeanMessages>` draws them
  beside a Magic Move of the six steps. Each step is its own namespace (`Hole1` …), since
  all define `Reader.bind`. Lean 4.33 reports the two holes of step 3 in reverse source
  order; `#guard_msgs (ordering := sorted)` happens to restore the book's order (α < ρ).
- **`#eval` commands may span lines** and start with `open … in`, as the book's do.
- **An intent carries over** to later frames that have none, so a sequence whose purpose
  does not change states it once.

**Monad laws are proved, not computed by hand.** The book checks the contract for `Many`
and `Reader` by unfolding definitions. `lean/Slides/Laws.lean` proves them: `rfl` for
`Reader`, induction with three lemmas about `union` for `Many`. The `Many` statements are
equalities of `Many` values, which is stronger than the book's multiset argument (order
included).

**Kept out of prose.** Results of the book's search and reader examples appear only as
checked `#eval` output; the rules slide states the rules, not the results.

## 19. From the prototype to the whole book

Settled with the owner before the move (2026-11-20).

**Purpose and unit.** The decks are for **talks in a study group**: built for a live presenter
(clicks, Magic Move, traces, speaker notes), and still readable alone afterwards thanks to the
intent/takeaway layers (§16). **One deck per book section** (about 30–45 minutes, like 4.3).
Very short sections may be merged later, as an exception.

**One repository, one site.** One Lake project and one Slidev project serve every deck; one
Vercel site serves each deck at `/<c>-<s>/` (section number, e.g. `/4-3/`) plus an index page.
**Not chosen:** one Vercel project per deck, one repository per deck (§3's reason, "quick to
change both sides at once", now applies to the shared tooling).

**Copy, then generalise.** The prototype's tooling was copied (provenance in the first
commit) and reworked; 4.3 moved first, and its regenerated output was compared with the
prototype's: identical except paths and one line number.

**One pinned book release.** `book.json` names a release tag of `leanprover/fp-lean`
(`release-2026-11`) and its commit. `lean/lean-toolchain` is that release's
`examples/lean-toolchain`; the import script checks this. The credit and "as in the book"
both refer to that release. Moving to a newer release is one deliberate change for all decks:
update `book.json` and the toolchain, re-import, and every `#guard_msgs` shows where behaviour
changed. Renumbered sections then get redirects from their old URLs. **Not chosen:** a
release per deck (several Lean versions, so no shared Lake project); following the latest
book with no record (claims would not be checkable against a fixed text).

**Order.** Decks are made in the order the study group reads, by default book order;
`docs/roadmap.md` will list every section.

**Exercises.** Listed on a final slide, without solutions (§18 left them out; the book gives
no solutions to check, and solving them is the reader's job).

**Deploy.** Vercel's Git integration (production from `main`, previews for pull requests)
builds only Slidev, from the committed `generated/` (§8), so Vercel needs no Lean.
A GitHub Actions job runs `lake build` and checks that `generated/` is what the import would
write. That replaces §14's "no CI".

**Licensing.** The book is CC BY 4.0 (© 2023 Microsoft Corporation; changes © 2023–2025
Lean FRO, LLC). Book code and decks are CC BY 4.0; the rest is MIT. `NOTICE` has the details;
each deck credits the book on its title and last slides.

### Layout choices made in the move

- **Per-section directories, not namespaces.** Book code of c.s is in
  `lean/Book/Sec<c>_<s>/`, helpers in `lean/Slides/Sec<c>_<s>/`. Wrapping each section in a
  namespace was not chosen: it would change how the book's code resolves names (e.g. a
  `def List.foo` would become `Sec4_3.List.foo`). Instead, no module imports two sections
  that define the same name, and the libraries use `globs` instead of a root module that
  imports everything.
- **One trace executable per deck** (`trace-<c>-<s>`), for the same reason: a single
  executable would import every deck's trace code. A deck without traces has none, and gets
  an empty `trace.json`.
- **Deck files at the top of `slides/`** (`slides/4-3.md`), not in a subdirectory: Slidev
  looks for `components/`, `style.css` etc. next to the entry file, so this is what lets every
  deck share them.
- **The deck names itself in its headmatter** (`deck: 4-3`). Slidev passes every headmatter key
  to the client as `configs`, and `utils/deckData.ts` uses it to pick
  `generated/<deck>/` out of an `import.meta.glob` of all decks' data. The import script
  checks the key against the file name. This bundles every deck's (small) JSON into each
  deck's build; acceptable while each is a few kB.
- **Region names are per deck**, so later decks need not avoid names used by earlier ones.
- **The import checks all decks before writing any** (§8 extended), then swaps each deck in
  on its own; each deck's pair (`generated/<id>/`, `<id>.md`) stays consistent.

## Open questions

- Is it worth moving to a Lean metaprogram for extraction (hover types, hole messages)?
- Should the trace *steps* get a correctness statement instead of pinned examples?
- Should `slides/generated/` stay committed once a CI exists? (§19: yes, so Vercel needs no Lean.)
- Can `LeanCaption` drop the `offset` assumption, e.g. by wrapping Magic Move in a
  component that publishes its own click range?
- Does the book's own line breaking matter? The code was copied from a page whose line
  breaks were lost; identifiers and structure match the book.
