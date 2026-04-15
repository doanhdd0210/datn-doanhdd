import { auth } from '../firebase'

// URL backend .NET — đặt trong .env.local: VITE_API_URL=http://localhost:5000
const BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000'

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
