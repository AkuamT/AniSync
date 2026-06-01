<script setup>
const props = defineProps({
  anime: { type: Object, required: true },
})

const emit = defineEmits(['plus-one', 'delete', 'status-change'])

const statusMap = {
  watching: '在看',
  plan: '想看',
  completed: '已看完',
}

function onStatusChange(e) {
  emit('status-change', props.anime, e.target.value)
}

function progressPercent() {
  if (!props.anime.total_episodes) return 0
  return Math.min(100, (props.anime.current_episode / props.anime.total_episodes) * 100)
}
</script>

<template>
  <div class="anime-card">
    <img :src="anime.cover_url" :alt="anime.title" class="anime-cover" />
    <div class="anime-body">
      <div class="anime-title">{{ anime.title }}</div>
      <div class="anime-status">
        <select
          :value="anime.status"
          @change="onStatusChange"
          :class="['status-select', anime.status]"
        >
          <option value="watching">在看</option>
          <option value="plan">想看</option>
          <option value="completed">已看完</option>
        </select>
      </div>
      <div class="anime-progress">
        <div class="progress-text">
          {{ anime.current_episode }} / {{ anime.total_episodes || '?' }} 集
        </div>
        <div v-if="anime.total_episodes > 0" class="progress-bar">
          <div class="progress-fill" :style="{ width: progressPercent() + '%' }"></div>
        </div>
      </div>
      <div class="anime-actions">
        <button class="btn-plus" @click="emit('plus-one', anime)">+1 集</button>
        <button class="btn-delete" @click="emit('delete', anime)">删除</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.anime-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  overflow: hidden;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.06);
  transition: all 0.3s ease;
}
.anime-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.12);
}
.anime-cover {
  width: 100%;
  height: 240px;
  object-fit: cover;
  display: block;
}
.anime-body {
  padding: 12px;
}
.anime-title {
  font-size: 14px;
  font-weight: 600;
  line-height: 1.3;
  margin-bottom: 6px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.anime-status {
  margin-bottom: 8px;
}
.status-select {
  appearance: none;
  -webkit-appearance: none;
  font-size: 11px;
  font-weight: 500;
  padding: 2px 22px 2px 8px;
  border: none;
  border-radius: 10px;
  cursor: pointer;
  outline: none;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='10' height='6'%3E%3Cpath d='M0 0l5 6 5-6z' fill='%23666'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right 6px center;
}
.status-select.watching { background-color: #e6f4ea; color: #1e8e3e; }
.status-select.plan { background-color: #e8f0fe; color: #1a73e8; }
.status-select.completed { background-color: #fce8e6; color: #d93025; }

.anime-progress {
  margin-bottom: 10px;
}
.progress-text {
  font-size: 12px;
  color: var(--text-secondary);
  margin-bottom: 4px;
}
.progress-bar {
  height: 4px;
  background: var(--border);
  border-radius: 2px;
  overflow: hidden;
}
.progress-fill {
  height: 100%;
  background: var(--accent);
  border-radius: 2px;
  transition: width 0.3s;
}

.anime-actions {
  display: flex;
  gap: 6px;
}
.btn-plus {
  flex: 1;
  background: var(--accent);
  color: #fff;
  font-size: 12px;
  font-weight: 500;
  padding: 6px 0;
}
.btn-plus:hover {
  background: var(--accent-hover);
}
.btn-delete {
  background: none;
  color: var(--danger);
  font-size: 12px;
  padding: 6px 10px;
}
.btn-delete:hover {
  background: rgba(255, 59, 48, 0.08);
}
</style>
