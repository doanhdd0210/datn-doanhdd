import { useState, useEffect, useCallback } from 'react'
import { usersApi } from '../services/api'

const PROVIDER_LABEL = { 'google.com': 'Google', password: 'Email', phone: 'Phone' }

export default function UsersPage() {
  const [users, setUsers] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')
  const [modal, setModal] = useState(null) // null | { mode: 'create'|'edit'|'delete', user? }
  const [saving, setSaving] = useState(false)
  const [form, setForm] = useState({})

  const loadUsers = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const data = await usersApi.list()
      setUsers(data ?? [])
    } catch (e) {
      setError(e.message)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { loadUsers() }, [loadUsers])

  const filtered = users.filter((u) => {
    const q = search.toLowerCase()
    return (
      u.email?.toLowerCase().includes(q) ||
      u.displayName?.toLowerCase().includes(q) ||
      u.uid?.toLowerCase().includes(q)
    )
  })

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
        <button onClick={loadUsers} style={s.btnSecondary} title="Làm mới">⟳ Làm mới</button>
        <button onClick={openCreate} style={s.btnPrimary}>+ Thêm người dùng</button>
      </div>

      {error && <div style={s.errorBox}>{error}</div>}

      {/* Stats */}
      <div style={s.statsRow}>
        <span style={s.stat}>Tổng: <strong>{users.length}</strong></span>
        <span style={s.stat}>Đang hiển thị: <strong>{filtered.length}</strong></span>
        <span style={s.stat}>Admin: <strong>{users.filter((u) => u.isAdmin).length}</strong></span>
        <span style={s.stat}>Bị khoá: <strong>{users.filter((u) => u.disabled).length}</strong></span>
      </div>

      {/* Table */}
      {loading ? (
        <div style={s.loading}>Đang tải...</div>
      ) : (
        <div style={s.tableWrap}>
          <table style={s.table}>
            <thead>
              <tr style={s.thead}>
                <th style={s.th}>Người dùng</th>
                <th style={s.th}>UID</th>
                <th style={s.th}>Provider</th>
                <th style={s.th}>Trạng thái</th>
                <th style={s.th}>Admin</th>
                <th style={s.th}>Ngày tạo</th>
                <th style={s.th}>Thao tác</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((u) => (
                <tr key={u.uid} style={s.tr}>
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
                      {u.disabled ? '🔒 Khoá' : '✓ Hoạt động'}
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
                    <div style={s.actions}>
                      <button onClick={() => openEdit(u)} style={s.btnEdit} title="Sửa">✏️</button>
                      <button onClick={() => openDelete(u)} style={s.btnDelete} title="Xoá">🗑️</button>
                    </div>
                  </td>
                </tr>
              ))}
              {filtered.length === 0 && (
                <tr><td colSpan={7} style={{ textAlign: 'center', padding: 40, color: '#94a3b8' }}>Không có kết quả</td></tr>
              )}
            </tbody>
          </table>
        </div>
      )}

      {/* Modal Create / Edit */}
      {modal && modal.mode !== 'delete' && (
        <div style={s.overlay}>
          <div style={s.modal}>
            <h3 style={s.modalTitle}>
              {modal.mode === 'create' ? 'Thêm người dùng mới' : `Sửa: ${modal.user?.email}`}
            </h3>

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

            <div style={s.modalActions}>
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
          <div style={s.modal}>
            <h3 style={s.modalTitle}>Xoá người dùng</h3>
            <p style={{ color: '#6b7280', marginBottom: 8 }}>
              Bạn chắc chắn muốn xoá <strong>{modal.user?.email}</strong>?
            </p>
            <p style={{ color: '#ef4444', fontSize: 13, marginBottom: 24 }}>
              Hành động này không thể hoàn tác. Tài khoản sẽ bị xoá khỏi Firebase Auth và Firestore.
            </p>
            <div style={s.modalActions}>
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
  avatar: { width: 36, height: 36, borderRadius: '50%', background: '#e0e7ff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, color: '#4f46e5', flexShrink: 0, overflow: 'hidden' },
  avatarImg: { width: 36, height: 36, objectFit: 'cover' },
  name: { fontWeight: 600, color: '#1e293b' },
  email: { fontSize: 12, color: '#64748b' },
  badge: { display: 'inline-block', padding: '2px 10px', borderRadius: 99, background: '#f1f5f9', color: '#475569', fontSize: 12, fontWeight: 500 },
  statusBtn: { padding: '4px 10px', borderRadius: 99, border: 'none', cursor: 'pointer', fontSize: 12, fontWeight: 600 },
  actions: { display: 'flex', gap: 6 },
  btnEdit: { padding: '4px 10px', background: '#e0f2fe', border: 'none', borderRadius: 6, cursor: 'pointer', fontSize: 14 },
  btnDelete: { padding: '4px 10px', background: '#fee2e2', border: 'none', borderRadius: 6, cursor: 'pointer', fontSize: 14 },
  overlay: { position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.45)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 200 },
  modal: { background: '#fff', borderRadius: 14, padding: '28px 32px', width: 420, maxWidth: '90vw', maxHeight: '90vh', overflowY: 'auto' },
  modalTitle: { margin: '0 0 20px', fontSize: 18, fontWeight: 700, color: '#1e293b' },
  label: { display: 'block', fontSize: 13, fontWeight: 500, color: '#374151', marginBottom: 4, marginTop: 12 },
  input: { width: '100%', padding: '9px 12px', border: '1.5px solid #e2e8f0', borderRadius: 8, fontSize: 14, outline: 'none', boxSizing: 'border-box' },
  checkboxRow: { display: 'flex', alignItems: 'center', marginTop: 16, fontSize: 14, cursor: 'pointer' },
  modalActions: { display: 'flex', justifyContent: 'flex-end', gap: 12, marginTop: 24 },
  cancelBtn: { padding: '9px 20px', border: '1.5px solid #e2e8f0', borderRadius: 8, background: '#fff', cursor: 'pointer', fontWeight: 500 },
}
