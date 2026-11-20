<script setup lang="ts">
// Draws one run from generated/trace.json (produced by Lean's `dump-trace`) as an
// expression tree, and applies one trace step per click.
import { useSlideContext } from '@slidev/client'
import { computed, onMounted, onUnmounted, shallowRef, useId } from 'vue'
import traces from '../generated/trace.json'

type Tree = { label: string, children: Tree[] }
type Step = { kind: 'enter' | 'return' | 'fail', path: number[], value?: string }
type Run = { id: string, example: string, monad: string, expr: Tree, steps: Step[] }

const props = defineProps<{ run: string, at?: string | number }>()

const data = (traces as Run[]).find(r => r.id === props.run)
if (!data)
  throw new Error(`[TraceView] no run "${props.run}" in generated/trace.json — run \`pnpm lean:import\``)

// ---- clicks: one per step. Registered in onMounted, like Slidev's own ShikiMagicMove,
// so the start is computed in document order together with v-click and Magic Move.
const { $clicksContext: clicks } = useSlideContext()
// Stable per component instance (two TraceViews of one run on a slide must not collide).
const id = `trace-${props.run}-${useId()}`
type ClickInfo = NonNullable<ReturnType<NonNullable<typeof clicks>['calculateSince']>>
const info = shallowRef<ClickInfo | null>(null)
onMounted(() => {
  if (!clicks)
    return
  info.value = clicks.calculateSince(props.at ?? '+1', data.steps.length)
  if (info.value)
    clicks.register(id, info.value)
})
onUnmounted(() => clicks?.unregister(id))

/** Number of steps applied so far (0 … steps.length). Before mounting (and without a
 * clicks context, e.g. in print mode) the whole run is shown. */
const applied = computed(() => {
  if (!clicks)
    return data.steps.length
  if (!info.value)
    return 0
  return Math.max(0, Math.min(data.steps.length, clicks.current - info.value.start + 1))
})

// ---- layout: leaves in order along x, depth along y
type Node = { key: string, label: string, x: number, y: number, parent?: string }
const nodes: Node[] = []
let leaf = 0
function layout(t: Tree, path: number[], depth: number, parent?: string): number {
  const key = path.join(',')
  let x: number
  if (!t.children.length) {
    x = leaf++
  }
  else {
    const xs = t.children.map((c, i) => layout(c, [...path, i], depth + 1, key))
    x = (xs[0] + xs[xs.length - 1]) / 2
  }
  nodes.push({ key, label: t.label, x, y: depth, parent })
  return x
}
layout(data.expr, [], 0)
const depth = Math.max(...nodes.map(n => n.y))
const dx = 110
const dy = 86
const r = 26
const pad = 40
const width = (leaf - 1) * dx + pad * 2
const height = depth * dy + pad * 2 + 30
const pos = (n: Node) => ({ cx: pad + n.x * dx, cy: pad + n.y * dy })
const byKey = new Map(nodes.map(n => [n.key, n]))

// ---- state after `applied` steps
type State = { status: 'idle' | 'active' | 'done' | 'failed', value?: string }
const states = computed(() => {
  const s = new Map<string, State>(nodes.map(n => [n.key, { status: 'idle' }]))
  for (const step of data.steps.slice(0, applied.value)) {
    const k = step.path.join(',')
    s.set(k, step.kind === 'enter'
      ? { status: 'active' }
      : { status: step.kind === 'return' ? 'done' : 'failed', value: step.value })
  }
  return s
})
const current = computed(() => applied.value ? data.steps[applied.value - 1] : undefined)

function describe(step: Step | undefined): string {
  if (!step)
    return `${data.example} を ${data.monad} で評価する`
  const n = byKey.get(step.path.join(','))!
  const what = n.label.match(/^-?\d+$/) ? `定数 ${n.label}` : `「${n.label}」のノード`
  if (step.kind === 'enter')
    return `${what} を評価`
  if (step.kind === 'return')
    return `${what} ⇒ ${step.value}`
  return `${what} で失敗 ⇒ ${step.value}`
}
</script>

<template>
  <div class="trace-view">
    <div class="trace-head">
      <code>{{ data.monad }}</code>
      <span class="trace-count">{{ applied }} / {{ data.steps.length }}</span>
    </div>
    <svg :viewBox="`0 0 ${width} ${height}`" :width="width" :height="height" role="img"
      :aria-label="`${data.example} の評価トレース (${data.monad})`">
      <line v-for="n in nodes.filter(n => n.parent !== undefined)" :key="`e-${n.key}`"
        :x1="pos(n).cx" :y1="pos(n).cy" :x2="pos(byKey.get(n.parent!)!).cx" :y2="pos(byKey.get(n.parent!)!).cy"
        class="edge" />
      <g v-for="n in nodes" :key="n.key" :class="['node', states.get(n.key)!.status,
        { current: current && current.path.join(',') === n.key }]">
        <circle :cx="pos(n).cx" :cy="pos(n).cy" :r="r" />
        <text :x="pos(n).cx" :y="pos(n).cy" class="label">{{ n.label }}</text>
        <text v-if="states.get(n.key)!.value !== undefined" :x="pos(n).cx" :y="pos(n).cy + r + 16" class="value">
          {{ states.get(n.key)!.value }}
        </text>
      </g>
    </svg>
    <div class="trace-desc">{{ describe(current) }}</div>
  </div>
</template>

<style scoped>
.trace-view {
  --tv-fg: #1f2328;
  --tv-muted: #8c959f;
  --tv-edge: #d0d7de;
  --tv-idle: #ffffff;
  --tv-active: #fff1c2;
  --tv-active-stroke: #d4a72c;
  --tv-done: #dafbe1;
  --tv-done-stroke: #2da44e;
  --tv-fail: #ffebe9;
  --tv-fail-stroke: #cf222e;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.25rem;
  color: var(--tv-fg);
}
:global(html.dark) .trace-view {
  --tv-fg: #e6edf3;
  --tv-muted: #7d8590;
  --tv-edge: #30363d;
  --tv-idle: #0d1117;
  --tv-active: #3b2e00;
  --tv-active-stroke: #d29922;
  --tv-done: #0f2e1a;
  --tv-done-stroke: #3fb950;
  --tv-fail: #3d1214;
  --tv-fail-stroke: #f85149;
}
.trace-head { display: flex; gap: 1rem; align-items: baseline; font-size: 0.9rem; }
.trace-count { color: var(--tv-muted); font-variant-numeric: tabular-nums; }
svg { max-width: 100%; height: auto; overflow: visible; }
.edge { stroke: var(--tv-edge); stroke-width: 2; }
.node circle { fill: var(--tv-idle); stroke: var(--tv-muted); stroke-width: 2; transition: all 0.25s; }
.node.active circle { fill: var(--tv-active); stroke: var(--tv-active-stroke); }
.node.done circle { fill: var(--tv-done); stroke: var(--tv-done-stroke); }
.node.failed circle { fill: var(--tv-fail); stroke: var(--tv-fail-stroke); }
.node.current circle { stroke-width: 4; }
.label { fill: var(--tv-fg); font-family: var(--slidev-code-font-family, monospace); font-size: 18px;
  text-anchor: middle; dominant-baseline: central; }
.value { font-family: var(--slidev-code-font-family, monospace); font-size: 14px; text-anchor: middle; fill: var(--tv-done-stroke); }
.node.failed .value { fill: var(--tv-fail-stroke); }
.trace-desc { min-height: 1.5em; font-size: 1rem; }
</style>
