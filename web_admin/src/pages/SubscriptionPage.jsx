import { useState, useEffect } from 'react'
import { Crown, Save, Trash2, RefreshCw, Package, Users } from 'lucide-react'
import { subscriptionAdminApi } from '../services/api'

const s = {
  page: { padding: '28px 32px', maxWidth: 960, margin: '0 auto' },
  heading: { fontSize: 22, fontWeight: 700, color: '#0f172a', marginBottom: 4 },
  sub: { fontSize: 13, color: '#64748b', marginBottom: 28 },
  section: { background: '#fff', borderRadius: 14, border: '1px solid #e2e8f0', padding: '22px 24px', marginBottom: 20 },
  sectionTitle: { fontSize: 15, fontWeight: 700, color: '#1e293b', marginBottom: 4, display: 'flex', alignItems: 'center', gap: 8 },
  sectionSub: { fontSize: 12, color: '#94a3b8', marginBottom: 16 },
  row: { display: 'flex', alignItems: 'center', gap: 12, marginBottom: 12 },
  label: { fontSize: 13, color: '#374151', fontWeight: 500, minWidth: 200 },
  input: { padding: '7px 12px', borderRadius: 8, border: '1px solid #e2e8f0', fontSize: 14, flex: 1, outline: 'none', maxWidth: 320 },
  btn: { padding: '7px 18px', borderRadius: 8, border: 'none', cursor: 'pointer', fontSize: 13, fontWeight: 600, display: 'flex', alignItems: 'center', gap: 6 },
  btnPrimary: { background: '#6366f1', color: '#fff' },
  btnDanger: { background: '#fee2e2', color: '#dc2626' },
  msg: { fontSize: 12, marginLeft: 8 },
  table: { width: '100%', borderCollapse: 'collapse', fontSize: 13 },
  th: { textAlign: 'left', padding: '8px 12px', color: '#94a3b8', fontWeight: 600, borderBottom: '1px solid #f1f5f9', fontSize: 12 },
  td: { padding: '10px 12px', borderBottom: '1px solid #f8fafc', color: '#374151', verticalAlign: 'middle' },
  badge: (color) => ({
    display: 'inline-block', padding: '2px 10px', borderRadius: 20,
    fontSize: 11, fontWeight: 700,
    background: color === 'gold' ? '#fef3c7' : color === 'purple' ? '#ede9fe' : '#f1f5f9',
    color: color === 'gold' ? '#92400e' : color === 'purple' ? '#6d28d9' : '#64748b',
  }),
  planCard: {
    border: '1px solid #e2e8f0', borderRadius: 12, padding: '16px 20px',
    display: 'flex', flexDirection: 'column', gap: 6, flex: 1,
  },
  planTitle: { fontSize: 15, fontWeight: 700, color: '#1e293b', display: 'flex', alignItems: 'center', gap: 6 },
  planDetail: { fontSize: 12, color: '#64748b' },
}

