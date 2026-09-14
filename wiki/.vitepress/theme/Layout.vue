<script setup lang="ts">
import { withBase } from 'vitepress'
import DefaultTheme from 'vitepress/theme'
</script>

<template>
  <DefaultTheme.Layout>
    <template #home-features-before>
      <section class="story" aria-labelledby="story-title">
        <a class="story-card" :href="withBase('/guide/collection-strategy')">
          <h2 id="story-title">这部影片里，你真正想留下什么？</h2>
          <p>一部喜欢的作品，一个舍不得的画面，或是想好好保存的几分钟。聊聊我为什么做这个项目，以及我理解的收藏。</p>
          <span class="story-link">读读 SakuraMedia 的初衷 <span aria-hidden="true">→</span></span>
        </a>
      </section>
      <h2 class="features-title">功能一览</h2>
    </template>
  </DefaultTheme.Layout>
</template>

<style scoped>
.story,
.features-title {
  margin: 0 auto 32px;
  padding: 0 24px;
  max-width: 1280px;
}

.features-title {
  margin-bottom: 20px;
  color: var(--vp-c-text-1);
  font-size: 24px;
  font-weight: 600;
  line-height: 1.5;
}

.story-card {
  display: block;
  padding: 28px;
  border: 1px solid transparent;
  border-radius: 16px;
  background: var(--vp-c-brand-soft);
  color: var(--vp-c-text-1);
  transition: border-color 0.2s;
}

.story-card:hover {
  border-color: var(--vp-c-brand-1);
}

.story-card:focus-visible {
  outline: 2px solid var(--vp-c-brand-1);
  outline-offset: 4px;
}

.story-card h2 {
  font-size: 24px;
  font-weight: 600;
  line-height: 1.5;
  text-wrap: pretty;
}

.story-card p {
  margin: 12px 0 20px;
  max-width: 760px;
  color: var(--vp-c-text-2);
  font-size: 16px;
  line-height: 1.8;
}

.story-link {
  color: var(--vp-c-brand-1);
  font-size: 15px;
  font-weight: 600;
}

@media (min-width: 640px) {
  .story,
  .features-title {
    padding: 0 48px;
  }

  .story-card {
    padding: 32px 40px;
  }

  .story-card h2 {
    font-size: 28px;
  }
}

@media (min-width: 960px) {
  .story,
  .features-title {
    padding: 0 64px;
  }
}
</style>
