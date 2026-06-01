import axios from 'axios'

const api = axios.create({
  baseURL: import.meta.env.PROD ? '/' : 'http://127.0.0.1:8080',
})

export async function searchBangumi(keyword) {
  const { data } = await api.get('/api/bangumi/search', { params: { keyword } })
  return data.results
}

export async function fetchAnimeList(params = {}) {
  const { data } = await api.get('/api/anime', { params })
  return data
}

export async function createAnime(payload) {
  const { data } = await api.post('/api/anime', payload)
  return data
}

export async function updateAnime(id, payload) {
  const { data } = await api.put(`/api/anime/${id}`, payload)
  return data
}

export async function deleteAnime(id) {
  await api.delete(`/api/anime/${id}`)
}
