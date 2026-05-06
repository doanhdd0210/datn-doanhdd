import { useState, useEffect } from 'react'
import { Target, Zap, X, Check } from 'lucide-react'
import { checkHealth, settingsApi } from '../services/api'
import { useAuth } from '../context/AuthContext'

export default function SettingsPage() {
  const { user } = useAuth()
  const [apiUrl, setApiUrl] = useState(import.meta.env.VITE_API_BASE_URL || 'http://localhost:5000')
  const [health, setHealth] = useState(null)
  const [checking, setChecking] = useState(false)

  // Daily goal bonus config
  const [bonusConfigs, setBonusConfigs] = useState([
    { goalXp: 20,  bonusXp: 5,  usersCount: 0 },
    { goalXp: 50,  bonusXp: 15, usersCount: 0 },
    { goalXp: 100, bonusXp: 35, usersCount: 0 },
  ])
  const [bonusLoading, setBonusLoading] = useState(true)
  const [bonusSaving, setBonusSaving] = useState(false)
  const [bonusMsg, setBonusMsg] = useState(null) // { ok, text }

  useEffect(() => {
    settingsApi.getDailyGoalBonuses()
      .then(data => {
        if (Array.isArray(data) && data.length > 0) {
          setBonusConfigs(data.map(d => ({ goalXp: d.goalXp, bonusXp: d.bonusXp, usersCount: d.usersCount ?? 0 })))
        }
      })
      .catch(() => {})
      .finally(() => setBonusLoading(false))
  }, [])

  const saveBonusConfigs = async () => {
    setBonusSaving(true)
    setBonusMsg(null)
    try {
      await settingsApi.updateDailyGoalBonuses(bonusConfigs)
      setBonusMsg({ ok: true, text: 'Lưu thành công!' })
    } catch (e) {
      setBonusMsg({ ok: false, text: e.message })
    } finally {
      setBonusSaving(false)
      setTimeout(() => setBonusMsg(null), 3000)
    }
  }

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
          <code>VITE_API_BASE_URL=http://localhost:5000</code>
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

      {/* Daily Goal Bonus Config */}
      <div style={s.card}>
        <h3 style={{ ...s.cardTitle, display:'flex', alignItems:'center', gap:6 }}><Target size={18} color="#f59e0b"/> Thưởng hoàn thành mục tiêu hàng ngày</h3>
        <p style={{ color: '#64748b', fontSize: 13, marginTop: 0, marginBottom: 16 }}>
          Khi người dùng đạt đủ XP mục tiêu trong ngày, họ sẽ nhận được bonus XP này (tối đa 1 lần/ngày).
        </p>

        {bonusLoading ? (
          <p style={{ color: '#94a3b8', fontSize: 13 }}>Đang tải...</p>
        ) : (
          <>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginBottom: 20 }}>
              {bonusConfigs.map((cfg, i) => {
                const tiers = [
                  { label: 'Cơ bản',     color: '#22c55e', bg: '#f0fdf4', border: '#bbf7d0' },
                  { label: 'Trung bình', color: '#3b82f6', bg: '#eff6ff', border: '#bfdbfe' },
                  { label: 'Thách thức', color: '#f59e0b', bg: '#fffbeb', border: '#fde68a' },
                ]
                const tier = tiers[i] ?? { label: `Cấp ${i + 1}`, color: '#94a3b8', bg: '#f8fafc', border: '#e2e8f0' }
                return (
                  <div key={i} style={{ display: 'grid', gridTemplateColumns: '180px 1fr 1fr 80px', alignItems: 'center', gap: 0, background: '#fff', borderRadius: 12, border: `1.5px solid ${tier.border}`, overflow: 'hidden' }}>
                    {/* Tier badge */}
                    <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '14px 16px', background: tier.bg, borderRight: `1.5px solid ${tier.border}` }}>
                      <div style={{ width: 36, height: 36, borderRadius: 10, background: tier.color + '22', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        <Target size={18} color={tier.color} />
                      </div>
                      <div>
                        <div style={{ fontWeight: 700, fontSize: 13, color: '#1e293b' }}>Mục tiêu</div>
                        <div style={{ fontSize: 11, fontWeight: 600, color: tier.color, marginTop: 1 }}>{tier.label}</div>
                      </div>
                    </div>
                    {/* Goal XP */}
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '14px 16px', borderRight: `1px solid #f1f5f9` }}>
                      <span style={{ fontSize: 12, color: '#94a3b8', whiteSpace: 'nowrap' }}>Mục tiêu</span>
                      <input type="number" min={1} max={9999} value={cfg.goalXp}
                        onChange={e => { const val = Math.max(1, parseInt(e.target.value) || 1); setBonusConfigs(prev => prev.map((c, j) => j === i ? { ...c, goalXp: val } : c)) }}
                        style={{ width: 68, padding: '6px 10px', border: '1.5px solid #e2e8f0', borderRadius: 8, fontSize: 15, fontWeight: 700, textAlign: 'center', outline: 'none', color: '#1e293b', background: '#f8fafc' }} />
                      <span style={{ fontSize: 12, fontWeight: 700, color: '#475569' }}>XP</span>
                    </div>
                    {/* Bonus XP */}
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '14px 16px' }}>
                      <span style={{ fontSize: 12, color: '#94a3b8', whiteSpace: 'nowrap' }}>Thưởng</span>
                      <input type="number" min={0} max={500} value={cfg.bonusXp}
                        onChange={e => { const val = Math.max(0, parseInt(e.target.value) || 0); setBonusConfigs(prev => prev.map((c, j) => j === i ? { ...c, bonusXp: val } : c)) }}
                        style={{ width: 68, padding: '6px 10px', border: '1.5px solid #fde68a', borderRadius: 8, fontSize: 15, fontWeight: 700, textAlign: 'center', outline: 'none', color: '#d97706', background: '#fffbeb' }} />
                      <span style={{ fontSize: 12, fontWeight: 700, color: '#f59e0b', display:'flex', alignItems:'center', gap:2 }}><Zap size={12}/>XP</span>
                    </div>
                    {/* Action */}
                    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 4, padding: '10px 8px', borderLeft: `1px solid #f1f5f9` }}>
                      {bonusConfigs.length > 1 && (
                        <button
                          onClick={() => {
                            if (cfg.usersCount > 0) {
                              if (!window.confirm(`Mục tiêu này đang có ${cfg.usersCount} user. Vẫn xoá?`)) return
                            }
                            setBonusConfigs(prev => prev.filter((_, j) => j !== i))
                          }}
                          style={{ width: 28, height: 28, borderRadius: 7, background: '#fee2e2', border: 'none', cursor: 'pointer', color: '#dc2626', display: 'flex', alignItems: 'center', justifyContent: 'center' }}
                          title={cfg.usersCount > 0 ? `Xoá (${cfg.usersCount} user đang dùng)` : 'Xoá mục tiêu này'}>
                          <X size={14}/>
                        </button>
                      )}
                      {cfg.usersCount > 0 && (
                        <span style={{ fontSize: 10, color: '#94a3b8', textAlign: 'center', lineHeight: 1.2 }}>{cfg.usersCount}<br/>users</span>
                      )}
                    </div>
                  </div>
                )
              })}
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 20 }}>
              {bonusConfigs.length < 5 && (
                <button
                  onClick={() => setBonusConfigs(prev => [...prev, { goalXp: (prev[prev.length - 1]?.goalXp ?? 0) + 10, bonusXp: 10, usersCount: 0 }])}
                  style={{ padding: '7px 16px', borderRadius: 8, border: '1.5px dashed #cbd5e1', background: 'none', cursor: 'pointer', fontSize: 13, color: '#64748b', fontWeight: 500, display: 'flex', alignItems: 'center', gap: 6 }}>
                  <span style={{ fontSize: 16, lineHeight: 1 }}>+</span> Thêm mục tiêu
                </button>
              )}
              <span style={{ fontSize: 12, color: '#94a3b8' }}>{bonusConfigs.length}/5 mục tiêu</span>
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <button onClick={saveBonusConfigs} disabled={bonusSaving} style={s.btnPrimary}>
                {bonusSaving ? 'Đang lưu...' : 'Lưu cấu hình'}
              </button>
              {bonusMsg && (
                <span style={{ fontSize: 13, color: bonusMsg.ok ? '#16a34a' : '#dc2626', fontWeight: 500 }}>
                  {bonusMsg.ok ? '✓' : '✗'} {bonusMsg.text}
                </span>
              )}
            </div>
          </>
        )}
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
  btnPrimary: { padding: '9px 20px', background: '#1a73e8', color: '#fff', border: 'none', borderRadius: 8, cursor: 'pointer', fontSize: 14, fontWeight: 600 },
  hint: { fontSize: 12, color: '#94a3b8', marginTop: 8, marginBottom: 0 },
  statusBox: { marginTop: 14, padding: '10px 14px', borderRadius: 8, border: '1px solid', fontSize: 14 },
  infoGrid: { display: 'flex', flexDirection: 'column' },
  link: { display: 'inline-block', color: '#1a73e8', fontSize: 14, fontWeight: 500, marginTop: 4 },
}
