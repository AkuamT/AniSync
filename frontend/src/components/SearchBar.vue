<script setup>
import { ref } from 'vue'
import { searchBangumi } from '../api'

const emit = defineEmits(['add'])

const keyword = ref('')
const results = ref([])
const searching = ref(false)
const showResults = ref(false)

async function handleSearch() {
  const q = keyword.value.trim()
  if (!q) return
  searching.value = true
  showResults.value = true
  try {
    results.value = await searchBangumi(q)
  } catch {
    alert('搜索失败，请检查后端是否运行')
    results.value = []
  } finally {
    searching.value = false
  }
}

function close() {
  showResults.value = false
}

function addAnime(item) {
  emit('add', item)
  showResults.value = false
  keyword.value = ''
  results.value = []
}
</script>

<template>
  <section class="search-section">
    <div class="search-bar">
      <input
        v-model="keyword"
        placeholder="搜索番剧..."
        @keyup.enter="handleSearch"
      />
      <button class="btn-primary" @click="handleSearch" :disabled="searching">
        {{ searching ? '搜索中...' : '搜索' }}
      </button>
    </div>

    <div v-if="showResults" class="search-results">
      <div class="search-results-header">
        <h3>搜索结果</h3>
        <button class="btn-ghost" @click="close">关闭</button>
      </div>
      <div v-if="results.length === 0 && !searching" class="empty">
        未找到相关番剧，换个名字试试吧~
      </div>
      <div class="result-grid">
        <div v-for="item in results" :key="item.bangumi_id" class="result-card">
          <img :src="item.cover_url" :alt="item.title" class="result-cover" />
          <div class="result-info">
            <div class="result-title">{{ item.title }}</div>
            <div class="result-meta">
              {{ item.total_episodes ? item.total_episodes + '集' : '集数未知' }}
              <span v-if="item.air_date"> · {{ item.air_date.slice(0, 7) }}</span>
            </div>
            <button class="btn-add" @click="addAnime(item)">+ 加入追番</button>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.search-section {
  margin-bottom: 36px;
}
.search-bar {
  display: flex;
  gap: 8px;
}
.search-bar input {
  flex: 1;
  padding: 10px 14px;
  font-size: 15px;
}
.btn-primary {
  background: var(--accent);
  color: #fff;
  padding: 10px 20px;
  font-size: 15px;
  font-weight: 500;
}
.btn-primary:hover {
  background: var(--accent-hover);
}
.btn-primary:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.search-results {
  margin-top: 16px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 16px;
}
.search-results-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12px;
}
.search-results-header h3 {
  font-size: 16px;
  font-weight: 600;
}
.btn-ghost {
  background: none;
  color: var(--text-secondary);
  font-size: 13px;
  padding: 4px 8px;
}
.btn-ghost:hover {
  color: var(--text);
}
.result-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 12px;
}
.result-card {
  display: flex;
  gap: 12px;
  padding: 10px;
  border: 1px solid var(--border);
  border-radius: 10px;
  transition: box-shadow 0.2s;
}
.result-card:hover {
  box-shadow: var(--shadow);
}
.result-cover {
  width: 64px;
  height: 90px;
  object-fit: cover;
  border-radius: 6px;
  flex-shrink: 0;
}
.result-info {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  min-width: 0;
}
.result-title {
  font-size: 14px;
  font-weight: 600;
  line-height: 1.3;
  overflow: hidden;
  text-overflow: ellipsis;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
}
.result-meta {
  font-size: 12px;
  color: var(--text-secondary);
}
.btn-add {
  background: var(--success);
  color: #fff;
  font-size: 12px;
  font-weight: 500;
  padding: 5px 10px;
  border-radius: 6px;
  align-self: flex-start;
}
.btn-add:hover {
  opacity: 0.9;
}
.empty {
  text-align: center;
  padding: 32px 0;
  color: var(--text-secondary);
  font-size: 14px;
}
</style>
