import { useState, useEffect, useCallback } from 'react'
import { notificationsApi, usersApi } from '../services/api'

const TARGET_OPTS = [
  { value: 'broadcastAll', label: 'Tất cả người dùng (topic "all")' },
  { value: 'topic', label: 'Topic cụ thể' },
  { value: 'uid', label: 'Người dùng cụ thể (theo UID)' },
  { value: 'token', label: 'FCM Token cụ thể' },
]

export default function NotificationsPage() {
  const [tab, setTab] = useState('send') // 'send' | 'history'
  const [users, setUsers] = useState([])
  const [history, setHistory] = useState([])
  const [loadingHistory, setLoadingHistory] = useState(false)
  const [sending, setSending] = useState(false)
  const [result, setResult] = useState(null)

  const [form, setForm] = useState({
    title: '',
    body: '',
    imageUrl: '',
    targetType: 'broadcastAll',
    targetValue: '',
  })

  useEffect(() => {
    usersApi.list(200).then(setUsers).catch(() => {})
  }, [])

  const loadHistory = useCallback(async () => {
    setLoadingHistory(true)
    try {
      const data = await notificationsApi.history(50)
      setHistory(data ?? [])
    } catch (e) {
      alert('Không thể tải lịch sử: ' + e.message)
    } finally {
      setLoadingHistory(false)
    }
  }, [])

  useEffect(() => {
    if (tab === 'history') loadHistory()
  }, [tab, loadHistory])

  const handleSend = async (e) => {
    e.preventDefault()
    if (!form.title || !form.body) return alert('Vui lòng nhập tiêu đề và nội dung')
    setSending(true)
    setResult(null)
    try {
      const payload = {
        title: form.title,
        body: form.body,
        imageUrl: form.imageUrl || undefined,
      }
      if (form.targetType === 'broadcastAll') payload.broadcastAll = true
      else if (form.targetType === 'topic') payload.topic = form.targetValue
      else if (form.targetType === 'uid') payload.uid = form.targetValue
      else if (form.targetType === 'token') payload.token = form.targetValue

      const res = await notificationsApi.send(payload)
      setResult({ ok: true, msg: 'Đã gửi thông báo thành công!', detail: res?.result })
      setForm((f) => ({ ...f, title: '', body: '', imageUrl: '', targetValue: '' }))
    } catch (e) {
      setResult({ ok: false, msg: e.message })
    } finally {
      setSending(false)
    }
  }

  return (
    <div>
      {/* Tabs */}
      <div style={s.tabs}>
        {[['send', '📤 Gửi thông báo'], ['history', '📋 Lịch sử']].map(([id, label]) => (
          <button key={id} onClick={() => setTab(id)} style={{ ...s.tab, ...(tab === id ? s.tabActive : {}) }}>
            {label}
          </button>
        ))}
      </div>

      {/* ── Send Tab ─────────────────────────────────────────────────── */}
      {tab === 'send' && (
        <div style={s.card}>
          <h3 style={s.cardTitle}>Soạn thông báo push</h3>

          <form onSubmit={handleSend}>
            {/* Target */}
            <label style={s.label}>Đối tượng nhận</label>
            <select
              value={form.targetType}
              onChange={(e) => setForm({ ...form, targetType: e.target.value, targetValue: '' })}
              style={s.select}
            >
              {TARGET_OPTS.map((o) => (
                <option key={o.value} value={o.value}>{o.label}</option>
              ))}
            </select>

            {form.targetType === 'uid' && (
              <>
                <label style={s.label}>Chọn người dùng</label>
                <select
                  value={form.targetValue}
                  onChange={(e) => setForm({ ...form, targetValue: e.target.value })}
                  style={s.select}
                >
                  <option value="">-- Chọn người dùng --</option>
                  {users.map((u) => (
                    <option key={u.uid} value={u.uid}>
                      {u.displayName || u.email} ({u.uid.slice(0, 8)}…)
                    </option>
                  ))}
                </select>
              </>
            )}

            {(form.targetType === 'topic' || form.targetType === 'token') && (
              <>
                <label style={s.label}>
                  {form.targetType === 'topic' ? 'Tên topic' : 'FCM Token'}
                </label>
                <input
                  style={s.input}
                  placeholder={form.targetType === 'topic' ? 'vd: news, promo...' : 'FCM device token...'}
                  value={form.targetValue}
                  onChange={(e) => setForm({ ...form, targetValue: e.target.value })}
                />
              </>
            )}

            {/* Title */}
            <label style={s.label}>Tiêu đề *</label>
            <input
              style={s.input}
              placeholder="Tiêu đề thông báo"
              value={form.title}
              onChange={(e) => setForm({ ...form, title: e.target.value })}
              required
            />

            {/* Body */}
            <label style={s.label}>Nội dung *</label>
            <textarea
              style={{ ...s.input, height: 90, resize: 'vertical' }}
              placeholder="Nội dung thông báo..."
              value={form.body}
              onChange={(e) => setForm({ ...form, body: e.target.value })}
              required
            />

            {/* Image URL */}
            <label style={s.label}>URL hình ảnh (tuỳ chọn)</label>
            <input
              style={s.input}
              placeholder="https://..."
              value={form.imageUrl}
              onChange={(e) => setForm({ ...form, imageUrl: e.target.value })}
            />

            {/* Preview */}
            {(form.title || form.body) && (
              <div style={s.preview}>
                <div style={s.previewLabel}>Xem trước</div>
                <div style={s.previewCard}>
                  <div style={s.previewTitle}>{form.title || 'Tiêu đề'}</div>
                  <div style={s.previewBody}>{form.body || 'Nội dung...'}</div>
                </div>
              </div>
            )}

            {result && (
              <div style={{ ...s.resultBox, background: result.ok ? '#f0fdf4' : '#fef2f2', borderColor: result.ok ? '#86efac' : '#fca5a5', color: result.ok ? '#166534' : '#dc2626' }}>
                {result.ok ? '✓ ' : '✗ '}{result.msg}
                {result.detail && <span style={{ marginLeft: 8, opacity: 0.7 }}>({result.detail})</span>}
              </div>
            )}

            <button type="submit" disabled={sending} style={{ ...s.btnPrimary, marginTop: 20, width: '100%' }}>
              {sending ? 'Đang gửi...' : '📤 Gửi thông báo'}
            </button>
          </form>
        </div>
      )}

      {/* ── History Tab ───────────────────────────────────────────────── */}
      {tab === 'history' && (
        <div>
          <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 12 }}>
            <button onClick={loadHistory} style={s.btnSecondary}>⟳ Làm mới</button>
          </div>
          {loadingHistory ? (
            <div style={s.loading}>Đang tải lịch sử...</div>
          ) : history.length === 0 ? (
            <div style={s.loading}>Chưa có thông báo nào được gửi.</div>
          ) : (
            <div style={s.tableWrap}>
              <table style={s.table}>
                <thead>
                  <tr style={s.thead}>
                    <th style={s.th}>Tiêu đề / Nội dung</th>
                    <th style={s.th}>Đối tượng</th>
                    <th style={s.th}>Trạng thái</th>
                    <th style={s.th}>Thời gian</th>
                  </tr>
                </thead>
                <tbody>
                  {history.map((h) => (
                    <tr key={h.id} style={s.tr}>
                      <td style={s.td}>
                        <div style={{ fontWeight: 600 }}>{h.title}</div>
                        <div style={{ fontSize: 12, color: '#64748b' }}>{h.body}</div>
                      </td>
                      <td style={s.td}>
                        <span style={s.badge}>{h.target}</span>
                        {h.targetValue && <div style={{ fontSize: 11, color: '#94a3b8', marginTop: 2 }}>{h.targetValue.slice(0, 20)}…</div>}
                      </td>
                      <td style={s.td}>
                        <span style={{ ...s.statusDot, background: h.success ? '#22c55e' : '#ef4444' }} />
                        {h.success ? 'Thành công' : 'Thất bại'}
                      </td>
                      <td style={{ ...s.td, fontSize: 12, color: '#64748b' }}>
                        {new Date(h.sentAt).toLocaleString('vi-VN')}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}
    </div>
  )
}

const s = {
  tabs: { display: 'flex', gap: 4, marginBottom: 24, borderBottom: '2px solid #e2e8f0' },
  tab: { padding: '10px 20px', border: 'none', background: 'transparent', cursor: 'pointer', fontSize: 14, fontWeight: 500, color: '#64748b', borderBottom: '2px solid transparent', marginBottom: -2 },
  tabActive: { color: '#1a73e8', borderBottomColor: '#1a73e8' },
  card: { background: '#fff', borderRadius: 12, border: '1px solid #e2e8f0', padding: 28, maxWidth: 560 },
  cardTitle: { margin: '0 0 20px', fontSize: 18, fontWeight: 700, color: '#1e293b' },
  label: { display: 'block', fontSize: 13, fontWeight: 500, color: '#374151', marginBottom: 6, marginTop: 16 },
  input: { width: '100%', padding: '9px 12px', border: '1.5px solid #e2e8f0', borderRadius: 8, fontSize: 14, outline: 'none', boxSizing: 'border-box' },
  select: { width: '100%', padding: '9px 12px', border: '1.5px solid #e2e8f0', borderRadius: 8, fontSize: 14, outline: 'none', background: '#fff' },
  preview: { marginTop: 20, padding: 16, background: '#f8fafc', borderRadius: 10, border: '1px dashed #cbd5e1' },
  previewLabel: { fontSize: 11, fontWeight: 600, color: '#94a3b8', textTransform: 'uppercase', marginBottom: 10 },
  previewCard: { background: '#fff', borderRadius: 8, padding: '12px 14px', boxShadow: '0 1px 4px rgba(0,0,0,0.08)' },
  previewTitle: { fontWeight: 700, fontSize: 15, color: '#1e293b', marginBottom: 4 },
  previewBody: { fontSize: 13, color: '#475569' },
  resultBox: { marginTop: 16, padding: '12px 16px', borderRadius: 8, border: '1px solid', fontSize: 14 },
  btnPrimary: { padding: '10px 20px', background: '#1a73e8', color: '#fff', border: 'none', borderRadius: 8, cursor: 'pointer', fontWeight: 600, fontSize: 14 },
  btnSecondary: { padding: '8px 16px', background: '#f1f5f9', color: '#334155', border: '1.5px solid #e2e8f0', borderRadius: 8, cursor: 'pointer', fontSize: 14 },
  loading: { textAlign: 'center', padding: 60, color: '#94a3b8' },
  tableWrap: { overflowX: 'auto', borderRadius: 12, border: '1px solid #e2e8f0', background: '#fff' },
  table: { width: '100%', borderCollapse: 'collapse', fontSize: 14 },
  thead: { background: '#f8fafc' },
  th: { padding: '12px 16px', textAlign: 'left', fontWeight: 600, color: '#374151', borderBottom: '1px solid #e2e8f0' },
  tr: { borderBottom: '1px solid #f1f5f9' },
  td: { padding: '12px 16px', verticalAlign: 'middle' },
  badge: { display: 'inline-block', padding: '2px 10px', borderRadius: 99, background: '#ede9fe', color: '#6d28d9', fontSize: 12, fontWeight: 500 },
  statusDot: { display: 'inline-block', width: 8, height: 8, borderRadius: '50%', marginRight: 6 },
}
