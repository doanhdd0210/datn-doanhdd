import { useState, useEffect, useCallback } from 'react'
import { RefreshCw, Trash2, BookOpen, X, Lock, Check, BarChart2 } from 'lucide-react'
import { usersApi, statsApi } from '../services/api'

async function runCleanup() {
  if (!window.confirm('Xoá toàn bộ dữ liệu DB của các tài khoản đã bị xoá khỏi Firebase?\nHành động này không thể hoàn tác.')) return
  try {
    const res = await usersApi.cleanupOrphanProfiles()
    alert(`✅ Đã dọn dẹp ${res?.deleted ?? 0} profile thừa`)
  } catch (e) {
    alert('Lỗi: ' + e.message)
  }
}

async function runDeleteAll(reload) {
  const confirmed = window.confirm(
    '⚠️ XOÁ TOÀN BỘ NGƯỜI DÙNG (trừ admin)?\n\nHành động này sẽ xoá:\n- Tất cả tài khoản Firebase Auth\n- Toàn bộ dữ liệu DB liên quan\n\nKHÔNG THỂ HOÀN TÁC!'
  )
  if (!confirmed) return
  const confirmed2 = window.confirm('Xác nhận lần 2: Bạn chắc chắn muốn xoá tất cả?')
  if (!confirmed2) return
  try {
    const res = await usersApi.deleteAllUsers()
    alert(`✅ Đã xoá ${res?.deletedUsers ?? 0} user và ${res?.deletedOrphans ?? 0} profile thừa`)
    reload()
  } catch (e) {
    alert('Lỗi: ' + e.message)
  }
}

const PROVIDER_LABEL = { 'google.com': 'Google', password: 'Email', phone: 'Phone' }

const TESTER_EMAILS = new Set([
  'vund.0709@gmail.com', 'vu_nd@amira.vn', 'vund.draft@gmail.com',
  'saokhuee88@gmail.com', 'nam.nt0910@gmail.com', 'hungto2288@gmail.com',
  'ductuan9603@gmail.com', 'bolaosieudang26598@gmail.com', 'doanhkull511a@gmail.com',
  'epartner64@gmail.com', 'psv.epartners@gmail.com', 'koydepzaiicloud@gmail.com',
])

function formatRelativeTime(dateStr) {
  const date = new Date(dateStr)
  const diff = Math.floor((Date.now() - date.getTime()) / 1000)
  if (diff < 60) return 'Vừa xong'
  if (diff < 3600) return `${Math.floor(diff / 60)} phút trước`
  if (diff < 86400) return `${Math.floor(diff / 3600)} giờ trước`
  if (diff < 86400 * 7) return `${Math.floor(diff / 86400)} ngày trước`
  return date.toLocaleDateString('vi-VN')
}

