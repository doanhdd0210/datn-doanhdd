import { auth } from '../firebase'

// URL backend .NET — đặt trong .env.local: VITE_API_BASE_URL=http://localhost:5000
const BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:5000'

async function getToken() {
  const user = auth.currentUser
  if (!user) throw new Error('Not authenticated')
  return user.getIdToken()
}

async function request(method, path, body) {
  const token = await getToken()
  const res = await fetch(`${BASE_URL}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: body ? JSON.stringify(body) : undefined,
  })

  const json = await res.json()
  if (!res.ok || !json.success) {
    throw new Error(json.error || json.message || `HTTP ${res.status}`)
  }
  return json.data
}

// ─── Users ───────────────────────────────────────────────────────────────────

export const usersApi = {
  list: (max = 500) => request('GET', `/api/users?max=${max}`),
  get: (uid) => request('GET', `/api/users/${uid}`),
  create: (data) => request('POST', '/api/users', data),
  update: (uid, data) => request('PUT', `/api/users/${uid}`, data),
  delete: (uid) => request('DELETE', `/api/users/${uid}`),
  setDisabled: (uid, disabled) => request('PATCH', `/api/users/${uid}/disable`, { disabled }),
  setAdmin: (uid, isAdmin) => request('PATCH', `/api/users/${uid}/admin`, { isAdmin }),
}

// ─── Admins ──────────────────────────────────────────────────────────────────

export const adminsApi = {
  list: () => request('GET', '/api/admins'),
  grant: (uid) => request('POST', `/api/admins/${uid}`),
  revoke: (uid) => request('DELETE', `/api/admins/${uid}`),
}

// ─── Notifications ───────────────────────────────────────────────────────────

export const notificationsApi = {
  send: (data) => request('POST', '/api/notifications/send', data),
  history: (limit = 50) => request('GET', `/api/notifications/history?limit=${limit}`),
  subscribe: (tokens, topic) => request('POST', '/api/notifications/topic/subscribe', { tokens, topic }),
  unsubscribe: (tokens, topic) => request('POST', '/api/notifications/topic/unsubscribe', { tokens, topic }),
}

// ─── Health ──────────────────────────────────────────────────────────────────

export const checkHealth = () =>
  fetch(`${BASE_URL}/health`).then((r) => r.json())

// ─── Topics ──────────────────────────────────────────────────────────────────
export const topicsApi = {
  list: () => request('GET', '/api/topics'),
  get: (id) => request('GET', `/api/topics/${id}`),
  create: (data) => request('POST', '/api/topics', data),
  update: (id, data) => request('PUT', `/api/topics/${id}`, data),
  delete: (id) => request('DELETE', `/api/topics/${id}`),
}

// ─── Lessons ─────────────────────────────────────────────────────────────────
export const lessonsApi = {
  list: (topicId) => request('GET', topicId ? `/api/lessons?topicId=${topicId}` : '/api/lessons'),
  get: (id) => request('GET', `/api/lessons/${id}`),
  create: (data) => request('POST', '/api/lessons', data),
  update: (id, data) => request('PUT', `/api/lessons/${id}`, data),
  delete: (id) => request('DELETE', `/api/lessons/${id}`),
}

// ─── Questions ───────────────────────────────────────────────────────────────
export const questionsApi = {
  list: (lessonId) => request('GET', `/api/questions?lessonId=${lessonId}`),
  create: (data) => request('POST', '/api/questions', data),
  update: (id, data) => request('PUT', `/api/questions/${id}`, data),
  delete: (id) => request('DELETE', `/api/questions/${id}`),
}

// ─── Code Snippets ────────────────────────────────────────────────────────────
export const codeSnippetsApi = {
  list: (topicId) => request('GET', topicId ? `/api/code-snippets?topicId=${topicId}` : '/api/code-snippets'),
  get: (id) => request('GET', `/api/code-snippets/${id}`),
  create: (data) => request('POST', '/api/code-snippets', data),
  update: (id, data) => request('PUT', `/api/code-snippets/${id}`, data),
  delete: (id) => request('DELETE', `/api/code-snippets/${id}`),
}

// ─── QA ──────────────────────────────────────────────────────────────────────
export const qaApi = {
  list: (page = 1) => request('GET', `/api/qa?page=${page}`),
  get: (id) => request('GET', `/api/qa/${id}`),
  delete: (id) => request('DELETE', `/api/qa/${id}`),
}

// ─── Progress/Stats ──────────────────────────────────────────────────────────
export const statsApi = {
  leaderboard: () => request('GET', '/api/friends/leaderboard'),
}
