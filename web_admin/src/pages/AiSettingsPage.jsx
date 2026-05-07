import { useState, useEffect } from 'react'
import { Bot, Save, Trash2, UserCog, BarChart3, RefreshCw } from 'lucide-react'
import { aiAdminApi, usersApi } from '../services/api'

const s = {
  page: { padding: '28px 32px', maxWidth: 900, margin: '0 auto' },
  heading: { fontSize: 22, fontWeight: 700, color: '#0f172a', marginBottom: 4 },
  sub: { fontSize: 13, color: '#64748b', marginBottom: 28 },
  section: { background: '#fff', borderRadius: 14, border: '1px solid #e2e8f0', padding: '22px 24px', marginBottom: 20 },
  sectionTitle: { fontSize: 15, fontWeight: 700, color: '#1e293b', marginBottom: 4, display: 'flex', alignItems: 'center', gap: 8 },
  sectionSub: { fontSize: 12, color: '#94a3b8', marginBottom: 16 },
  row: { display: 'flex', alignItems: 'center', gap: 12 },
  label: { fontSize: 13, color: '#374151', fontWeight: 500, minWidth: 180 },
  input: { padding: '7px 12px', borderRadius: 8, border: '1px solid #e2e8f0', fontSize: 14, width: 100, outline: 'none' },
  btn: { padding: '7px 18px', borderRadius: 8, border: 'none', cursor: 'pointer', fontSize: 13, fontWeight: 600, display: 'flex', alignItems: 'center', gap: 6 },
  btnPrimary: { background: '#6366f1', color: '#fff' },
  btnDanger: { background: '#fee2e2', color: '#dc2626' },
  btnGray: { background: '#f1f5f9', color: '#64748b' },
  msg: { fontSize: 12, marginLeft: 8 },
  table: { width: '100%', borderCollapse: 'collapse', fontSize: 13 },
  th: { textAlign: 'left', padding: '8px 12px', color: '#94a3b8', fontWeight: 600, borderBottom: '1px solid #f1f5f9', fontSize: 12 },
  td: { padding: '10px 12px', borderBottom: '1px solid #f8fafc', color: '#374151', verticalAlign: 'middle' },
  badge: { display: 'inline-block', padding: '2px 8px', borderRadius: 20, fontSize: 11, fontWeight: 600 },
  searchInput: { padding: '7px 12px', borderRadius: 8, border: '1px solid #e2e8f0', fontSize: 13, width: 260, outline: 'none' },
}

