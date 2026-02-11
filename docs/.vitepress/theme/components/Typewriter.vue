<template>
  <div class="hero-container">
    <h1 v-if="staticTitle" class="hero-title">
      {{ staticTitle }}
    </h1>

    <div class="typewriter-wrapper">
      <p class="typewriter-text" aria-label="Animated hero text">
        {{ displayedText }}<span class="cursor">|</span>
      </p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'

const props = withDefaults(defineProps<{
  staticTitle?: string
  words?: string[]
  typeSpeed?: number
  deleteSpeed?: number
  delay?: number
}>(), {
  staticTitle: 'Warp',
  words: () => [
    'A fast networking library.',
    'A simple networking library.',
    'A powerful networking library.',
    'A lightweight networking',
  ],
  typeSpeed: 50,
  deleteSpeed: 20,
  delay: 2000
})

const displayedText = ref('')
const currentWordIndex = ref(0)
const isDeleting = ref(false)
let typingTimeout: any = null

const typeLoop = () => {
  const currentWord = props.words[currentWordIndex.value]
  
  let currentSpeed = props.typeSpeed
  
  if (isDeleting.value) {
    displayedText.value = currentWord.substring(0, displayedText.value.length - 1)
    currentSpeed = props.deleteSpeed
  } else {
    displayedText.value = currentWord.substring(0, displayedText.value.length + 1)
    currentSpeed = props.typeSpeed
  }

  if (!isDeleting.value && displayedText.value === currentWord) {
    currentSpeed = props.delay
    isDeleting.value = true
  } else if (isDeleting.value && displayedText.value === '') {
    isDeleting.value = false
    currentWordIndex.value = (currentWordIndex.value + 1) % props.words.length
    currentSpeed = 500
  }

  typingTimeout = setTimeout(typeLoop, currentSpeed)
}

onMounted(() => {
  typeLoop()
})

onUnmounted(() => {
  clearTimeout(typingTimeout)
})
</script>

<style scoped>
.hero-container {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  justify-content: center;
  width: 100%;
  padding-bottom: 32px;
}

.hero-title {
  margin: 0;
  padding: 0;
  font-weight: 800;
  font-size: 75px;
  line-height: 1;
  letter-spacing: -1.5px;
  
  background: -webkit-linear-gradient(120deg, #fe5234 30%, #fe9934);
  background-clip: text;
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;

  text-shadow: 0 0 40px rgba(254,82,52,.3);
  
  margin-bottom: 16px;
}

.typewriter-wrapper {
  display: flex;
  min-height: 120px;
  align-items: flex-start;
}

.typewriter-text {
  margin: 0;
  border: none;
  padding: 0;
  
  font-weight: 700;
  font-size: 48px; 
  line-height: 1.2;
  letter-spacing: -0.5px;
  color: var(--vp-c-text-1);
  
  max-width: 800px;
  white-space: pre-wrap;
  text-align: left;
}

.cursor {
  display: inline-block;
  margin-left: 4px;
  width: 4px;
  height: 1em;
  background-color: var(--vp-c-brand-1);
  animation: blink 1s step-end infinite;
  vertical-align: text-bottom;
}

@keyframes blink {
  0%, 100% { opacity: 1; }
  50% { opacity: 0; }
}

@media (max-width: 960px) {
  .hero-title {
    font-size: 64px;
  }
  .typewriter-text {
    font-size: 40px;
  }
}

@media (max-width: 640px) {
  .hero-container {
    align-items: center;
    text-align: center;
  }
  
  .typewriter-text {
    text-align: center;
    font-size: 32px;
  }
  
  .hero-title {
    font-size: 48px;
  }
}
</style>