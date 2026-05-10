import { useState, useEffect } from 'react'
import { Crown, Save, Trash2, RefreshCw, Users } from 'lucide-react'
import { subscriptionAdminApi } from '../services/api'

const inp = {
  padding: '6px 10px', borderRadius: 7, border: '1px solid #cbd5e1',
  fontSize: 13, width: '100%', outline: 'none', background: '#f8fafc',
  color: '#1e293b', boxSizing: 'border-box',
}
const inpFocus = { ...inp, border: '1px solid #6366f1', background: '#fff' }

const s = {
  page: { padding: '28px 32px', maxWidth: 980, margin: '0 auto' },
  heading: { fontSize: 22, fontWeight: 700, color: '#0f172a', marginBottom: 4 },
  sub: { fontSize: 13, color: '#64748b', marginBottom: 24 },
  section: { background: '#fff', borderRadius: 14, border: '1px solid #e2e8f0', padding: '22px 24px', marginBottom: 20 },
  sectionTitle: { fontSize: 15, fontWeight: 700, color: '#1e293b', marginBottom: 16, display: 'flex', alignItems: 'center', gap: 8 },
  sectionSub: { fontSize: 12, color: '#94a3b8', marginBottom: 16 },
  btn: { padding: '7px 18px', borderRadius: 8, border: 'none', cursor: 'pointer', fontSize: 13, fontWeight: 600, display: 'flex', alignItems: 'center', gap: 6 },
  btnPrimary: { background: '#6366f1', color: '#fff' },
  btnDanger: { background: '#fee2e2', color: '#dc2626' },
  table: { width: '100%', borderCollapse: 'collapse', fontSize: 13 },
  th: { textAlign: 'left', padding: '8px 12px', color: '#94a3b8', fontWeight: 600, borderBottom: '1px solid #f1f5f9', fontSize: 12 },
  td: { padding: '10px 12px', borderBottom: '1px solid #f8fafc', color: '#374151', verticalAlign: 'middle' },
  badge: (color) => ({
    display: 'inline-block', padding: '2px 10px', borderRadius: 20,
    fontSize: 11, fontWeight: 700,
    background: color === 'gold' ? '#fef3c7' : color === 'purple' ? '#ede9fe' : '#f1f5f9',
    color: color === 'gold' ? '#92400e' : color === 'purple' ? '#6d28d9' : '#64748b',
  }),
}

function FocusInput({ value, onChange, placeholder, style }) {
  const [focused, setFocused] = useState(false)
  return (
    <input
      style={focused ? { ...inpFocus, ...style } : { ...inp, ...style }}
      value={value}
      placeholder={placeholder}
      onChange={onChange}
      onFocus={() => setFocused(true)}
      onBlur={() => setFocused(false)}
    />
  )
}

const parsePrice = (str) => parseInt((str || '').replace(/[^\d]/g, '')) || 0
const formatVND = (num) => num > 0
  ? new Intl.NumberFormat('vi-VN').format(num) + 'đ / tháng'
  : ''

function PriceInput({ value, onChange }) {
  const [focused, setFocused] = useState(false)
  const numVal = parsePrice(value)
  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <input
          type="number"
          min={0}
          style={focused ? { ...inpFocus, maxWidth: 160 } : { ...inp, maxWidth: 160 }}
          value={numVal || ''}
          placeholder="29000"
          onChange={e => onChange(formatVND(parseInt(e.target.value) || 0))}
          onFocus={() => setFocused(true)}
          onBlur={() => setFocused(false)}
        />
        {numVal > 0 && (
          <span style={{ fontSize: 13, color: '#6366f1', fontWeight: 600 }}>
            {formatVND(numVal)}
          </span>
        )}
      </div>
      <div style={{ fontSize: 10, color: '#94a3b8', marginTop: 3 }}>Hiển thị trong app khi Play Store chưa load giá</div>
    </div>
  )
}

