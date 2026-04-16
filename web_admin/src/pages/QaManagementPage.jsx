import { useState, useEffect, useCallback } from 'react'
import { qaApi } from '../services/api'
import { exportJson } from '../utils/importExport'

function Toast({ msg, type }) {
  if (!msg) return null
  return (
    <div style={{
      position: 'fixed', bottom: 24, right: 24, zIndex: 9999,
      background: type === 'error' ? '#fee2e2' : '#dcfce7',
      color: type === 'error' ? '#dc2626' : '#16a34a',
      padding: '12px 20px', borderRadius: 8, fontWeight: 600,
      boxShadow: '0 4px 16px rgba(0,0,0,0.12)', fontSize: 14,
    }}>{msg}</div>
  )
}

const STATUS_FILTERS = [
  { id: 'all', label: 'Tất cả' },
  { id: 'solved', label: '✓ Đã giải' },
  { id: 'unsolved', label: '○ Chưa giải' },
]

export default function QaManagementPage() {
  const [posts, setPosts] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState('all')
  const [page, setPage] = useState(1)
  const [hasMore, setHasMore] = useState(true)
  const [modal, setModal] = useState(null) // { mode: 'view'|'delete', item }
  const [deleting, setDeleting] = useState(false)
  const [toast, setToast] = useState({ msg: '', type: 'success' })

  const showToast = (msg, type = 'success') => {
    setToast({ msg, type })
    setTimeout(() => setToast({ msg: '', type: 'success' }), 2500)
  }

  const load = useCallback(async (reset = false) => {
    setLoading(true)
    setError('')
    const currentPage = reset ? 1 : page
    try {
      const data = await qaApi.list(currentPage)
      const items = data?.items ?? data ?? []
      if (reset) {
        setPosts(items)
        setPage(1)
      } else {
        setPosts(prev => currentPage === 1 ? items : [...prev, ...items])
      }
      setHasMore(items.length >= 20)
    } catch (e) {
      setError(e.message)
    } finally {
      setLoading(false)
    }
  }, [page])

  useEffect(() => { load(true) }, []) // eslint-disable-line

  const loadMore = () => {
    const nextPage = page + 1
    setPage(nextPage)
  }

  useEffect(() => {
    if (page > 1) load(false)
  }, [page]) // eslint-disable-line

  const filtered = posts.filter(p => {
    const q = search.toLowerCase()
    const matchSearch = !q || p.title?.toLowerCase().includes(q) || p.authorName?.toLowerCase().includes(q) || p.authorEmail?.toLowerCase().includes(q)
    const matchStatus = statusFilter === 'all' || (statusFilter === 'solved' ? p.isSolved : !p.isSolved)
    return matchSearch && matchStatus
  })

  const openView = (item) => setModal({ mode: 'view', item })
  const openDelete = (item) => setModal({ mode: 'delete', item })
  const closeModal = () => setModal(null)

  const handleDelete = async () => {
    setDeleting(true)
    try {
      await qaApi.delete(modal.item.id)
      showToast('Đã xoá bài đăng')
      setPosts(prev => prev.filter(p => p.id !== modal.item.id))
      closeModal()
    } catch (e) {
      alert('Lỗi: ' + e.message)
    } finally {
      setDeleting(false)
    }
  }

  const handleExportJson = () => exportJson(posts, 'qa_posts_export.json')

  const formatDate = (d) => {
    if (!d) return '—'
    try { return new Date(d).toLocaleDateString('vi-VN', { day: '2-digit', month: '2-digit', year: 'numeric' }) }
    catch { return d }
  }

  return (
    <div>
      <Toast msg={toast.msg} type={toast.type} />

      {/* Toolbar */}
      <div style={s.toolbar}>
        <input placeholder="Tìm theo tiêu đề, người hỏi..." value={search} onChange={e => setSearch(e.target.value)} style={s.searchInput} />
        <div style={{ display: 'flex', gap: 4 }}>
          {STATUS_FILTERS.map(f => (
            <button key={f.id} onClick={() => setStatusFilter(f.id)}
              style={{ ...s.filterBtn, ...(statusFilter === f.id ? s.filterBtnActive : {}) }}>
              {f.label}
            </button>
          ))}
        </div>
        <button onClick={() => load(true)} style={s.btnSecondary}>⟳ Làm mới</button>
        <button onClick={handleExportJson} style={s.btnSm}>📤 Export JSON</button>
      </div>

      {error && <div style={s.errorBox}>{error}</div>}

      <div style={s.statsRow}>
        <span style={s.stat}>Tổng: <strong>{posts.length}</strong></span>
        <span style={s.stat}>Hiển thị: <strong>{filtered.length}</strong></span>
        <span style={s.stat}>Đã giải: <strong>{posts.filter(p => p.isSolved).length}</strong></span>
      </div>

      {loading && posts.length === 0 ? (
        <div style={s.loading}>⏳ Đang tải...</div>
      ) : filtered.length === 0 ? (
        <div style={s.empty}><div style={{ fontSize: 48 }}>💬</div><div style={{ color: '#94a3b8', marginTop: 8 }}>Không có bài đăng nào</div></div>
      ) : (
        <>
          <div style={s.tableWrap}>
            <table style={s.table}>
              <thead>
                <tr style={s.thead}>
                  <th style={s.th}>Người hỏi</th>
                  <th style={s.th}>Tiêu đề</th>
                  <th style={s.th}>Tags</th>
                  <th style={s.th}>Trả lời</th>
                  <th style={s.th}>Upvotes</th>
                  <th style={s.th}>Trạng thái</th>
                  <th style={s.th}>Ngày tạo</th>
                  <th style={s.th}>Hành động</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((p, idx) => (
                  <tr key={p.id} style={{ ...s.tr, background: idx % 2 === 0 ? '#fff' : '#f9f9f9', cursor: 'pointer' }}
                    onMouseEnter={e => e.currentTarget.style.background = '#f0f9eb'}
                    onMouseLeave={e => e.currentTarget.style.background = idx % 2 === 0 ? '#fff' : '#f9f9f9'}
                    onClick={() => openView(p)}>
                    <td style={s.td}>
                      <div style={{ fontWeight: 600, fontSize: 13, color: '#1e293b' }}>{p.authorName || p.authorEmail || '—'}</div>
                      {p.authorEmail && p.authorName && <div style={{ fontSize: 11, color: '#94a3b8' }}>{p.authorEmail}</div>}
                    </td>
                    <td style={{ ...s.td, maxWidth: 240 }}>
                      <span style={{ display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden', fontWeight: 500 }}>
                        {p.title || '(Không có tiêu đề)'}
                      </span>
                    </td>
                    <td style={s.td}>
                      <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
                        {(p.tags ?? []).slice(0, 3).map((tag, i) => (
                          <span key={i} style={{ ...s.badge, background: '#dbeafe', color: '#1d4ed8', fontSize: 11 }}>{tag}</span>
                        ))}
                      </div>
                    </td>
                    <td style={{ ...s.td, textAlign: 'center' }}>
                      <span style={s.badge}>{p.answerCount ?? p.answers?.length ?? 0}</span>
                    </td>
                    <td style={{ ...s.td, textAlign: 'center' }}>
                      <span style={{ ...s.badge, background: '#fef9c3', color: '#854d0e' }}>👍 {p.upvotes ?? p.upvoteCount ?? 0}</span>
                    </td>
                    <td style={s.td}>
                      <span style={{ ...s.statusBadge, background: p.isSolved ? '#dcfce7' : '#fff7ed', color: p.isSolved ? '#16a34a' : '#c2410c' }}>
                        {p.isSolved ? '✓ Đã giải' : '○ Chưa giải'}
                      </span>
                    </td>
                    <td style={{ ...s.td, fontSize: 12, color: '#64748b' }}>{formatDate(p.createdAt)}</td>
                    <td style={s.td} onClick={e => e.stopPropagation()}>
                      <div style={s.actions}>
                        <button onClick={() => openView(p)} style={s.btnEdit} title="Xem">👁️</button>
                        <button onClick={() => openDelete(p)} style={s.btnDelete} title="Xoá">🗑️</button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {hasMore && (
            <div style={{ textAlign: 'center', marginTop: 20 }}>
              <button onClick={loadMore} disabled={loading} style={{ ...s.btnSecondary, padding: '10px 28px' }}>
                {loading ? 'Đang tải...' : 'Tải thêm'}
              </button>
            </div>
          )}
        </>
      )}

      {/* View Modal */}
      {modal?.mode === 'view' && (
        <div style={s.overlay}>
          <div style={{ ...s.modal, maxWidth: 700 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 16 }}>
              <h3 style={{ ...s.modalTitle, margin: 0, flex: 1 }}>{modal.item.title || '(Không có tiêu đề)'}</h3>
              <button onClick={closeModal} style={{ background: 'none', border: 'none', cursor: 'pointer', fontSize: 20, color: '#94a3b8', marginLeft: 8 }}>✕</button>
            </div>

            <div style={{ display: 'flex', gap: 12, marginBottom: 16, flexWrap: 'wrap' }}>
              <span style={s.badge}>👤 {modal.item.authorName || modal.item.authorEmail || '—'}</span>
              <span style={{ ...s.badge, background: modal.item.isSolved ? '#dcfce7' : '#fff7ed', color: modal.item.isSolved ? '#16a34a' : '#c2410c' }}>
                {modal.item.isSolved ? '✓ Đã giải' : '○ Chưa giải'}
              </span>
              <span style={s.badge}>📅 {formatDate(modal.item.createdAt)}</span>
              {(modal.item.tags ?? []).map((tag, i) => (
                <span key={i} style={{ ...s.badge, background: '#dbeafe', color: '#1d4ed8' }}>{tag}</span>
              ))}
            </div>

            <div style={{ background: '#f8fafc', borderRadius: 8, padding: 16, marginBottom: 16, color: '#374151', lineHeight: 1.6 }}>
              {modal.item.body || modal.item.content || modal.item.question || '(Không có nội dung)'}
            </div>

            {(modal.item.answers ?? []).length > 0 && (
              <div>
                <h4 style={{ margin: '0 0 10px', fontSize: 15, color: '#1e293b' }}>Trả lời ({modal.item.answers.length})</h4>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                  {modal.item.answers.map((ans, i) => (
                    <div key={i} style={{ background: ans.isAccepted ? '#f0fdf4' : '#f8fafc', border: ans.isAccepted ? '1px solid #86efac' : '1px solid #e2e8f0', borderRadius: 8, padding: '12px 14px' }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
                        <span style={{ fontWeight: 600, fontSize: 13, color: '#374151' }}>{ans.authorName || ans.authorEmail || '—'}</span>
                        {ans.isAccepted && <span style={{ ...s.badge, background: '#dcfce7', color: '#16a34a' }}>✓ Đáp án được chọn</span>}
                      </div>
                      <div style={{ color: '#475569', fontSize: 14, lineHeight: 1.5 }}>{ans.body || ans.content || '—'}</div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            <div style={s.modalActions}>
              <button onClick={() => { closeModal(); openDelete(modal.item) }} style={{ ...s.cancelBtn, color: '#dc2626', border: '1.5px solid #dc2626' }}>🗑️ Xoá bài đăng</button>
              <button onClick={closeModal} style={s.btnPrimary}>Đóng</button>
            </div>
          </div>
        </div>
      )}

      {/* Delete Modal */}
      {modal?.mode === 'delete' && (
        <div style={s.overlay}>
          <div style={{ ...s.modal, maxWidth: 400 }}>
            <h3 style={s.modalTitle}>Xoá bài đăng QA</h3>
            <p style={{ color: '#6b7280', marginBottom: 8 }}>Xoá bài đăng: <strong>{modal.item?.title || '(không có tiêu đề)'}</strong>?</p>
            <p style={{ color: '#ef4444', fontSize: 13, marginBottom: 24 }}>Hành động này không thể hoàn tác. Tất cả câu trả lời cũng sẽ bị xoá.</p>
            <div style={s.modalActions}>
              <button onClick={closeModal} style={s.cancelBtn}>Huỷ</button>
              <button onClick={handleDelete} disabled={deleting} style={{ ...s.btnPrimary, background: '#ef4444' }}>{deleting ? 'Đang xoá...' : 'Xoá'}</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

const s = {
  toolbar: { display: 'flex', gap: 10, marginBottom: 16, alignItems: 'center', flexWrap: 'wrap' },
  searchInput: { flex: 1, minWidth: 200, padding: '8px 14px', border: '1.5px solid #e2e8f0', borderRadius: 8, fontSize: 14, outline: 'none' },
  filterBtn: { padding: '7px 14px', border: '1.5px solid #e2e8f0', borderRadius: 8, background: '#fff', cursor: 'pointer', fontSize: 13 },
  filterBtnActive: { background: '#58CC02', color: '#fff', border: '1.5px solid #58CC02' },
  btnPrimary: { padding: '8px 18px', background: '#58CC02', color: '#fff', border: 'none', borderRadius: 8, cursor: 'pointer', fontWeight: 600, fontSize: 14 },
  btnSecondary: { padding: '8px 14px', background: '#f1f5f9', color: '#334155', border: '1.5px solid #e2e8f0', borderRadius: 8, cursor: 'pointer', fontSize: 14 },
  btnSm: { padding: '6px 12px', background: '#f8fafc', color: '#475569', border: '1.5px solid #e2e8f0', borderRadius: 6, cursor: 'pointer', fontSize: 12, fontWeight: 500 },
  errorBox: { background: '#fee2e2', color: '#dc2626', padding: '10px 16px', borderRadius: 8, marginBottom: 12 },
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
  modal: { background: '#fff', borderRadius: 14, padding: '28px 32px', width: 640, maxWidth: '90vw', maxHeight: '90vh', overflowY: 'auto' },
  modalTitle: { margin: '0 0 20px', fontSize: 18, fontWeight: 700, color: '#1e293b' },
  modalActions: { display: 'flex', justifyContent: 'flex-end', gap: 12, marginTop: 24 },
  cancelBtn: { padding: '9px 20px', border: '1.5px solid #e2e8f0', borderRadius: 8, background: '#fff', cursor: 'pointer', fontWeight: 500 },
}
