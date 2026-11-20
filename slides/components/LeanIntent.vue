<script setup lang="ts">
// The `-- intent:` text (what this code is for, and why it has this shape) of the frame
// on screen, shown above the code. The click check is done by <LeanCaption> when the
// slide has one; pass `check` to do it here instead.
import { computed } from 'vue'
import { useLeanFrame } from '../utils/leanFrame'

const props = withDefaults(defineProps<{ name: string, offset?: number, check?: boolean }>(), { offset: 0, check: false })
const { frames, active, checkClicks } = useLeanFrame(props.name, () => props.offset)
const mismatch = props.check ? checkClicks() : null
const dev = import.meta.env.DEV
// A frame without its own intent keeps the latest earlier one: the intent says what the
// sequence is doing, and later frames often only carry it out.
const shown = computed(() => frames.filter(f => f.frame <= active.value.frame && f.intents.length).at(-1))
const html = computed(() => shown.value?.intentsHtml.join('<br>') ?? '')
</script>

<template>
  <div v-if="html" class="lean-intent" v-html="html" />
  <div v-if="dev && mismatch" class="lean-intent-warning">{{ mismatch }}</div>
</template>

<style scoped>
.lean-intent {
  margin-bottom: 0.75rem;
  padding-left: 0.75rem;
  border-left: 3px solid var(--slidev-theme-primary, #3b82f6);
  font-size: 1rem;
  line-height: 1.5;
}
.lean-intent-warning {
  margin-bottom: 0.5rem;
  font-size: 0.75rem;
  color: #cf222e;
}
</style>