function PlanCard({ icon, title, accentColor, borderColor, aiLimit, fields, onChange }) {
  return (
    <div style={{
      flex: 1, border: `2px solid ${borderColor}`, borderRadius: 14,
      padding: '20px 22px', display: 'flex', flexDirection: 'column', gap: 14,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <span style={{ fontSize: 22 }}>{icon}</span>
        <div>
          <div style={{ fontSize: 16, fontWeight: 700, color: accentColor }}>{title}</div>
          <div style={{ fontSize: 11, color: '#94a3b8' }}>AI limit: {aiLimit}</div>
        </div>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        <div>
          <div style={{ fontSize: 11, fontWeight: 600, color: '#64748b', marginBottom: 4, textTransform: 'uppercase', letterSpacing: 0.4 }}>Product ID</div>
          <FocusInput
            value={fields.productId}
            placeholder="vip_standard"
            onChange={e => onChange('productId', e.target.value)}
          />
        </div>
        <div>
          <div style={{ fontSize: 11, fontWeight: 600, color: '#64748b', marginBottom: 4, textTransform: 'uppercase', letterSpacing: 0.4 }}>Giá hiển thị</div>
          <PriceInput
            value={fields.price}
            onChange={val => onChange('price', val)}
          />
        </div>
      </div>
    </div>
  )
}

export default function SubscriptionPage() {
  const [config, setConfig] = useState({
    packageName: '',
    standardProductId: '', maxProductId: '',
    standardPrice: '', maxPrice: '',
    trialDays: 7,
    standardAiLimit: 100,
  })
  const [subscribers, setSubscribers] = useState([])
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [msg, setMsg] = useState(null)
  const [revoking, setRevoking] = useState(null)
  const [pkgFocused, setPkgFocused] = useState(false)

  useEffect(() => {
    Promise.all([
      subscriptionAdminApi.getPlans().then(d => setConfig(prev => ({ ...prev, ...d }))).catch(() => {}),
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

      {/* Stats bar */}
      <div style={{ display: 'flex', gap: 12, marginBottom: 20 }}>
        <div style={{ background: '#f0fdf4', border: '1px solid #bbf7d0', borderRadius: 10, padding: '12px 20px', display: 'flex', alignItems: 'center', gap: 10 }}>
          <Users size={16} color="#16a34a" />
          <div>
            <div style={{ fontSize: 20, fontWeight: 800, color: '#16a34a', lineHeight: 1 }}>{activeCount}</div>
            <div style={{ fontSize: 11, color: '#166534' }}>subscriber active</div>
          </div>
        </div>
        <div style={{ background: '#faf5ff', border: '1px solid #e9d5ff', borderRadius: 10, padding: '12px 20px', display: 'flex', alignItems: 'center', gap: 10 }}>
          <Crown size={16} color="#7c3aed" />
          <div>
            <div style={{ fontSize: 20, fontWeight: 800, color: '#7c3aed', lineHeight: 1 }}>{subscribers.length}</div>
            <div style={{ fontSize: 11, color: '#6d28d9' }}>tổng đã mua</div>
          </div>
        </div>
      </div>

      {/* Plan config cards */}
      <div style={s.section}>
        <div style={s.sectionTitle}>
          <Crown size={16} color="#6366f1" /> Cấu hình gói VIP
        </div>

        {/* Package name */}
        <div style={{ marginBottom: 18 }}>
          <div style={{ fontSize: 11, fontWeight: 600, color: '#64748b', marginBottom: 4, textTransform: 'uppercase', letterSpacing: 0.4 }}>Package Name</div>
          <input
            style={pkgFocused ? { ...inpFocus, maxWidth: 400 } : { ...inp, maxWidth: 400 }}
            value={config.packageName}
            placeholder="doanhdd.javaup.mobile"
            onChange={e => setConfig(c => ({ ...c, packageName: e.target.value }))}
            onFocus={() => setPkgFocused(true)}
            onBlur={() => setPkgFocused(false)}
          />
          <div style={{ fontSize: 10, color: '#94a3b8', marginTop: 3 }}>Phải trùng với package name trong Google Play Console</div>
        </div>

        {/* Trial days */}
        <div style={{ marginBottom: 18 }}>
          <div style={{ fontSize: 11, fontWeight: 600, color: '#64748b', marginBottom: 4, textTransform: 'uppercase', letterSpacing: 0.4 }}>Số ngày dùng thử miễn phí</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <input
              type="number"
              min={0}
              style={{ ...inp, maxWidth: 100 }}
              value={config.trialDays}
              onChange={e => setConfig(c => ({ ...c, trialDays: parseInt(e.target.value) || 0 }))}
            />
            <span style={{ fontSize: 13, color: '#64748b' }}>ngày</span>
            {config.trialDays > 0 && (
              <span style={{ fontSize: 12, background: '#dcfce7', color: '#15803d', padding: '2px 10px', borderRadius: 20, fontWeight: 600 }}>
                Đang bật — thử miễn phí {config.trialDays} ngày
              </span>
            )}
            {config.trialDays === 0 && (
              <span style={{ fontSize: 12, background: '#f1f5f9', color: '#64748b', padding: '2px 10px', borderRadius: 20 }}>
                Tắt
              </span>
            )}
          </div>
          <div style={{ fontSize: 10, color: '#94a3b8', marginTop: 3 }}>
            Cấu hình period thực tế trong Google Play Console → Subscription → Free trial. Số ngày ở đây chỉ để hiển thị trong app.
          </div>
        </div>

        {/* Plan cards */}
        <div style={{ display: 'flex', gap: 16, marginBottom: 18 }}>
          <PlanCard
            icon="⭐"
            title="Gói Standard"
            accentColor="#b45309"
            borderColor="#fde68a"
            aiLimit="100 lượt / ngày"
            fields={{ productId: config.standardProductId, price: config.standardPrice }}
            onChange={(field, val) => setConfig(c => ({
              ...c,
              [field === 'productId' ? 'standardProductId' : 'standardPrice']: val
            }))}
          />
          <PlanCard
            icon="👑"
            title="Gói Max"
            accentColor="#7c3aed"
            borderColor="#c4b5fd"
            aiLimit="Không giới hạn"
            fields={{ productId: config.maxProductId, price: config.maxPrice }}
            onChange={(field, val) => setConfig(c => ({
              ...c,
              [field === 'productId' ? 'maxProductId' : 'maxPrice']: val
            }))}
          />
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <button style={{ ...s.btn, ...s.btnPrimary }} onClick={saveConfig} disabled={saving}>
            <Save size={14} /> {saving ? 'Đang lưu...' : 'Lưu cấu hình'}
          </button>
          {msg && (
            <span style={{ fontSize: 12, color: msg.ok ? '#16a34a' : '#dc2626' }}>{msg.text}</span>
          )}
        </div>
      </div>

      {/* Subscribers list */}
      <div style={s.section}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
          <div style={s.sectionTitle}><Users size={16} /> Danh sách subscriber</div>
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
                      ? <span style={s.badge('green')}>Active</span>
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