export default function SubscriptionPage() {
  const [config, setConfig] = useState({ packageName: '', standardProductId: '', maxProductId: '', standardAiLimit: 100 })
  const [subscribers, setSubscribers] = useState([])
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [msg, setMsg] = useState(null)
  const [revoking, setRevoking] = useState(null)

  useEffect(() => {
    Promise.all([
      subscriptionAdminApi.getPlans().then(d => setConfig(d)).catch(() => {}),
      subscriptionAdminApi.getAll().then(d => setSubscribers(Array.isArray(d) ? d : [])).catch(() => {}),
    ]).finally(() => setLoading(false))
  }, [])

  const saveConfig = async () => {
    setSaving(true); setMsg(null)
    try {
      await subscriptionAdminApi.updatePlans(config)
      setMsg({ ok: true, text: 'Đã lưu cấu hình!' })
    } catch (e) {
      setMsg({ ok: false, text: e.message })
    } finally {
      setSaving(false)
      setTimeout(() => setMsg(null), 3000)
    }
  }

  const revoke = async (userId) => {
    if (!window.confirm(`Huỷ subscription của user ${userId}?`)) return
    setRevoking(userId)
    try {
      await subscriptionAdminApi.revoke(userId)
      setSubscribers(prev => prev.map(s => s.userId === userId ? { ...s, isActive: false } : s))
    } catch (e) {
      alert(e.message)
    } finally {
      setRevoking(null)
    }
  }

  const activeCount = subscribers.filter(s => s.isActive).length

  return (
    <div style={s.page}>
      <h1 style={s.heading}>Quản lý gói VIP</h1>
      <p style={s.sub}>Cấu hình sản phẩm Google Play và theo dõi subscriber</p>

      {/* Plan overview cards */}
      <div style={{ display: 'flex', gap: 16, marginBottom: 20 }}>
        <div style={s.planCard}>
          <div style={s.planTitle}><span>⭐</span> Gói Standard</div>
          <div style={s.planDetail}>AI limit: <b>100 lượt / ngày</b></div>
          <div style={s.planDetail}>Product ID: <code style={{ fontSize: 11, background: '#f1f5f9', padding: '1px 6px', borderRadius: 4 }}>{config.standardProductId || '(chưa cấu hình)'}</code></div>
        </div>
        <div style={{ ...s.planCard, borderColor: '#a855f7' }}>
          <div style={{ ...s.planTitle, color: '#7c3aed' }}><span>👑</span> Gói Max</div>
          <div style={s.planDetail}>AI limit: <b>Không giới hạn</b></div>
          <div style={s.planDetail}>Product ID: <code style={{ fontSize: 11, background: '#f1f5f9', padding: '1px 6px', borderRadius: 4 }}>{config.maxProductId || '(chưa cấu hình)'}</code></div>
        </div>
        <div style={{ ...s.planCard, background: '#f8fafc' }}>
          <div style={s.planTitle}><Users size={14} /> Tổng subscriber</div>
          <div style={{ fontSize: 28, fontWeight: 800, color: '#6366f1' }}>{activeCount}</div>
          <div style={s.planDetail}>đang active / {subscribers.length} tổng</div>
        </div>
      </div>

      {/* Config section */}
      <div style={s.section}>
        <div style={s.sectionTitle}><Package size={16} /> Cấu hình Google Play</div>
        <div style={s.sectionSub}>Product ID phải trùng với ID đã tạo trên Google Play Console</div>

        <div style={s.row}>
          <span style={s.label}>Package Name</span>
          <input style={s.input} value={config.packageName}
            placeholder="com.example.app"
            onChange={e => setConfig(c => ({ ...c, packageName: e.target.value }))} />
        </div>
        <div style={s.row}>
          <span style={s.label}>Product ID — Gói Standard</span>
          <input style={s.input} value={config.standardProductId}
            placeholder="vip_standard"
            onChange={e => setConfig(c => ({ ...c, standardProductId: e.target.value }))} />
        </div>
        <div style={s.row}>
          <span style={s.label}>Product ID — Gói Max</span>
          <input style={s.input} value={config.maxProductId}
            placeholder="vip_max"
            onChange={e => setConfig(c => ({ ...c, maxProductId: e.target.value }))} />
        </div>

        <div style={{ display: 'flex', alignItems: 'center', marginTop: 8 }}>
          <button style={{ ...s.btn, ...s.btnPrimary }} onClick={saveConfig} disabled={saving}>
            <Save size={14} /> {saving ? 'Đang lưu...' : 'Lưu cấu hình'}
          </button>
          {msg && (
            <span style={{ ...s.msg, color: msg.ok ? '#16a34a' : '#dc2626' }}>{msg.text}</span>
          )}
        </div>
      </div>

      {/* Subscribers list */}
      <div style={s.section}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
          <div>
            <div style={s.sectionTitle}><Crown size={16} /> Danh sách subscriber</div>
            <div style={s.sectionSub}>Tất cả user đã mua gói VIP</div>
          </div>
          <button style={{ ...s.btn, background: '#f1f5f9', color: '#64748b' }}
            onClick={() => subscriptionAdminApi.getAll().then(d => setSubscribers(d ?? [])).catch(() => {})}>
            <RefreshCw size={13} /> Tải lại
          </button>
        </div>

        {loading ? (
          <div style={{ textAlign: 'center', padding: 32, color: '#94a3b8' }}>Đang tải...</div>
        ) : subscribers.length === 0 ? (
          <div style={{ textAlign: 'center', padding: 32, color: '#94a3b8' }}>Chưa có subscriber nào</div>
        ) : (
          <table style={s.table}>
            <thead>
              <tr>
                <th style={s.th}>User ID</th>
                <th style={s.th}>Gói</th>
                <th style={s.th}>Order ID</th>
                <th style={s.th}>Ngày mua</th>
                <th style={s.th}>Hết hạn</th>
                <th style={s.th}>Trạng thái</th>
                <th style={s.th}></th>
              </tr>
            </thead>
            <tbody>
              {subscribers.map(sub => (
                <tr key={sub.userId}>
                  <td style={s.td}>
                    <code style={{ fontSize: 11, background: '#f1f5f9', padding: '2px 6px', borderRadius: 4 }}>
                      {sub.userId.slice(0, 16)}...
                    </code>
                  </td>
                  <td style={s.td}>
                    {sub.planType === 'max'
                      ? <span style={s.badge('purple')}>👑 Max</span>
                      : <span style={s.badge('gold')}>⭐ Standard</span>}
                  </td>
                  <td style={s.td} title={sub.orderId}>
                    <span style={{ fontSize: 11, color: '#94a3b8' }}>
                      {sub.orderId ? sub.orderId.slice(0, 20) + '...' : '-'}
                    </span>
                  </td>
                  <td style={s.td}>{new Date(sub.purchasedAt).toLocaleDateString('vi-VN')}</td>
                  <td style={s.td}>
                    {sub.expiresAt
                      ? new Date(sub.expiresAt).toLocaleDateString('vi-VN')
                      : <span style={{ color: '#94a3b8' }}>Không hết hạn</span>}
                  </td>
                  <td style={s.td}>
                    {sub.isActive
                      ? <span style={s.badge('green', '#dcfce7', '#166534')}>Active</span>
                      : <span style={s.badge('')}>Đã huỷ</span>}
                  </td>
                  <td style={s.td}>
                    {sub.isActive && (
                      <button
                        style={{ ...s.btn, ...s.btnDanger, padding: '4px 12px' }}
                        disabled={revoking === sub.userId}
                        onClick={() => revoke(sub.userId)}>
                        <Trash2 size={12} />
                        {revoking === sub.userId ? '...' : 'Huỷ'}
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}
