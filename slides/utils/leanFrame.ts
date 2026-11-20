// Which frame of a region sequence is on screen, for <LeanIntent> and <LeanCaption>.
//
// Neither component registers clicks. Frame i of a Magic Move is visible for clicks in
// [offset + S_i, offset + S_i + len_i - 1], where len_i is the number of highlight
// states of that frame (`{*|2|3}` → 3), S_i the sum of the earlier ones, and `offset`
// the number of clicks consumed on the slide before the Magic Move starts (0 when the
// Magic Move is the first click consumer).
//
// Slidev does not expose which click range belongs to which Magic Move, so the offset
// cannot be read back. `checkClicks` compares the slide's total click count with what
// the frame layout implies and reports a mismatch, so a wrong offset does not go unnoticed.
import { useSlideContext } from '@slidev/client'
import { computed, nextTick, onMounted, ref } from 'vue'
// Slidev loads this stylesheet only when slides.md itself contains math; frame texts
// rendered by the import script need it regardless.
import 'katex/dist/katex.min.css'
import { regions } from './deckData'

export type Region = {
  name: string
  frame: number
  range: string
  captions: string[]
  intents: string[]
  /** The same texts as HTML (`inline code`, $math$ via KaTeX), rendered by the import script. */
  captionsHtml: string[]
  intentsHtml: string[]
  /** #guard_msgs-checked messages of non-#eval commands in the frame (shown by <LeanMessages>). */
  messages: { severity: string, text: string }[]
}

export function useLeanFrame(name: string, offset: () => number) {
  const frames = (regions() as Region[])
    .filter(r => r.name === name)
    .sort((a, b) => a.frame - b.frame)
  if (!frames.length)
    throw new Error(`[lean] no region "${name}" in this deck's generated/regions.json — run \`pnpm lean:import\``)

  const lens = frames.map(f => f.range ? f.range.slice(1, -1).split('|').length : 1)
  const starts = lens.map((_, i) => lens.slice(0, i).reduce((a, b) => a + b, 0))

  const { $clicks: clicks, $clicksContext: clicksContext } = useSlideContext()
  const active = computed(() => {
    const c = clicks.value - offset()
    let i = 0
    while (i + 1 < frames.length && c >= starts[i + 1])
      i++
    return frames[i]
  })

  /** Reports (on screen in dev, and in the console) when the slide's clicks cannot match. */
  function checkClicks() {
    // A Magic Move consumes sum(len_i) - 1 clicks; a single code block with a range
    // consumes len - 1. Fewer clicks on the slide means the frames cannot line up; more
    // means something else consumes clicks, which is fine only after the code.
    const expected = offset() + lens.reduce((a, b) => a + b, 0) - 1
    const mismatch = ref('')
    onMounted(() => nextTick(() => {
      const total = clicksContext?.total
      if (total === undefined || total === expected)
        return
      mismatch.value = `region "${name}": slide has ${total} clicks, frames imply ${expected} (offset ${offset()}). `
        + (total < expected ? 'The offset is too large.' : 'If something before the code consumes clicks, set `offset`.')
      console.warn(`[lean] ${mismatch.value}`)
    }))
    return mismatch
  }

  return { frames, active, checkClicks }
}