export default function AiSettingsPage() {
  // Default limit
  const [defaultLimit, setDefaultLimit] = useState(10)
  const [limitInput, setLimitInput] = useState('10')
  const [savingDefault, setSavingDefault] = useState(false)
  const [defaultMsg, setDefaultMsg] = useState(null)

  // Usage today
  const [usageList, setUsageList] = useState([])
  const [usageLoading, setUsageLoading] = useState(true)

  // Per-user override
  const [users, setUsers] = useState([])
  const [searchUid, setSearchUid] = useState('')
  const [overrides, setOverrides] = useState([]) // { userId, overrideLimit, defaultLimit }
  const [overrideLoading, setOverrideLoading] = useState(false)
  const [editingUid, setEditingUid] = useState(null)
  const [editValue, setEditValue] = useState('')
  const [overrideMsg, setOverrideMsg] = useState(null)

  useEffect(() => {
    aiAdminApi.getSettings()
      .then(d => { setDefaultLimit(d.defaultDailyLimit); setLimitInput(String(d.defaultDailyLimit)) })
      .catch(() => {})

    aiAdminApi.getTodayUsage()
      .then(d => setUsageList(d ?? []))
      .catch(() => {})
      .finally(() => setUsageLoading(false))

    usersApi.list(500)
      .then(d => setUsers(Array.isArray(d) ? d : []))
      .catch(() => {})
  }, [])

  const saveDefaultLimit = async () => {
    const val = parseInt(limitInput)
    if (isNaN(val) || val < 1) { setDefaultMsg({ ok: false, text: 'Giới hạn phải là số dương.' }); return }
    setSavingDefault(true); setDefaultMsg(null)
    try {
      await aiAdminApi.updateSettings(val)
      setDefaultLimit(val)
      setDefaultMsg({ ok: true, text: 'Đã lưu!' })
    } catch (e) {
      setDefaultMsg({ ok: false, text: e.message })
    } finally {
      setSavingDefault(false)
      setTimeout(() => setDefaultMsg(null), 3000)
    }
  }

  const searchUser = async () => {
    const uid = searchUid.trim()
    if (!uid) return
    setOverrideLoading(true); setOverrideMsg(null)
    try {
      const d = await aiAdminApi.getUserLimit(uid)
      setOverrides(prev => {
        const exists = prev.find(o => o.userId === uid)
        if (exists) return prev.map(o => o.userId === uid ? d : o)
        return [...prev, d]
      })
    } catch (e) {
      setOverrideMsg({ ok: false, text: `Không tìm thấy user: ${e.message}` })
    } finally {
      setOverrideLoading(false)
    }
  }

  const saveOverride = async (uid) => {
    const val = parseInt(editValue)
    if (isNaN(val) || val < 1) return
    try {
      const d = await aiAdminApi.setUserLimit(uid, val)
      setOverrides(prev => prev.map(o => o.userId === uid ? d : o))
      setEditingUid(null)
      setOverrideMsg({ ok: true, text: 'Đã lưu override!' })
      setTimeout(() => setOverrideMsg(null), 3000)
    } catch (e) {
      setOverrideMsg({ ok: false, text: e.message })
    }
  }

  const deleteOverride = async (uid) => {
    try {
      await aiAdminApi.deleteUserLimit(uid)
      setOverrides(prev => prev.filter(o => o.userId !== uid))
      setOverrideMsg({ ok: true, text: 'Đã xoá override.' })
      setTimeout(() => setOverrideMsg(null), 3000)
    } catch (e) {
      setOverrideMsg({ ok: false, text: e.message })
    }
  }

  const refreshUsage = async () => {
    setUsageLoading(true)
    try {
      const d = await aiAdminApi.getTodayUsage()
      setUsageList(d ?? [])
    } finally {
      setUsageLoading(false)
    }
  }

  const getUserDisplay = (uid) => {
    const u = users.find(x => x.uid === uid)
    return u ? (u.displayName || u.email || uid) : uid
  }

  return (
    <div style={s.page}>
      <h2 style={s.heading}>Cài đặt AI</h2>
      <p style={s.sub}>Quản lý giới hạn lượt sử dụng AI cho người dùng mỗi ngày.</p>

      {/* Giới hạn mặc định */}
      <div style={s.section}>
        <div style={s.sectionTitle}><Bot size={16} color="#6366f1" /> Giới hạn mặc định</div>
        <div style={s.sectionSub}>Áp dụng cho tất cả người dùng không có override riêng. Reset lúc 00:00 giờ Việt Nam.</div>
        <div style={s.row}>
          <span style={s.label}>Lượt AI tối đa / ngày</span>
          <input
            type="number" min={1} style={s.input}
            value={limitInput}
            onChange={e => setLimitInput(e.target.value)}
          />
          <button
            style={{ ...s.btn, ...s.btnPrimary }}
            onClick={saveDefaultLimit}
            disabled={savingDefault}
          >
            <Save size={14} />
            {savingDefault ? 'Đang lưu...' : 'Lưu'}
          </button>
          {defaultMsg && (
            <span style={{ ...s.msg, color: defaultMsg.ok ? '#16a34a' : '#dc2626' }}>
              {defaultMsg.text}
            </span>
          )}
        </div>
      </div>

      {/* Override từng user */}
      <div style={s.section}>
        <div style={s.sectionTitle}><UserCog size={16} color="#6366f1" /> Override từng người dùng</div>
        <div style={s.sectionSub}>Set giới hạn riêng cho một user cụ thể. Giá trị này ưu tiên hơn giới hạn mặc định.</div>

        <div style={{ ...s.row, marginBottom: 16 }}>
          <input
            style={s.searchInput}
            placeholder="Nhập Firebase UID của user..."
            value={searchUid}
            onChange={e => setSearchUid(e.target.value)}
            onKeyDown={e => e.key === 'Enter' && searchUser()}
          />
          <button style={{ ...s.btn, ...s.btnGray }} onClick={searchUser} disabled={overrideLoading}>
            {overrideLoading ? 'Đang tìm...' : 'Xem / Thêm'}
          </button>
          {overrideMsg && (
            <span style={{ ...s.msg, color: overrideMsg.ok ? '#16a34a' : '#dc2626' }}>
              {overrideMsg.text}
            </span>
          )}
        </div>

        {overrides.length > 0 && (
          <table style={s.table}>
            <thead>
              <tr>
                <th style={s.th}>User</th>
                <th style={s.th}>Override</th>
                <th style={s.th}>Default</th>
                <th style={s.th}>Hành động</th>
              </tr>
            </thead>
            <tbody>
              {overrides.map(o => (
                <tr key={o.userId}>
                  <td style={s.td}>
                    <div style={{ fontWeight: 600 }}>{getUserDisplay(o.userId)}</div>
                    <div style={{ fontSize: 11, color: '#94a3b8' }}>{o.userId}</div>
                  </td>
                  <td style={s.td}>
                    {editingUid === o.userId ? (
                      <input
                        type="number" min={1} style={{ ...s.input, width: 80 }}
                        value={editValue}
                        onChange={e => setEditValue(e.target.value)}
                        autoFocus
                      />
                    ) : (
                      o.overrideLimit != null
                        ? <span style={{ ...s.badge, background: '#ede9fe', color: '#7c3aed' }}>{o.overrideLimit} lượt</span>
                        : <span style={{ ...s.badge, background: '#f1f5f9', color: '#94a3b8' }}>Chưa set</span>
                    )}
                  </td>
                  <td style={s.td}>
                    <span style={{ ...s.badge, background: '#f0fdf4', color: '#16a34a' }}>{o.defaultLimit} lượt</span>
                  </td>
                  <td style={s.td}>
                    <div style={s.row}>
                      {editingUid === o.userId ? (
                        <>
                          <button style={{ ...s.btn, ...s.btnPrimary, padding: '5px 12px' }} onClick={() => saveOverride(o.userId)}>
                            <Save size={13} /> Lưu
                          </button>
                          <button style={{ ...s.btn, ...s.btnGray, padding: '5px 12px' }} onClick={() => setEditingUid(null)}>
                            Huỷ
                          </button>
                        </>
                      ) : (
                        <>
                          <button
                            style={{ ...s.btn, ...s.btnGray, padding: '5px 12px' }}
                            onClick={() => { setEditingUid(o.userId); setEditValue(String(o.overrideLimit ?? defaultLimit)) }}
                          >
                            <UserCog size={13} /> Sửa
                          </button>
                          {o.overrideLimit != null && (
                            <button style={{ ...s.btn, ...s.btnDanger, padding: '5px 12px' }} onClick={() => deleteOverride(o.userId)}>
                              <Trash2 size={13} /> Xoá
                            </button>
                          )}
                        </>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* Usage hôm nay */}
      <div style={s.section}>
        <div style={{ ...s.sectionTitle, justifyContent: 'space-between' }}>
          <span style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <BarChart3 size={16} color="#6366f1" /> Lượt dùng AI hôm nay
          </span>
          <button style={{ ...s.btn, ...s.btnGray, padding: '5px 12px' }} onClick={refreshUsage} disabled={usageLoading}>
            <RefreshCw size={13} /> Làm mới
          </button>
        </div>
        <div style={s.sectionSub}>Danh sách user đã sử dụng AI trong ngày hôm nay (giờ Việt Nam).</div>

        {usageLoading ? (
          <div style={{ color: '#94a3b8', fontSize: 13 }}>Đang tải...</div>
        ) : usageList.length === 0 ? (
          <div style={{ color: '#94a3b8', fontSize: 13 }}>Chưa có ai dùng AI hôm nay.</div>
        ) : (
          <table style={s.table}>
            <thead>
              <tr>
                <th style={s.th}>User</th>
                <th style={s.th}>Đã dùng</th>
                <th style={s.th}>Giới hạn</th>
                <th style={s.th}>Trạng thái</th>
              </tr>
            </thead>
            <tbody>
              {usageList.map(u => {
                const pct = Math.round((u.used / u.limit) * 100)
                const full = u.used >= u.limit
                return (
                  <tr key={u.userId}>
                    <td style={s.td}>
                      <div style={{ fontWeight: 600 }}>{getUserDisplay(u.userId)}</div>
                      <div style={{ fontSize: 11, color: '#94a3b8' }}>{u.userId}</div>
                    </td>
                    <td style={s.td}>{u.used}</td>
                    <td style={s.td}>{u.limit}</td>
                    <td style={s.td}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <div style={{ width: 80, height: 6, borderRadius: 4, background: '#f1f5f9', overflow: 'hidden' }}>
                          <div style={{ width: `${Math.min(pct, 100)}%`, height: '100%', borderRadius: 4, background: full ? '#ef4444' : pct > 70 ? '#f59e0b' : '#22c55e' }} />
                        </div>
                        <span style={{ fontSize: 12, color: full ? '#ef4444' : '#64748b' }}>
                          {full ? 'Hết lượt' : `${pct}%`}
                        </span>
                      </div>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}
