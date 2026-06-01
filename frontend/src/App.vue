<script setup>
import { ref, computed, onMounted } from 'vue'
import { fetchAnimeList, createAnime, updateAnime, deleteAnime } from './api'
import SearchBar from './components/SearchBar.vue'
import AnimeCard from './components/AnimeCard.vue'

const animeList = ref([])
const loading = ref(false)

// 状态 Tab
const activeTab = ref('watching')

const filteredList = computed(() =>
  animeList.value.filter((a) => a.status === activeTab.value)
)

const tabCounts = computed(() => {
  const counts = { watching: 0, plan: 0, completed: 0 }
  animeList.value.forEach((a) => {
    if (counts[a.status] !== undefined) counts[a.status]++
  })
  return counts
})

// Toast
const toast = ref({ show: false, message: '' })
let toastTimer = null

function showToast(message) {
  toast.value = { show: true, message }
  clearTimeout(toastTimer)
  toastTimer = setTimeout(() => { toast.value.show = false }, 2500)
}

async function loadList() {
  loading.value = true
  try {
    animeList.value = await fetchAnimeList({ page_size: 100 })
  } finally {
    loading.value = false
  }
}

async function handleAdd(item) {
  try {
    await createAnime({
      title: item.title,
      cover_url: item.cover_url,
      description: item.description,
      total_episodes: item.total_episodes,
      bangumi_id: item.bangumi_id,
      air_date: item.air_date,
      status: 'plan',
    })
    await loadList()
    showToast(`已添加「${item.title}」`)
  } catch {
    showToast('添加失败')
  }
}

async function handlePlusOne(anime) {
  const next = anime.current_episode + 1
  const done = anime.total_episodes > 0 && next >= anime.total_episodes
  await updateAnime(anime.id, {
    current_episode: next,
    status: done ? 'completed' : anime.status,
  })
  await loadList()
  showToast(`进度更新至第 ${next} 集`)
}

async function handleDelete(anime) {
  if (!confirm(`确认删除「${anime.title}」？`)) return
  await deleteAnime(anime.id)
  await loadList()
  showToast(`已删除「${anime.title}」`)
}

async function handleStatusChange(anime, newStatus) {
  try {
    await updateAnime(anime.id, { status: newStatus })
    await loadList()
    const labels = { watching: '在看', plan: '想看', completed: '已看完' }
    showToast(`「${anime.title}」已移至${labels[newStatus]}`)
  } catch {
    showToast('状态更新失败')
  }
}

onMounted(loadList)
</script>

<template>
  <div class="app">
    <!-- Toast -->
    <Transition name="toast">
      <div v-if="toast.show" class="toast">{{ toast.message }}</div>
    </Transition>

    <header class="header">
      <h1>AniSync</h1>
      <p class="subtitle">追番记录管理</p>
    </header>

    <SearchBar @add="handleAdd" />

    <section class="anime-section">
      <div class="section-header">
        <h2>我的追番</h2>
        <span class="count">{{ filteredList.length }} 部</span>
      </div>

      <!-- 状态 Tab -->
      <div class="tabs">
        <button
          :class="['tab', { active: activeTab === 'watching' }]"
          @click="activeTab = 'watching'"
        >
          在看 <span class="tab-count">{{ tabCounts.watching }}</span>
        </button>
        <button
          :class="['tab', { active: activeTab === 'plan' }]"
          @click="activeTab = 'plan'"
        >
          想看 <span class="tab-count">{{ tabCounts.plan }}</span>
        </button>
        <button
          :class="['tab', { active: activeTab === 'completed' }]"
          @click="activeTab = 'completed'"
        >
          已看完 <span class="tab-count">{{ tabCounts.completed }}</span>
        </button>
      </div>

      <div v-if="loading" class="empty">加载中...</div>
      <div v-else-if="filteredList.length === 0" class="empty">
        该分类下暂无番剧
      </div>

      <div v-else class="anime-grid">
        <AnimeCard
          v-for="anime in filteredList"
          :key="anime.id"
          :anime="anime"
          @plus-one="handlePlusOne"
          @delete="handleDelete"
          @status-change="handleStatusChange"
        />
      </div>
    </section>
  </div>
</template>

<style scoped>
.app {
  max-width: 960px;
  margin: 0 auto;
  padding: 24px 20px 60px;
}

.header {
  text-align: center;
  margin-bottom: 32px;
}
.header h1 {
  font-size: 28px;
  font-weight: 700;
  letter-spacing: -0.5px;
}
.subtitle {
  color: var(--text-secondary);
  font-size: 14px;
  margin-top: 4px;
}

.anime-section {
  margin-top: 8px;
}
.section-header {
  display: flex;
  align-items: baseline;
  gap: 8px;
  margin-bottom: 16px;
}
.section-header h2 {
  font-size: 20px;
  font-weight: 700;
}
.count {
  font-size: 13px;
  color: var(--text-secondary);
}
.empty {
  text-align: center;
  padding: 48px 0;
  color: var(--text-secondary);
  font-size: 14px;
}

/* Tabs */
.tabs {
  display: flex;
  gap: 4px;
  margin-bottom: 20px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 4px;
}
.tab {
  flex: 1;
  padding: 8px 0;
  border: none;
  background: transparent;
  font-size: 13px;
  font-weight: 500;
  color: var(--text-secondary);
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s ease;
}
.tab:hover {
  background: rgba(0, 0, 0, 0.03);
}
.tab.active {
  background: var(--accent);
  color: #fff;
}
.tab-count {
  font-size: 11px;
  opacity: 0.7;
  margin-left: 2px;
}

.anime-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: 16px;
}

/* Toast */
.toast {
  position: fixed;
  top: 20px;
  left: 50%;
  transform: translateX(-50%);
  background: #1d1d1f;
  color: #fff;
  font-size: 14px;
  padding: 10px 24px;
  border-radius: 8px;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.18);
  z-index: 1000;
  white-space: nowrap;
}
.toast-enter-active,
.toast-leave-active {
  transition: opacity 0.3s ease, transform 0.3s ease;
}
.toast-enter-from,
.toast-leave-to {
  opacity: 0;
  transform: translateX(-50%) translateY(-12px);
}
</style>