export default function UsersPage() {
  const [users, setUsers] = useState([])
  const [leaderboard, setLeaderboard] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')
  const [modal, setModal] = useState(null) // null | { mode: 'create'|'edit'|'delete'|'stats', user? }
  const [saving, setSaving] = useState(false)
  const [form, setForm] = useState({})
  const [sortByActivity, setSortByActivity] = useState(false) // false = default, true = sort desc by lastActiveAt

  const loadUsers = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const [userData, lbData] = await Promise.all([
        usersApi.list(),
        statsApi.leaderboard(500).catch(() => []),
      ])
      setUsers(userData ?? [])
      setLeaderboard(lbData ?? [])
    } catch (e) {
      setError(e.message)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { loadUsers() }, [loadUsers])

  const filtered = users
    .filter((u) => {
      if (u.isAdmin) return false
      const q = search.toLowerCase()
      return (
        u.email?.toLowerCase().includes(q) ||
        u.displayName?.toLowerCase().includes(q) ||
        u.uid?.toLowerCase().includes(q)
      )
    })
    .sort((a, b) => {
      if (!sortByActivity) return 0
      const ta = a.lastActiveAt ? new Date(a.lastActiveAt).getTime() : 0
      const tb = b.lastActiveAt ? new Date(b.lastActiveAt).getTime() : 0
      return tb - ta
    })

  const getUserStats = (uid) => leaderboard.find(l => l.uid === uid || l.userId === uid)

  const openCreate = () => {
    setForm({ email: '', password: '', displayName: '', phoneNumber: '', isAdmin: false })
    setModal({ mode: 'create' })
  }

  const openEdit = (user) => {
    setForm({
      email: user.email ?? '',
      displayName: user.displayName ?? '',
      phoneNumber: user.phoneNumber ?? '',
      isAdmin: user.isAdmin,
    })
    setModal({ mode: 'edit', user })
  }

  const openDelete = (user) => setModal({ mode: 'delete', user })
  const openStats = (user) => setModal({ mode: 'stats', user })

  const closeModal = () => { setModal(null); setForm({}) }

  const handleSave = async () => {
    setSaving(true)
    try {
      if (modal.mode === 'create') {
        await usersApi.create(form)
      } else {
        const payload = {}
        if (form.displayName !== undefined) payload.displayName = form.displayName
        if (form.email) payload.email = form.email
        if (form.phoneNumber !== undefined) payload.phoneNumber = form.phoneNumber
        if (form.password) payload.password = form.password
        if (form.isAdmin !== undefined) payload.isAdmin = form.isAdmin
        await usersApi.update(modal.user.uid, payload)
      }
      await loadUsers()
      closeModal()
    } catch (e) {
      alert('Lỗi: ' + e.message)
    } finally {
      setSaving(false)
    }
  }

  const handleDelete = async () => {
    setSaving(true)
    try {
      await usersApi.delete(modal.user.uid)
      await loadUsers()
      closeModal()
    } catch (e) {
      alert('Lỗi: ' + e.message)
    } finally {
      setSaving(false)
    }
  }

  const toggleDisabled = async (user) => {
    try {
      await usersApi.setDisabled(user.uid, !user.disabled)
      await loadUsers()
    } catch (e) {
      alert('Lỗi: ' + e.message)
    }
  }

  const toggleAdmin = async (user) => {
    if (!window.confirm(`${user.isAdmin ? 'Thu hồi' : 'Cấp'} quyền admin cho ${user.email}?`)) return
    try {
      await usersApi.setAdmin(user.uid, !user.isAdmin)
      await loadUsers()
    } catch (e) {
      alert('Lỗi: ' + e.message)
    }
  }

  return (
    <div>
      {/* Toolbar */}
      <div style={s.toolbar}>
        <input
          placeholder="Tìm theo email, tên, UID..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          style={s.searchInput}
        />
        <button onClick={loadUsers} style={s.btnSecondary} title="Làm mới"><RefreshCw size={14} style={{marginRight:5,verticalAlign:"middle"}}/> Làm mới</button>
        <button onClick={runCleanup} style={{ ...s.btnSecondary, color: '#b45309' }} title="Xoá dữ liệu DB của tài khoản đã bị xoá">🧹 Dọn dữ liệu thừa</button>
        <button onClick={() => runDeleteAll(loadUsers)} style={{ ...s.btnSecondary, color: '#dc2626', borderColor: '#fca5a5' }} title="Xoá toàn bộ người dùng (trừ admin)"><Trash2 size={14} style={{marginRight:5,verticalAlign:'middle'}}/> Xoá tất cả user</button>
      </div>

      {error && <div style={s.errorBox}>{error}</div>}

      {/* Stats */}
      <div style={s.statsRow}>
        <span style={s.stat}>Tổng: <strong>{users.filter((u) => !u.isAdmin).length}</strong></span>
        <span style={s.stat}>Đang hiển thị: <strong>{filtered.length}</strong></span>
        <span style={s.stat}>Bị khoá: <strong>{users.filter((u) => !u.isAdmin && u.disabled).length}</strong></span>
        <span style={{ ...s.stat, color: '#15803d', background: '#dcfce7', padding: '2px 12px', borderRadius: 99, fontWeight: 500 }}>
          🟢 Truy cập hôm nay: <strong>{users.filter((u) => {
            if (u.isAdmin || !u.lastActiveAt) return false
            const d = new Date(u.lastActiveAt), now = new Date()
            return d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth() && d.getDate() === now.getDate()
          }).length}</strong>
        </span>
        <span style={{ ...s.stat, color: '#7c3aed', background: '#ede9fe', padding: '2px 12px', borderRadius: 99, fontWeight: 500 }}>
          🧪 Tester hôm nay: <strong>{users.filter((u) => {
            if (!u.lastActiveAt || !TESTER_EMAILS.has(u.email?.toLowerCase())) return false
            const d = new Date(u.lastActiveAt), now = new Date()
            return d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth() && d.getDate() === now.getDate()
          }).length} / {TESTER_EMAILS.size}</strong>
        </span>
      </div>

      {/* Table */}
      {loading ? (
        <div style={s.loading}>Đang tải...</div>
      ) : (
        <div style={s.tableWrap}>
          <table style={s.table}>
            <thead>
              <tr style={s.thead}>
                <th style={{ ...s.th, width: 48, textAlign: 'center' }}>STT</th>
                <th style={s.th}>Người dùng</th>
                <th style={s.th}>UID</th>
                <th style={s.th}>Provider</th>
                <th style={s.th}>Trạng thái</th>
                <th style={s.th}>Admin</th>
                <th style={s.th}>Ngày tạo</th>
                <th
                  style={{ ...s.th, cursor: 'pointer', userSelect: 'none' }}
                  onClick={() => setSortByActivity(v => !v)}
                  title="Click để sắp xếp theo hoạt động gần nhất"
                >
                  Hoạt động gần nhất {sortByActivity ? '↓' : '↕'}
                </th>
                <th style={s.th}>Thao tác</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((u, idx) => (
                <tr key={u.uid} style={s.tr}>
                  <td style={{ ...s.td, textAlign: 'center', color: '#94a3b8', fontSize: 13 }}>{idx + 1}</td>
                  <td style={s.td}>
                    <div style={s.userCell}>
                      <div style={s.avatar}>
                        {u.photoUrl
                          ? <img src={u.photoUrl} alt="" style={s.avatarImg} />
                          : <span>{(u.displayName || u.email || '?')[0].toUpperCase()}</span>}
                      </div>
                      <div>
                        <div style={s.name}>{u.displayName || '—'}</div>
                        <div style={s.email}>{u.email}</div>
                      </div>
                    </div>
                  </td>
                  <td style={{ ...s.td, fontFamily: 'monospace', fontSize: 11, color: '#64748b' }}>
                    {u.uid.slice(0, 12)}…
                  </td>
                  <td style={s.td}>
                    <span style={s.badge}>{PROVIDER_LABEL[u.provider] ?? u.provider ?? '—'}</span>
                  </td>
                  <td style={s.td}>
                    <button
                      onClick={() => toggleDisabled(u)}
                      style={{ ...s.statusBtn, background: u.disabled ? '#fef3c7' : '#dcfce7', color: u.disabled ? '#b45309' : '#15803d' }}
                    >
                      {u.disabled ? <><Lock size={12} style={{marginRight:4,verticalAlign:'middle'}}/>Khoá</> : <><Check size={12} style={{marginRight:4,verticalAlign:'middle'}}/>Hoạt động</>}
                    </button>
                  </td>
                  <td style={s.td}>
                    <button
                      onClick={() => toggleAdmin(u)}
                      style={{ ...s.statusBtn, background: u.isAdmin ? '#ede9fe' : '#f1f5f9', color: u.isAdmin ? '#6d28d9' : '#64748b' }}
                    >
                      {u.isAdmin ? '★ Admin' : '— User'}
                    </button>
                  </td>
                  <td style={s.td}>
                    <div style={{ fontSize: 12, color: '#64748b' }}>
                      {new Date(u.createdAt).toLocaleDateString('vi-VN')}
                    </div>
                    {u.lastSignInAt && (
                      <div style={{ fontSize: 11, color: '#94a3b8' }}>
                        Login: {new Date(u.lastSignInAt).toLocaleDateString('vi-VN')}
                      </div>
                    )}
                  </td>
                  <td style={s.td}>
                    {u.lastActiveAt ? (
                      <div style={{ fontSize: 12, color: '#16a34a', fontWeight: 500 }}>
                        {formatRelativeTime(u.lastActiveAt)}
                      </div>
                    ) : (
                      <div style={{ fontSize: 12, color: '#cbd5e1' }}>—</div>
                    )}
                  </td>
                  <td style={s.td}>
                    <div style={s.actions}>
                      <button onClick={() => openStats(u)} style={s.btnStats} title="Xem thống kê"><BarChart2 size={14}/></button>
                      <button onClick={() => openDelete(u)} style={s.btnDelete} title="Xoá"><Trash2 size={14}/></button>
                    </div>
                  </td>
                </tr>
              ))}
              {filtered.length === 0 && (
                <tr><td colSpan={9} style={{ textAlign: 'center', padding: 40, color: '#94a3b8' }}>Không có kết quả</td></tr>
              )}
            </tbody>
          </table>
        </div>
      )}

      {/* Modal Stats */}
      {modal?.mode === 'stats' && (() => {
        const st = getUserStats(modal.user.uid)
        const xp = st?.xp ?? st?.totalXp ?? 0
        const streak = st?.streak ?? st?.currentStreak ?? 0
        const lessons = st?.lessonsCompleted ?? st?.completedLessons ?? 0
        const rank = st?.rank ?? '—'
        return (
          <div style={s.overlay}>
            <div style={s.modal}>
              <div style={s.modalHeader}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <div style={{ ...s.avatar, width: 40, height: 40, fontSize: 18 }}>
                    {modal.user.photoUrl
                      ? <img src={modal.user.photoUrl} alt="" style={{ width: 40, height: 40, objectFit: 'cover' }} />
                      : <span>{(modal.user.displayName || modal.user.email || '?')[0].toUpperCase()}</span>}
                  </div>
                  <div>
                    <div style={{ fontWeight: 700, fontSize: 15, color: '#1e293b' }}>{modal.user.displayName || '—'}</div>
                    <div style={{ fontSize: 12, color: '#64748b' }}>{modal.user.email}</div>
                  </div>
                </div>
                <button onClick={closeModal} style={s.modalClose}><X size={16}/></button>
              </div>
              <div style={s.modalBody}>
                {!st ? (
                  <div style={{ textAlign: 'center', padding: '24px 0', color: '#94a3b8' }}>
                    Người dùng chưa có dữ liệu học tập
                  </div>
                ) : (
                  <div style={s.statsGrid}>
                    <div style={s.statCard}><div style={s.statIcon}>⭐</div><div style={s.statValue}>{xp.toLocaleString()}</div><div style={s.statLabel}>Tổng XP</div></div>
                    <div style={s.statCard}><div style={s.statIcon}>🔥</div><div style={s.statValue}>{streak}</div><div style={s.statLabel}>Streak (ngày)</div></div>
                    <div style={s.statCard}><div style={s.statIcon}><BookOpen size={24} color="#9333ea"/></div><div style={s.statValue}>{lessons}</div><div style={s.statLabel}>Bài học hoàn thành</div></div>
                    <div style={s.statCard}><div style={s.statIcon}>🏆</div><div style={s.statValue}>{rank === '—' ? '—' : `#${rank}`}</div><div style={s.statLabel}>Thứ hạng</div></div>
                  </div>
                )}
              </div>
              <div style={s.modalFooter}>
                <button onClick={closeModal} style={s.cancelBtn}>Đóng</button>
              </div>
            </div>
          </div>
        )
      })()}

      {/* Modal Create / Edit */}
      {modal && modal.mode !== 'delete' && modal.mode !== 'stats' && (
        <div style={s.overlay}>
          <div style={s.modal}>
            <div style={s.modalHeader}>
              <h3 style={s.modalTitle}>
                {modal.mode === 'create' ? 'Thêm người dùng mới' : `Sửa: ${modal.user?.email}`}
              </h3>
              <button onClick={closeModal} style={s.modalClose}><X size={16}/></button>
            </div>
            <div style={s.modalBody}>
              <label style={s.label}>Email</label>
              <input style={s.input} value={form.email ?? ''} onChange={(e) => setForm({ ...form, email: e.target.value })} />

              {modal.mode === 'create' && (
                <>
                  <label style={s.label}>Mật khẩu (tối thiểu 6 ký tự)</label>
                  <input style={s.input} type="password" value={form.password ?? ''} onChange={(e) => setForm({ ...form, password: e.target.value })} />
                </>
              )}

              {modal.mode === 'edit' && (
                <>
                  <label style={s.label}>Đổi mật khẩu (để trống = không đổi)</label>
                  <input style={s.input} type="password" placeholder="Mật khẩu mới..." value={form.password ?? ''} onChange={(e) => setForm({ ...form, password: e.target.value })} />
                </>
              )}

              <label style={s.label}>Tên hiển thị</label>
              <input style={s.input} value={form.displayName ?? ''} onChange={(e) => setForm({ ...form, displayName: e.target.value })} />

              <label style={s.label}>Số điện thoại</label>
              <input style={s.input} placeholder="+84..." value={form.phoneNumber ?? ''} onChange={(e) => setForm({ ...form, phoneNumber: e.target.value })} />

              <label style={s.checkboxRow}>
                <input type="checkbox" checked={form.isAdmin ?? false} onChange={(e) => setForm({ ...form, isAdmin: e.target.checked })} />
                <span style={{ marginLeft: 8 }}>Cấp quyền Admin</span>
              </label>
            </div>
            <div style={s.modalFooter}>
              <button onClick={closeModal} style={s.cancelBtn}>Huỷ</button>
              <button onClick={handleSave} disabled={saving} style={s.btnPrimary}>
                {saving ? 'Đang lưu...' : 'Lưu'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Modal Delete */}
      {modal?.mode === 'delete' && (
        <div style={s.overlay}>
          <div style={{ ...s.modal, maxWidth: 420 }}>
            <div style={s.modalHeader}>
              <h3 style={s.modalTitle}>Xoá người dùng</h3>
              <button onClick={closeModal} style={s.modalClose}><X size={16}/></button>
            </div>
            <div style={s.modalBody}>
              <p style={{ color: '#6b7280', marginBottom: 8 }}>
                Bạn chắc chắn muốn xoá <strong>{modal.user?.email}</strong>?
              </p>
              <p style={{ color: '#ef4444', fontSize: 13, margin: 0 }}>
                Hành động này không thể hoàn tác. Tài khoản sẽ bị xoá khỏi Firebase Auth và toàn bộ dữ liệu trong cơ sở dữ liệu.
              </p>
            </div>
            <div style={s.modalFooter}>
              <button onClick={closeModal} style={s.cancelBtn}>Huỷ</button>
              <button onClick={handleDelete} disabled={saving} style={{ ...s.btnPrimary, background: '#ef4444' }}>
                {saving ? 'Đang xoá...' : 'Xoá'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

const s = {
  toolbar: { display: 'flex', gap: 12, marginBottom: 16, alignItems: 'center', flexWrap: 'wrap' },
  searchInput: { flex: 1, minWidth: 200, padding: '8px 14px', border: '1.5px solid #e2e8f0', borderRadius: 8, fontSize: 14, outline: 'none' },
  btnPrimary: { padding: '8px 18px', background: '#1a73e8', color: '#fff', border: 'none', borderRadius: 8, cursor: 'pointer', fontWeight: 600, fontSize: 14 },
  btnSecondary: { padding: '8px 14px', background: '#f1f5f9', color: '#334155', border: '1.5px solid #e2e8f0', borderRadius: 8, cursor: 'pointer', fontSize: 14 },
  errorBox: { background: '#fee2e2', color: '#dc2626', padding: '10px 16px', borderRadius: 8, marginBottom: 12 },
  statsRow: { display: 'flex', gap: 20, marginBottom: 16, flexWrap: 'wrap' },
  stat: { fontSize: 14, color: '#64748b' },
  loading: { textAlign: 'center', padding: 60, color: '#94a3b8', fontSize: 16 },
  tableWrap: { overflowX: 'auto', borderRadius: 12, border: '1px solid #e2e8f0', background: '#fff' },
  table: { width: '100%', borderCollapse: 'collapse', fontSize: 14 },
  thead: { background: '#f8fafc' },
  th: { padding: '12px 16px', textAlign: 'left', fontWeight: 600, color: '#374151', borderBottom: '1px solid #e2e8f0', whiteSpace: 'nowrap' },
  tr: { borderBottom: '1px solid #f1f5f9', transition: 'background 0.1s' },
  td: { padding: '12px 16px', verticalAlign: 'middle' },
  userCell: { display: 'flex', alignItems: 'center', gap: 10 },
  avatar: { width: 36, height: 36, borderRadius: '50%', background: '#dbeafe', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, color: '#1a73e8', flexShrink: 0, overflow: 'hidden' },
  avatarImg: { width: 36, height: 36, objectFit: 'cover' },
  name: { fontWeight: 600, color: '#1e293b' },
  email: { fontSize: 12, color: '#64748b' },
  badge: { display: 'inline-block', padding: '2px 10px', borderRadius: 99, background: '#f1f5f9', color: '#475569', fontSize: 12, fontWeight: 500 },
  statusBtn: { padding: '4px 10px', borderRadius: 99, border: 'none', cursor: 'pointer', fontSize: 12, fontWeight: 600 },
  actions: { display: 'flex', gap: 6 },
  btnStats: { padding: '4px 10px', background: '#ede9fe', border: 'none', borderRadius: 6, cursor: 'pointer', fontSize: 14 },
  btnEdit: { padding: '4px 10px', background: '#e0f2fe', border: 'none', borderRadius: 6, cursor: 'pointer', fontSize: 14 },
  btnDelete: { padding: '4px 10px', background: '#fee2e2', border: 'none', borderRadius: 6, cursor: 'pointer', fontSize: 14 },
  overlay: { position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.45)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 200 },
  modal: { background: '#fff', borderRadius: 14, width: 420, maxWidth: '90vw', maxHeight: '90vh', display: 'flex', flexDirection: 'column', overflow: 'hidden' },
  modalHeader: { padding: '18px 24px', borderBottom: '1px solid #e2e8f0', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexShrink: 0 },
  modalTitle: { margin: 0, fontSize: 18, fontWeight: 700, color: '#1e293b' },
  modalBody: { padding: '20px 24px', overflowY: 'auto', flex: 1 },
  modalFooter: { padding: '14px 24px', borderTop: '1px solid #e2e8f0', display: 'flex', justifyContent: 'flex-end', gap: 12, flexShrink: 0 },
  modalClose: { background: 'none', border: 'none', cursor: 'pointer', fontSize: 20, color: '#94a3b8', padding: '2px 4px', lineHeight: 1, borderRadius: 4 },
  label: { display: 'block', fontSize: 13, fontWeight: 500, color: '#374151', marginBottom: 4, marginTop: 12 },
  input: { width: '100%', padding: '9px 12px', border: '1.5px solid #e2e8f0', borderRadius: 8, fontSize: 14, outline: 'none', boxSizing: 'border-box' },
  checkboxRow: { display: 'flex', alignItems: 'center', marginTop: 16, fontSize: 14, cursor: 'pointer' },
  cancelBtn: { padding: '9px 20px', border: '1.5px solid #e2e8f0', borderRadius: 8, background: '#fff', cursor: 'pointer', fontWeight: 500 },
  statsGrid: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 },
  statCard: { background: '#f8fafc', borderRadius: 10, padding: '16px 12px', textAlign: 'center', border: '1px solid #e2e8f0' },
  statIcon: { fontSize: 24, marginBottom: 6 },
  statValue: { fontSize: 22, fontWeight: 700, color: '#1e293b', marginBottom: 2 },
  statLabel: { fontSize: 12, color: '#64748b' },
}
