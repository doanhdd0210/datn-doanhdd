import { useState, useEffect } from 'react'
import { checkHealth } from '../services/api'
import { useAuth } from '../context/AuthContext'

export default function SettingsPage() {
  const { user } = useAuth()
  const [apiUrl, setApiUrl] = useState(import.meta.env.VITE_API_URL || 'http://localhost:5000')
  const [health, setHealth] = useState(null)
  const [checking, setChecking] = useState(false)

  const checkBackend = async () => {
    setChecking(true)
    setHealth(null)
    try {
      const data = await checkHealth()
      setHealth({ ok: true, data })
    } catch (e) {
      setHealth({ ok: false, error: e.message })
    } finally {
      setChecking(false)
    }
  }

  useEffect(() => { checkBackend() }, [])

  return (
    <div style={{ maxWidth: 620 }}>
      {/* Backend config */}
      <div style={s.card}>
        <h3 style={s.cardTitle}>Kết nối Backend</h3>

        <label style={s.label}>URL Backend .NET API</label>
        <div style={s.row}>
          <input
            style={s.input}
            value={apiUrl}
            onChange={(e) => setApiUrl(e.target.value)}
            placeholder="http://localhost:5000"
          />
          <button onClick={checkBackend} disabled={checking} style={s.btnSecondary}>
            {checking ? 'Đang kiểm tra...' : 'Kiểm tra kết nối'}
          </button>
        </div>
        <p style={s.hint}>
          Cấu hình trong <code>web_admin/.env.local</code>:&nbsp;
          <code>VITE_API_URL=http://localhost:5000</code>
        </p>

        {health && (
          <div style={{ ...s.statusBox, background: health.ok ? '#f0fdf4' : '#fef2f2', borderColor: health.ok ? '#86efac' : '#fca5a5' }}>
            {health.ok ? (
              <span style={{ color: '#166534' }}>
                ✓ Kết nối thành công — Project: <strong>{health.data?.project}</strong>
              </span>
            ) : (
              <span style={{ color: '#dc2626' }}>✗ Lỗi kết nối: {health.error}</span>
            )}
          </div>
        )}
      </div>

      {/* Firebase info */}
      <div style={s.card}>
        <h3 style={s.cardTitle}>Firebase Project</h3>
        <div style={s.infoGrid}>
          <InfoRow label="Project ID" value={import.meta.env.VITE_FIREBASE_PROJECT_ID || '(chưa cấu hình)'} />
          <InfoRow label="Auth Domain" value={import.meta.env.VITE_FIREBASE_AUTH_DOMAIN || '(chưa cấu hình)'} />
        </div>
        <p style={s.hint}>
          Cấu hình trong <code>web_admin/.env.local</code> với các biến <code>VITE_FIREBASE_*</code>
        </p>
      </div>

      {/* Admin info */}
      <div style={s.card}>
        <h3 style={s.cardTitle}>Tài khoản đang đăng nhập</h3>
        <div style={s.infoGrid}>
          <InfoRow label="Email" value={user?.email} />
          <InfoRow label="UID" value={user?.uid} mono />
        </div>
      </div>

      {/* API docs link */}
      <div style={s.card}>
        <h3 style={s.cardTitle}>Tài liệu API</h3>
        <p style={{ color: '#475569', fontSize: 14, marginTop: 0 }}>
          Swagger UI có thể truy cập khi backend đang chạy:
        </p>
        <a href={`${apiUrl}/swagger`} target="_blank" rel="noreferrer" style={s.link}>
          {apiUrl}/swagger ↗
        </a>
      </div>
    </div>
  )
}

function InfoRow({ label, value, mono }) {
  return (
    <div style={{ display: 'flex', alignItems: 'baseline', gap: 12, padding: '8px 0', borderBottom: '1px solid #f1f5f9' }}>
      <span style={{ width: 120, flexShrink: 0, fontSize: 13, color: '#64748b', fontWeight: 500 }}>{label}</span>
      <span style={{ fontSize: 13, color: '#1e293b', fontFamily: mono ? 'monospace' : 'inherit', wordBreak: 'break-all' }}>{value || '—'}</span>
    </div>
  )
}

const s = {
  card: { background: '#fff', borderRadius: 12, border: '1px solid #e2e8f0', padding: 24, marginBottom: 20 },
  cardTitle: { margin: '0 0 16px', fontSize: 16, fontWeight: 700, color: '#1e293b' },
  label: { display: 'block', fontSize: 13, fontWeight: 500, color: '#374151', marginBottom: 8 },
  row: { display: 'flex', gap: 10 },
  input: { flex: 1, padding: '9px 12px', border: '1.5px solid #e2e8f0', borderRadius: 8, fontSize: 14, outline: 'none' },
  btnSecondary: { padding: '9px 16px', background: '#f1f5f9', color: '#334155', border: '1.5px solid #e2e8f0', borderRadius: 8, cursor: 'pointer', fontSize: 14, whiteSpace: 'nowrap' },
  hint: { fontSize: 12, color: '#94a3b8', marginTop: 8, marginBottom: 0 },
  statusBox: { marginTop: 14, padding: '10px 14px', borderRadius: 8, border: '1px solid', fontSize: 14 },
  infoGrid: { display: 'flex', flexDirection: 'column' },
  link: { display: 'inline-block', color: '#1a73e8', fontSize: 14, fontWeight: 500, marginTop: 4 },
}
