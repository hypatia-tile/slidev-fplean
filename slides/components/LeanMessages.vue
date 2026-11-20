<script setup lang="ts">
// The #guard_msgs-checked messages of the frame on screen (e.g. "don't know how to
// synthesize placeholder" with its context), drawn like Lean's infoview. The goal line
// (⊢ …) is emphasized. No click check here: <LeanCaption> does it on the same slide.
import { useLeanFrame } from '../utils/leanFrame'

const props = withDefaults(defineProps<{ name: string, offset?: number }>(), { offset: 0 })
const { active } = useLeanFrame(props.name, () => props.offset)
const lines = (text: string) => text.split('\n')
</script>

<template>
  <div class="lean-messages">
    <div v-if="!active.messages.length" class="lean-message-none">No messages</div>
    <div v-for="(m, i) in active.messages" :key="`${active.frame}-${i}`" class="lean-message" :class="m.severity">
      <div class="lean-message-head">{{ m.severity }}</div>
      <pre><span v-for="(l, k) in lines(m.text)" :key="k" :class="{ goal: l.startsWith('⊢') }">{{ l }}
</span></pre>
    </div>
  </div>
</template>

<style scoped>
.lean-messages {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  font-size: 0.8rem;
}
.lean-message {
  border-left: 3px solid #888;
  background: var(--slidev-code-background, #f5f5f5);
  border-radius: 4px;
  padding: 0.35rem 0.6rem;
}
.lean-message.error { border-left-color: #cf222e; }
.lean-message.warning { border-left-color: #bf8700; }
.lean-message.info { border-left-color: #0969da; }
.lean-message-head {
  font-size: 0.7rem;
  opacity: 0.6;
  margin-bottom: 0.15rem;
}
.lean-message pre {
  margin: 0;
  font-family: var(--slidev-code-font-family, monospace);
  line-height: 1.45;
  white-space: pre-wrap;
}
.goal {
  font-weight: 700;
  color: var(--slidev-theme-primary, #3b82f6);
}
.lean-message-none {
  opacity: 0.5;
  font-style: italic;
}
</style>
