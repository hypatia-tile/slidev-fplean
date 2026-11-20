// The generated data of the deck being shown. Every deck shares these components, so
// they find their deck through its headmatter (`deck: 4-3`, checked by the import script)
// and pick slides/generated/<deck>/ out of all decks' data.
//
// The glob bundles every deck's regions.json and trace.json into each deck's build. They
// are small (a few kB per deck); revisit if that changes.
import { configs } from '@slidev/client'

const regionFiles = import.meta.glob('../generated/*/regions.json', { eager: true, import: 'default' })
const traceFiles = import.meta.glob('../generated/*/trace.json', { eager: true, import: 'default' })

const deck = (configs as { deck?: string }).deck

function pick(files: Record<string, unknown>, name: string): unknown {
  if (!deck)
    throw new Error('[lean] the deck\'s headmatter has no `deck:` (e.g. `deck: 4-3`)')
  const data = files[`../generated/${deck}/${name}`]
  if (data === undefined)
    throw new Error(`[lean] no generated/${deck}/${name} — run \`pnpm lean:import ${deck}\``)
  return data
}

export const regions = () => pick(regionFiles, 'regions.json')
export const traces = () => pick(traceFiles, 'trace.json')
