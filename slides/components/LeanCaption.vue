<script setup lang="ts">
// The `-- caption:` text (the takeaway) of the frame on screen, shown under the code.
// Frame tracking and the click check are in ../utils/leanFrame.ts.
import { computed } from 'vue'
import { useLeanFrame } from '../utils/leanFrame'

const props = withDefaults(defineProps<{ name: string, offset?: number }>(), { offset: 0 })
const { frames, active, checkClicks } = useLeanFrame(props.name, () => props.offset)
const mismatch = checkClicks()
const dev = import.meta.env.DEV
const html = computed(() => active.value.captionsHtml.join('<br>'))
</script>

<template>
  <div v-if="dev && mismatch" class="lean-caption-warning">{{ mismatch }}</div>
  <div v-if="active.captions.length" class="lean-caption">
    <span v-if="frames.length > 1" class="lean-caption-frame">{{ active.frame }} / {{ frames.length }}</span>
    <span v-html="html" />
  </div>
</template>

<style scoped>
.lean-caption {
  display: flex;
  gap: 0.75rem;
  align-items: baseline;
  margin-top: 0.75rem;
  font-size: 0.95rem;
  line-height: 1.5;
}
.lean-caption-warning {
  margin-top: 0.5rem;
  font-size: 0.75rem;
  color: #cf222e;
}
.lean-caption-frame {
  flex: none;
  font-variant-numeric: tabular-nums;
  opacity: 0.5;
  font-size: 0.8rem;
}
</style>
