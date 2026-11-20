// Import checked Lean code into the Slidev deck.
//
//   1. `lake build`            — type-checks everything; every #guard / #guard_msgs must pass.
//   2. Read regions from lean/**/*.lean and write
//        slides/generated/snippets/<name>@<n>.lean   (code shown on slides)
//        slides/generated/regions.json               (steps, notes, source locations)
//        slides/generated/evals.json                 (#eval + expected output from #guard_msgs)
//   3. `lake exe dump-trace`   → slides/generated/trace.json
//   4. Refill the generated blocks in slides/slides.md (see CLAUDE.md for the syntax).
//
// Any problem stops the script with a non-zero exit before slides.md is touched.

import { execFileSync } from "node:child_process";
import fs from "node:fs";
import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const leanDir = path.join(root, "lean");
const slidesDir = path.join(root, "slides");
const genDir = path.join(slidesDir, "generated");
const slidesMd = path.join(slidesDir, "slides.md");

// KaTeX is a dependency of the Slidev project, so resolve it from there.
const katex = createRequire(path.join(slidesDir, "package.json"))("katex");

class ImportError extends Error {}
const fail = (msg: string): never => {
  throw new ImportError(msg);
};

// ---------------------------------------------------------------- 1. lake build

function run(cmd: string, args: string[], cwd: string, what: string): string {
  try {
    return execFileSync(cmd, args, { cwd, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"], maxBuffer: 64 << 20 });
  } catch (e: any) {
    const out = `${e.stdout ?? ""}${e.stderr ?? ""}`;
    // Keep only Lake's error lines and what follows them; drop the long `trace:` command lines.
    const relevant = out
      .split("\n")
      .filter((l) => !l.startsWith("trace: "))
      .join("\n")
      .trim();
    return fail(`${what} failed:\n\n${relevant}`);
  }
}

// ---------------------------------------------------------------- 2. regions

const escapeHtml = (s: string) =>
  s.replace(/[&<>"]/g, (ch) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[ch]!);

/**
 * Caption/intent text → HTML: plain text with `inline code` and $inline math$ (KaTeX);
 * `\$` is a literal dollar. Rendered here so that bad TeX fails the import, not the talk.
 */
function renderText(text: string, at: string): string {
  const plain = (s: string) => {
    if (s.includes("$")) fail(`${at}: unmatched \`$\` in "${text}" (write \\$ for a literal dollar)`);
    return escapeHtml(s);
  };
  let html = "";
  let last = 0;
  for (const m of text.matchAll(/\\\$|`([^`]*)`|\$([^$]+)\$/g)) {
    html += plain(text.slice(last, m.index));
    if (m[1] !== undefined) html += `<code>${escapeHtml(m[1])}</code>`;
    else if (m[2] !== undefined) {
      try {
        html += katex.renderToString(m[2], { throwOnError: true, strict: "error" });
      } catch (e: any) {
        fail(`${at}: KaTeX cannot render $${m[2]}$: ${e.message}`);
      }
    } else html += "$";
    last = m.index! + m[0].length;
  }
  return html + plain(text.slice(last));
}

// `-- region: a @1` or, for a frame shared by two sequences, `-- region: a @2, b @1`.
const RE_REGION = /^\s*-- region:\s*(.+?)\s*$/;
const RE_MEMBER = /^([\w-]+)\s*@(\d+)$/;
const RE_ENDREGION = /^\s*-- endregion\s*$/;
// `-- note: …` applies to every sequence of the region; `-- note(b): …` only to sequence b,
// and replaces the unqualified text there. Same for caption and intent.
const RE_TEXT = /^\s*-- (note|caption|intent)(?:\(([\w-]+)\))?:\s?(.*)$/;
const RE_ELIDE_BEGIN = /^\s*-- elide-begin\s*$/;
const RE_ELIDE_END = /^\s*-- elide-end\s*$/;
const RE_STEP = /\s+-- step (\d+)\s*$/;
const RE_GUARD = /^#guard_msgs(\s*\([^)]*\))?\s+in$/;
// Something that looks like a marker but did not parse as one. A marker needs its
// punctuation (`note:`, `region:`, `step 3`), so prose such as `-- note that …` passes.
const RE_ANY_MARKER = /--\s*(?:(?:note|caption|intent)\s*[:(]|region\s*:|endregion\b|elide-(?:begin|end)\b|step\s+\d)/;

type TextKind = "note" | "caption" | "intent";

/** One frame of one sequence, as the deck sees it. */
type Region = {
  name: string;
  frame: number;
  source: string; // lean/…:line of the `-- region` line
  code: string;
  steps: Record<number, number[]>; // step → 1-based lines in `code`
  notes: string[]; // speaker notes
  captions: string[]; // shown under the code by <LeanCaption>
  intents: string[]; // shown above the code by <LeanIntent>
  messages: Message[]; // #guard_msgs-checked messages of non-#eval commands, shown by <LeanMessages>
};
type Message = { severity: string; text: string };
/** What regions.json holds per frame: the texts also as HTML, with math rendered. */
type RegionMeta = Omit<Region, "code"> & { range: string; captionsHtml: string[]; intentsHtml: string[] };
type Eval = { region: string; source: string; command: string; output: string };
type Member = { name: string; frame: number };
type OpenRegion = { members: Member[]; start: number; body: { text: string; line: number }[] };

function walk(dir: string): string[] {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((d) => {
    const p = path.join(dir, d.name);
    if (d.isDirectory()) return d.name.startsWith(".") ? [] : walk(p);
    return p.endsWith(".lean") ? [p] : [];
  });
}

function dedent(lines: string[]): string[] {
  const indents = lines.filter((l) => l.trim()).map((l) => l.match(/^ */)![0].length);
  const n = indents.length ? Math.min(...indents) : 0;
  return lines.map((l) => l.slice(n));
}

const label = (ms: Member[]) => ms.map((m) => `${m.name} @${m.frame}`).join(", ");

function parseMembers(spec: string, at: string): Member[] {
  const members = spec.split(",").map((part) => {
    const m = part.trim().match(RE_MEMBER);
    if (!m) fail(`${at}: malformed region "${spec}" (expected "name @n" or "a @n, b @m")`);
    return { name: m![1], frame: Number(m![2]) };
  });
  const names = members.map((m) => m.name);
  if (new Set(names).size !== names.length) fail(`${at}: region "${spec}" names the same sequence twice`);
  return members;
}

function parseFile(file: string): { regions: Region[]; evals: Eval[] } {
  const rel = path.relative(root, file);
  const lines = fs.readFileSync(file, "utf8").split("\n");
  const regions: Region[] = [];
  const evals: Eval[] = [];
  let cur: OpenRegion | null = null;

  lines.forEach((line, i) => {
    const at = `${rel}:${i + 1}`;
    if (RE_ENDREGION.test(line)) {
      if (!cur) fail(`${at}: "-- endregion" without an open region`);
      regions.push(...finishRegion(rel, cur!, evals));
      cur = null;
      return;
    }
    const open = line.match(RE_REGION);
    if (open) {
      const members = parseMembers(open[1], at);
      if (cur) fail(`${at}: region "${label(members)}" opened inside "${label(cur.members)}" (regions do not nest)`);
      cur = { members, start: i + 1, body: [] };
      return;
    }
    if (!cur) {
      if ([RE_TEXT, RE_ELIDE_BEGIN, RE_ELIDE_END, RE_STEP].some((re) => re.test(line)))
        fail(`${at}: note/caption/intent/elide/step marker outside any region`);
      return;
    }
    cur.body.push({ text: line, line: i + 1 });
  });
  if (cur) fail(`${rel}: region "${label((cur as OpenRegion).members)}" is never closed`);
  return { regions, evals };
}

function finishRegion(rel: string, r: OpenRegion, evals: Eval[]): Region[] {
  // texts[kind][qualifier] — qualifier "" is the unqualified text.
  const texts: Record<TextKind, Record<string, string[]>> = { note: {}, caption: {}, intent: {} };
  const memberNames = new Set(r.members.map((m) => m.name));
  const kept: { text: string; step?: number; line: number }[] = [];
  // Lines between `-- elide-begin` and `-- elide-end` stay in Lean (and are checked)
  // but are shown as a single `...` line, indented like the first elided line.
  let elided: { line: number; indent?: string } | null = null;
  for (const { text, line } of r.body) {
    if (RE_ELIDE_BEGIN.test(text)) {
      if (elided) fail(`${rel}:${line}: elide-begin inside another elide (line ${elided.line})`);
      elided = { line };
      continue;
    }
    if (RE_ELIDE_END.test(text)) {
      if (!elided) fail(`${rel}:${line}: elide-end without elide-begin`);
      if (elided!.indent === undefined) fail(`${rel}:${line}: empty elide block`);
      kept.push({ text: `${elided!.indent}...`, line: elided!.line });
      elided = null;
      continue;
    }
    const t = text.match(RE_TEXT);
    if (t) {
      const [, kind, qualifier = "", body] = t;
      if (qualifier && !memberNames.has(qualifier))
        fail(`${rel}:${line}: "-- ${kind}(${qualifier})" but this region is "${label(r.members)}"`);
      (texts[kind as TextKind][qualifier] ??= []).push(body);
      continue;
    }
    if (elided) {
      if (RE_STEP.test(text)) fail(`${rel}:${line}: step marker inside an elided block is never shown`);
      if (elided.indent === undefined && text.trim()) elided.indent = text.match(/^\s*/)![0];
      continue;
    }
    const step = text.match(RE_STEP);
    const clean = step ? text.replace(RE_STEP, "") : text.replace(/\s+$/, "");
    if (RE_ANY_MARKER.test(clean)) fail(`${rel}:${line}: malformed marker: ${text.trim()}`);
    kept.push({ text: clean, step: step ? Number(step[1]) : undefined, line });
  }
  if (elided) fail(`${rel}:${elided.line}: elide-begin is never closed`);

  // #guard_msgs blocks: `/-- … -/` (one or more lines), `#guard_msgs [(options)] in`, then
  // the guarded command, which runs to the next blank line.
  //  - An `#eval` (optionally after `open … in` lines) is shown as the command plus the
  //    expected output (lean:eval); the doc comment must be a single `info:`.
  //  - Any other command (a definition with a hole, say) stays in the code, and its
  //    messages become the frame's `messages`, shown by <LeanMessages> like an infoview.
  // The guard machinery itself is never shown.
  const shown: typeof kept = [];
  const found: Omit<Eval, "region">[] = [];
  const messages: Message[] = [];
  for (let i = 0; i < kept.length; i++) {
    const t = kept[i].text.trim();
    if (t.startsWith("#eval")) fail(`${rel}:${kept[i].line}: #eval inside a region must be wrapped in #guard_msgs`);
    if (!t.startsWith("/--")) {
      shown.push(kept[i]);
      continue;
    }
    // Collect the doc comment.
    let doc = "";
    let j = i;
    for (; j < kept.length; j++) {
      doc += (j > i ? "\n" : "") + kept[j].text;
      if (kept[j].text.includes("-/")) break;
    }
    if (!RE_GUARD.test(kept[j + 1]?.text.trim() ?? "")) {
      // An ordinary doc comment on a definition: keep it as code.
      shown.push(kept[i]);
      continue;
    }
    let end = j + 2;
    while (end < kept.length && kept[end].text.trim() && !kept[end].text.trim().startsWith("/--")) end++;
    const cmdLines = kept.slice(j + 2, end);
    if (!cmdLines.length) fail(`${rel}:${kept[j + 1].line}: #guard_msgs without a command`);
    const body = doc.trim().replace(/^\/--/, "").replace(/-\/$/, "").trim();
    const parsed = body.split(/\n---\n/).map((part) => {
      const m = part.trim().match(/^(info|warning|error):\s*([\s\S]*)$/);
      if (!m) fail(`${rel}:${kept[i].line}: cannot read the #guard_msgs docstring part: ${part.trim()}`);
      return { severity: m![1], text: m![2].trim() };
    });
    const evalAt = cmdLines.findIndex((l) => !/^\s*open .* in\s*$/.test(l.text));
    if (cmdLines[evalAt]?.text.trim().startsWith("#eval")) {
      if (parsed.length !== 1 || parsed[0].severity !== "info")
        fail(`${rel}:${kept[i].line}: an #eval in a region needs exactly one "info:" message, got: ${body}`);
      found.push({
        source: `${rel}:${cmdLines[evalAt].line}`,
        command: dedent(cmdLines.map((l) => l.text)).join("\n"),
        output: parsed[0].text,
      });
    } else messages.push(...parsed);
    shown.push(...cmdLines);
    i = end - 1;
  }

  // Trim blank lines at both ends, then dedent.
  while (shown.length && !shown[0].text.trim()) shown.shift();
  while (shown.length && !shown[shown.length - 1].text.trim()) shown.pop();
  const code = dedent(shown.map((s) => s.text)).join("\n") + "\n";
  const steps: Record<number, number[]> = {};
  shown.forEach((s, idx) => {
    if (s.step !== undefined) (steps[s.step] ??= []).push(idx + 1);
  });

  // One view per sequence the region belongs to; a qualified text replaces the unqualified one.
  return r.members.map(({ name, frame }) => {
    const pick = (kind: TextKind) => texts[kind][name] ?? texts[kind][""] ?? [];
    for (const e of found) evals.push({ region: `${name}@${frame}`, ...e });
    return {
      name,
      frame,
      source: `${rel}:${r.start}`,
      code,
      steps,
      notes: pick("note"),
      captions: pick("caption"),
      intents: pick("intent"),
      messages,
    };
  });
}

/** `{*|1-3|5}`-style Slidev range: everything first, then each step in order. */
function rangeOf(steps: Record<number, number[]>): string {
  const keys = Object.keys(steps).map(Number).sort((a, b) => a - b);
  if (!keys.length) return "";
  const compress = (ls: number[]) => {
    const out: string[] = [];
    for (let i = 0; i < ls.length; ) {
      let j = i;
      while (j + 1 < ls.length && ls[j + 1] === ls[j] + 1) j++;
      out.push(i === j ? `${ls[i]}` : `${ls[i]}-${ls[j]}`);
      i = j + 1;
    }
    return out.join(",");
  };
  return `{*|${keys.map((k) => compress(steps[k])).join("|")}}`;
}

// ---------------------------------------------------------------- 4. slides.md blocks

// <!-- lean:code NAME --> … <!-- /lean -->      code (Magic Move when NAME has several frames)
// <!-- lean:eval NAME --> … <!-- /lean -->      #eval commands of NAME with their checked output
// <!--
// lean:notes NAME                              speaker notes from `-- note:` (must be the slide's last comment)
// … -->
const RE_BLOCK = /<!-- lean:(code|eval) ([\w-]+) -->\n[\s\S]*?<!-- \/lean -->/g;
const RE_NOTES = /<!--\nlean:notes ([\w-]+)\n[\s\S]*?-->/g;

/**
 * Every `<!-- lean:code|eval NAME -->` must be closed by its own `<!-- /lean -->` before the
 * next one opens, and every `lean:` marker must be well formed. Otherwise the non-greedy
 * block regex could pair an opener with a later block's closer and silently drop content.
 */
function checkBlockMarkers(md: string) {
  let open: { name: string; line: number } | null = null;
  md.split("\n").forEach((raw, i) => {
    const line = raw.trim();
    const at = `slides.md:${i + 1}`;
    const opener = line.match(/^<!-- lean:(code|eval) ([\w-]+) -->$/);
    if (opener) {
      if (open) fail(`${at}: "${line}" opens before "${open.name}" (line ${open.line}) is closed with <!-- /lean -->`);
      open = { name: `lean:${opener[1]} ${opener[2]}`, line: i + 1 };
      return;
    }
    if (line === "<!-- /lean -->") {
      if (!open) fail(`${at}: <!-- /lean --> without an opening <!-- lean:code|eval NAME -->`);
      open = null;
      return;
    }
    if (/^lean:notes\b/.test(line)) {
      if (!/^lean:notes [\w-]+$/.test(line)) fail(`${at}: malformed "${line}" (expected "lean:notes NAME")`);
      if (md.split("\n")[i - 1]?.trim() !== "<!--") fail(`${at}: "${line}" must directly follow a line "<!--"`);
      return;
    }
    if (/<!--\s*\/?\s*lean\b/.test(line)) fail(`${at}: malformed lean marker: ${line}`);
  });
  if (open) fail(`slides.md:${(open as { line: number }).line}: "${(open as { name: string }).name}" is never closed with <!-- /lean -->`);
}

function renderBlocks(md: string, byName: Map<string, Region[]>, evals: Eval[]): string {
  checkBlockMarkers(md);
  const need =(name: string, at: string) => byName.get(name) ?? fail(`slides.md: ${at} refers to unknown region "${name}"`);
  md = md.replace(RE_BLOCK, (_all, kind: string, name: string) => {
    const frames = need(name, `lean:${kind}`);
    let body: string;
    if (kind === "code") {
      const imports = frames.map((f) => `<<< @/generated/snippets/${name}@${f.frame}.lean ${rangeOf(f.steps)}`.trimEnd());
      body = frames.length === 1 ? imports[0] : ["````md magic-move", ...imports, "````"].join("\n");
    } else {
      const es = evals.filter((e) => e.region.startsWith(`${name}@`));
      if (!es.length) fail(`slides.md: lean:eval ${name} — region has no #guard_msgs-checked #eval`);
      body = es
        .map((e) => ["```lean", e.command, "```", '<div class="lean-output">', "", "```text", e.output, "```", "", "</div>"].join("\n"))
        .join("\n\n");
    }
    return `<!-- lean:${kind} ${name} -->\n${body}\n<!-- /lean -->`;
  });
  md = md.replace(RE_NOTES, (_all, name: string) => {
    const frames = need(name, "lean:notes");
    const lines = frames.flatMap((f) =>
      f.notes.length ? [frames.length > 1 ? `**@${f.frame}** ${f.notes.join(" ")}` : f.notes.join("\n\n")] : [],
    );
    return `<!--\nlean:notes ${name}\n\n${lines.join("\n\n")}\n-->`;
  });
  return md;
}

// ---------------------------------------------------------------- main

function main() {
  if (fs.existsSync(`${genDir}.old`))
    console.warn("! slides/generated.old/ exists: an earlier import was killed while swapping, so generated/ and slides.md may not match. This run regenerates both.");
  console.log("› lake build");
  run("lake", ["build"], leanDir, "lake build");

  const regions: Region[] = [];
  const evals: Eval[] = [];
  for (const f of walk(leanDir).sort()) {
    const r = parseFile(f);
    regions.push(...r.regions);
    evals.push(...r.evals);
  }
  const byName = new Map<string, Region[]>();
  for (const r of regions) {
    const list = byName.get(r.name) ?? [];
    if (list.some((x) => x.frame === r.frame)) fail(`${r.source}: duplicate region "${r.name} @${r.frame}"`);
    list.push(r);
    byName.set(r.name, list);
  }
  for (const [name, list] of byName) {
    list.sort((a, b) => a.frame - b.frame);
    list.forEach((r, i) => r.frame !== i + 1 && fail(`${r.source}: frames of "${name}" must be @1, @2, … without gaps`));
  }

  console.log("› lake exe dump-trace");
  const trace = JSON.parse(run("lake", ["exe", "dump-trace"], leanDir, "lake exe dump-trace"));

  const md = renderBlocks(fs.readFileSync(slidesMd, "utf8"), byName, evals);
  checkSlides(md, new Set(trace.map((t: { id: string }) => t.id)), new Set(byName.keys()));
  const meta: RegionMeta[] = regions.map(({ code, ...rest }) => {
    const at = (kind: string) => `${rest.source} (${rest.name} @${rest.frame}, ${kind})`;
    return {
      ...rest,
      range: rangeOf(rest.steps),
      captionsHtml: rest.captions.map((t) => renderText(t, at("caption"))),
      intentsHtml: rest.intents.map((t) => renderText(t, at("intent"))),
    };
  });

  // All checks passed. Write everything to staging paths first, then swap them in
  // with renames, so a failure while writing leaves the last good output in place.
  const genNext = `${genDir}.next`;
  const genOld = `${genDir}.old`;
  const mdNext = `${slidesMd}.next`;
  fs.rmSync(genNext, { recursive: true, force: true });
  fs.rmSync(genOld, { recursive: true, force: true });
  fs.mkdirSync(path.join(genNext, "snippets"), { recursive: true });
  for (const r of regions) fs.writeFileSync(path.join(genNext, "snippets", `${r.name}@${r.frame}.lean`), r.code);
  fs.writeFileSync(path.join(genNext, "regions.json"), JSON.stringify(meta, null, 2) + "\n");
  fs.writeFileSync(path.join(genNext, "evals.json"), JSON.stringify(evals, null, 2) + "\n");
  fs.writeFileSync(path.join(genNext, "trace.json"), JSON.stringify(trace, null, 2) + "\n");
  fs.writeFileSync(mdNext, md);

  // The two renames below are not one atomic step. If the second one throws, put the old
  // generated/ back so the pair stays consistent. If the process is killed between them,
  // generated.old/ is left behind and the next run says so (any successful run repairs it,
  // since both outputs are regenerated from lean/).
  if (fs.existsSync(genDir)) fs.renameSync(genDir, genOld);
  fs.renameSync(genNext, genDir);
  try {
    fs.renameSync(mdNext, slidesMd);
  } catch (e) {
    if (fs.existsSync(genOld)) {
      fs.rmSync(genDir, { recursive: true, force: true });
      fs.renameSync(genOld, genDir);
    }
    throw e;
  }
  fs.rmSync(genOld, { recursive: true, force: true });
  console.log(`✓ ${regions.length} regions, ${evals.length} evals, ${trace.length} traces → slides/generated/`);
}

/** Deck-level checks that would otherwise only show up when presenting. */
function checkSlides(md: string, traceIds: Set<string>, regionNames: Set<string>) {
  // Slidev uses a slide's *last* HTML comment as speaker notes, so a generated block's
  // closing `<!-- /lean -->` must be followed by another comment before the slide ends.
  const lines = md.split("\n");
  lines.forEach((line, i) => {
    if (line.trim() !== "<!-- /lean -->") return;
    let j = i + 1;
    while (j < lines.length && lines[j].trim() !== "---" && !lines[j].includes("<!--")) j++;
    if (j >= lines.length || lines[j].trim() === "---")
      fail(`slides.md:${i + 1}: the slide ends with "<!-- /lean -->", which Slidev would show as speaker notes; end the slide with its lean:notes comment`);
  });
  // A lean:notes comment must be the slide's last comment, or Slidev shows the later one.
  lines.forEach((line, i) => {
    if (!/^lean:notes /.test(line.trim())) return;
    let j = i + 1;
    while (j < lines.length && !lines[j].includes("-->")) j++;
    for (j++; j < lines.length && lines[j].trim() !== "---"; j++)
      if (lines[j].includes("<!--"))
        fail(`slides.md:${j + 1}: a comment after "${line.trim()}" (line ${i + 1}) would become the speaker notes; move it above, or into the notes`);
  });
  for (const m of md.matchAll(/<TraceView\s+run="([^"]+)"/g))
    if (!traceIds.has(m[1])) fail(`slides.md: <TraceView run="${m[1]}"> — no such run in Slides.allRuns (have: ${[...traceIds].join(", ")})`);
  for (const m of md.matchAll(/<(LeanIntent|LeanCaption|LeanMessages)\b[^>]*?\bname="([^"]+)"/g))
    if (!regionNames.has(m[2])) fail(`slides.md: <${m[1]} name="${m[2]}"> — no region "${m[2]}" in lean/`);
}

try {
  main();
} catch (e) {
  if (e instanceof ImportError) {
    console.error(`\n✗ ${e.message}`);
    process.exit(1);
  }
  throw e;
}
