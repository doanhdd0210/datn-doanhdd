import { useState, useEffect, useCallback, useRef } from 'react'
import { topicsApi } from '../services/api'
import { exportJson, exportCsv, importJson } from '../utils/importExport'

const COLOR_PALETTE = [
  '#58CC02', '#1CB0F6', '#FFD900', '#FF9600',
  '#CE82FF', '#FF4B4B', '#2DB6FF', '#00CD9C',
]

function Toast({ msg, type }) {
  if (!msg) return null
  return (
    <div style={{
      position: 'fixed', bottom: 24, right: 24, zIndex: 9999,
      background: type === 'error' ? '#fee2e2' : '#dcfce7',
      color: type === 'error' ? '#dc2626' : '#16a34a',
      padding: '12px 20px', borderRadius: 8, fontWeight: 600,
      boxShadow: '0 4px 16px rgba(0,0,0,0.12)', fontSize: 14,
    }}>
      {msg}
    </div>
  )
}

export default function TopicsPage() {
  const [topics, setTopics] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')
  const [modal, setModal] = useState(null)
  const [saving, setSaving] = useState(false)
  const [form, setForm] = useState({})
  const [toast, setToast] = useState({ msg: '', type: 'success' })
  const [importProgress, setImportProgress] = useState('')
  const importRef = useRef()

  const showToast = (msg, type = 'success') => {
    setToast({ msg, type })
    setTimeout(() => setToast({ msg: '', type: 'success' }), 2500)
  }

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const data = await topicsApi.list()
      setTopics(data ?? [])
    } catch (e) {
      setError(e.message)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { load() }, [load])

  const filtered = topics.filter(t =>
    t.title?.toLowerCase().includes(search.toLowerCase()) ||
    t.description?.toLowerCase().includes(search.toLowerCase())
  )

  const defaultForm = { title: '', description: '', icon: '📚', color: '#58CC02', order: 0, isActive: true }

  const openCreate = () => { setForm(defaultForm); setModal({ mode: 'create' }) }
  const openEdit = (t) => {
    setForm({ title: t.title ?? '', description: t.description ?? '', icon: t.icon ?? '📚', color: t.color ?? '#58CC02', order: t.order ?? 0, isActive: t.isActive ?? true })
    setModal({ mode: 'edit', item: t })
  }
  const openDelete = (t) => setModal({ mode: 'delete', item: t })
  const closeModal = () => { setModal(null); setForm({}) }

  const handleSave = async () => {
    if (!form.title?.trim()) { alert('Tiêu đề không được để trống'); return }
    setSaving(true)
    try {
      if (modal.mode === 'create') {
        await topicsApi.create(form)
        showToast('Đã tạo chủ đề thành công')
      } else {
        await topicsApi.update(modal.item.id, form)
        showToast('Đã cập nhật chủ đề')
      }
      await load()
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
      await topicsApi.delete(modal.item.id)
      showToast('Đã xoá chủ đề')
      await load()
      closeModal()
    } catch (e) {
      alert('Lỗi: ' + e.message)
    } finally {
      setSaving(false)
    }
  }

  const handleImport = async (e) => {
    const file = e.target.files?.[0]
    if (!file) return
    e.target.value = ''
    try {
      const data = await importJson(file)
      if (!Array.isArray(data)) throw new Error('File phải là một mảng JSON')
      for (let i = 0; i < data.length; i++) {
        setImportProgress(`Đang import ${i + 1}/${data.length}...`)
        await topicsApi.create(data[i])
      }
      setImportProgress('')
      showToast(`Đã import ${data.length} mục thành công`)
      await load()
    } catch (e) {
      setImportProgress('')
      showToast('Lỗi: ' + e.message, 'error')
    }
  }

  const handleExportJson = () => exportJson(topics, 'topics_export.json')

  const handleExportCsv = () => {
    const headers = ['id', 'title', 'description', 'icon', 'color', 'order', 'isActive']
    exportCsv(topics, headers, 'topics.csv')
  }

  return (
    <div>
      <Toast msg={toast.msg} type={toast.type} />

      {/* Toolbar */}
      <div style={s.toolbar}>
        <input
          placeholder="Tìm chủ đề..."
          value={search}
          onChange={e => setSearch(e.target.value)}
          style={s.searchInput}
        />
        <button onClick={load} style={s.btnSecondary}>⟳ Làm mới</button>
        <button onClick={openCreate} style={s.btnPrimary}>+ Thêm chủ đề</button>
        <div style={s.btnGroup}>
          <button onClick={() => importRef.current?.click()} style={s.btnSm}>📥 Import JSON</button>
          <button onClick={handleExportJson} style={s.btnSm}>📤 Export JSON</button>
          <button onClick={handleExportCsv} style={s.btnSm}>📊 Export CSV</button>
        </div>
        <input type="file" accept=".json" ref={importRef} style={{ display: 'none' }} onChange={handleImport} />
      </div>

      {importProgress && <div style={s.progressBox}>{importProgress}</div>}
      {error && <div style={s.errorBox}>{error}</div>}

      <div style={s.statsRow}>
        <span style={s.stat}>Tổng: <strong>{topics.length}</strong></span>
        <span style={s.stat}>Hiển thị: <strong>{filtered.length}</strong></span>
        <span style={s.stat}>Đang hoạt động: <strong>{topics.filter(t => t.isActive).length}</strong></span>
      </div>

      {loading ? (
        <div style={s.loading}>⏳ Đang tải...</div>
      ) : filtered.length === 0 ? (
        <div style={s.empty}>
          <div style={{ fontSize: 48 }}>📚</div>
          <div style={{ color: '#94a3b8', marginTop: 8 }}>Chưa có chủ đề nào</div>
        </div>
      ) : (
        <div style={s.tableWrap}>
          <table style={s.table}>
            <thead>
              <tr style={s.thead}>
                <th style={s.th}>Icon</th>
                <th style={s.th}>Tên chủ đề</th>
                <th style={s.th}>Mô tả</th>
                <th style={s.th}>Màu</th>
                <th style={s.th}>Số bài học</th>
                <th style={s.th}>Trạng thái</th>
                <th style={s.th}>Thứ tự</th>
                <th style={s.th}>Hành động</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((t, idx) => (
                <tr key={t.id} style={{ ...s.tr, background: idx % 2 === 0 ? '#fff' : '#f9f9f9' }}
                  onMouseEnter={e => e.currentTarget.style.background = '#f0f9eb'}
                  onMouseLeave={e => e.currentTarget.style.background = idx % 2 === 0 ? '#fff' : '#f9f9f9'}>
                  <td style={s.td}><span style={{ fontSize: 24 }}>{t.icon || '📚'}</span></td>
                  <td style={s.td}><strong style={{ color: '#1e293b' }}>{t.title}</strong></td>
                  <td style={{ ...s.td, color: '#64748b', maxWidth: 220 }}>
                    <span style={{ display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>
                      {t.description || '—'}
                    </span>
                  </td>
                  <td style={s.td}>
                    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                      <span style={{ width: 16, height: 16, borderRadius: 4, background: t.color || '#ccc', display: 'inline-block', border: '1px solid rgba(0,0,0,0.1)' }} />
                      <span style={{ fontSize: 12, color: '#64748b', fontFamily: 'monospace' }}>{t.color || '—'}</span>
                    </span>
                  </td>
                  <td style={{ ...s.td, textAlign: 'center' }}>
                    <span style={s.badge}>{t.lessonCount ?? t.lessonsCount ?? 0}</span>
                  </td>
                  <td style={s.td}>
                    <span style={{ ...s.statusBadge, background: t.isActive ? '#dcfce7' : '#f1f5f9', color: t.isActive ? '#16a34a' : '#64748b' }}>
                      {t.isActive ? '✓ Hiện' : '— Ẩn'}
                    </span>
                  </td>
                  <td style={{ ...s.td, textAlign: 'center', color: '#64748b' }}>{t.order ?? 0}</td>
                  <td style={s.td}>
                    <div style={s.actions}>
                      <button onClick={() => openEdit(t)} style={s.btnEdit} title="Sửa">✏️</button>
                      <button onClick={() => openDelete(t)} style={s.btnDelete} title="Xoá">🗑️</button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Create/Edit Modal */}
      {modal && modal.mode !== 'delete' && (
        <div style={s.overlay}>
          <div style={s.modal}>
            <h3 style={s.modalTitle}>{modal.mode === 'create' ? 'Thêm chủ đề mới' : `Sửa: ${modal.item?.title}`}</h3>

            <label style={s.label}>Tiêu đề *</label>
            <input style={s.input} value={form.title ?? ''} onChange={e => setForm({ ...form, title: e.target.value })} placeholder="Tên chủ đề..." />

            <label style={s.label}>Mô tả</label>
            <textarea style={{ ...s.input, minHeight: 72, resize: 'vertical' }} value={form.description ?? ''} onChange={e => setForm({ ...form, description: e.target.value })} placeholder="Mô tả ngắn..." />

            <label style={s.label}>Icon (emoji)</label>
            <input style={{ ...s.input, fontSize: 20 }} value={form.icon ?? ''} onChange={e => setForm({ ...form, icon: e.target.value })} placeholder="📚" maxLength={4} />

            <label style={s.label}>Màu</label>
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 8 }}>
              {COLOR_PALETTE.map(c => (
                <button key={c} onClick={() => setForm({ ...form, color: c })}
                  style={{ width: 28, height: 28, borderRadius: 6, background: c, border: form.color === c ? '3px solid #1e293b' : '2px solid transparent', cursor: 'pointer' }} />
              ))}
            </div>
            <input type="color" value={form.color ?? '#58CC02'} onChange={e => setForm({ ...form, color: e.target.value })} style={{ width: 48, height: 32, border: 'none', borderRadius: 4, cursor: 'pointer' }} />
            <span style={{ marginLeft: 8, fontSize: 12, color: '#64748b', fontFamily: 'monospace' }}>{form.color}</span>

            <label style={s.label}>Thứ tự</label>
            <input style={s.input} type="number" value={form.order ?? 0} onChange={e => setForm({ ...form, order: Number(e.target.value) })} />

            <label style={s.checkboxRow}>
              <input type="checkbox" checked={form.isActive ?? true} onChange={e => setForm({ ...form, isActive: e.target.checked })} />
              <span style={{ marginLeft: 8 }}>Hiển thị (isActive)</span>
            </label>

            <div style={s.modalActions}>
              <button onClick={closeModal} style={s.cancelBtn}>Huỷ</button>
              <button onClick={handleSave} disabled={saving} style={s.btnPrimary}>{saving ? 'Đang lưu...' : 'Lưu'}</button>
            </div>
          </div>
        </div>
      )}

      {/* Delete Modal */}
      {modal?.mode === 'delete' && (
        <div style={s.overlay}>
          <div style={s.modal}>
            <h3 style={s.modalTitle}>Xoá chủ đề</h3>
            <p style={{ color: '#6b7280', marginBottom: 8 }}>Bạn chắc chắn muốn xoá <strong>{modal.item?.title}</strong>?</p>
            <p style={{ color: '#ef4444', fontSize: 13, marginBottom: 24 }}>Hành động này không thể hoàn tác.</p>
            <div style={s.modalActions}>
              <button onClick={closeModal} style={s.cancelBtn}>Huỷ</button>
              <button onClick={handleDelete} disabled={saving} style={{ ...s.btnPrimary, background: '#ef4444' }}>{saving ? 'Đang xoá...' : 'Xoá'}</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

const s = {
  toolbar: { display: 'flex', gap: 10, marginBottom: 16, alignItems: 'center', flexWrap: 'wrap' },
  searchInput: { flex: 1, minWidth: 180, padding: '8px 14px', border: '1.5px solid #e2e8f0', borderRadius: 8, fontSize: 14, outline: 'none' },
  btnPrimary: { padding: '8px 18px', background: '#58CC02', color: '#fff', border: 'none', borderRadius: 8, cursor: 'pointer', fontWeight: 600, fontSize: 14 },
  btnSecondary: { padding: '8px 14px', background: '#f1f5f9', color: '#334155', border: '1.5px solid #e2e8f0', borderRadius: 8, cursor: 'pointer', fontSize: 14 },
  btnGroup: { display: 'flex', gap: 6 },
  btnSm: { padding: '6px 12px', background: '#f8fafc', color: '#475569', border: '1.5px solid #e2e8f0', borderRadius: 6, cursor: 'pointer', fontSize: 12, fontWeight: 500 },
  errorBox: { background: '#fee2e2', color: '#dc2626', padding: '10px 16px', borderRadius: 8, marginBottom: 12 },
  progressBox: { background: '#fef9c3', color: '#854d0e', padding: '10px 16px', borderRadius: 8, marginBottom: 12 },
  statsRow: { display: 'flex', gap: 20, marginBottom: 16, flexWrap: 'wrap' },
  stat: { fontSize: 14, color: '#64748b' },
  loading: { textAlign: 'center', padding: 60, color: '#94a3b8', fontSize: 16 },
  empty: { textAlign: 'center', padding: 60, color: '#94a3b8' },
  tableWrap: { overflowX: 'auto', borderRadius: 12, border: '1px solid #e2e8f0', background: '#fff' },
  table: { width: '100%', borderCollapse: 'collapse', fontSize: 14 },
  thead: { background: '#f8fafc' },
  th: { padding: '12px 16px', textAlign: 'left', fontWeight: 600, color: '#374151', borderBottom: '1px solid #e2e8f0', whiteSpace: 'nowrap' },
  tr: { borderBottom: '1px solid #f1f5f9', transition: 'background 0.1s' },
  td: { padding: '12px 16px', verticalAlign: 'middle' },
  badge: { display: 'inline-block', padding: '2px 10px', borderRadius: 99, background: '#f1f5f9', color: '#475569', fontSize: 12, fontWeight: 500 },
  statusBadge: { display: 'inline-block', padding: '3px 10px', borderRadius: 99, fontSize: 12, fontWeight: 600 },
  actions: { display: 'flex', gap: 6 },
  btnEdit: { padding: '4px 10px', background: '#e0f2fe', border: 'none', borderRadius: 6, cursor: 'pointer', fontSize: 14 },
  btnDelete: { padding: '4px 10px', background: '#fee2e2', border: 'none', borderRadius: 6, cursor: 'pointer', fontSize: 14 },
  overlay: { position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.45)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 200 },
  modal: { background: '#fff', borderRadius: 14, padding: '28px 32px', width: 480, maxWidth: '90vw', maxHeight: '90vh', overflowY: 'auto' },
  modalTitle: { margin: '0 0 20px', fontSize: 18, fontWeight: 700, color: '#1e293b' },
  label: { display: 'block', fontSize: 13, fontWeight: 500, color: '#374151', marginBottom: 4, marginTop: 12 },
  input: { width: '100%', padding: '9px 12px', border: '1.5px solid #e2e8f0', borderRadius: 8, fontSize: 14, outline: 'none', boxSizing: 'border-box' },
  checkboxRow: { display: 'flex', alignItems: 'center', marginTop: 16, fontSize: 14, cursor: 'pointer' },
  modalActions: { display: 'flex', justifyContent: 'flex-end', gap: 12, marginTop: 24 },
  cancelBtn: { padding: '9px 20px', border: '1.5px solid #e2e8f0', borderRadius: 8, background: '#fff', cursor: 'pointer', fontWeight: 500 },
}
