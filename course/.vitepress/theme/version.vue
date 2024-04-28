<script setup>
import { useData } from "vitepress";
import { ref, computed } from "vue";

const { isDark, title, frontmatter } = useData();

const currentVersion = ref("0.12.0");

const fontColor = computed(() => (isDark.value ? "#fff" : "#000"));
const backgroundColor = computed(() => (isDark.value ? "#14120F" : "#ebedf0"));
</script>

<template>
  <span class="version">Zig 版本：{{ currentVersion }}</span>
</template>

<style scoped>
.version {
  color: v-bind(fontColor);
  border-radius: 15px;
  background-color: v-bind(backgroundColor);
  padding: 5px 10px;
  margin-bottom: 10px;
  display: inline-block;
}
</style>
