import { useState, useEffect, useCallback, useRef } from 'react'
import { codeSnippetsApi, topicsApi } from '../services/api'
import { exportJson, exportCsv, importJson } from '../utils/importExport'

const LANGUAGES = ['java', 'python', 'javascript', 'kotlin', 'cpp', 'c', 'typescript']

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

export default function CodeSnippetsPage() {
  const [snippets, setSnippets] = useState([])
  const [topics, setTopics] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')
  const [topicFilter, setTopicFilter] = useState('')
  const [modal, setModal] = useState(null)
  const [saving, setSaving] = useState(false)
  const [form, setForm] = useState({})
  const [toast, setToast] = useState({ msg: '', type: 'success' })
  const [importProgress, setImportProgress] = useState('')
  const [runOutput, setRunOutput] = useState('')
  const [running, setRunning] = useState(false)
  const importRef = useRef()

  const showToast = (msg, type = 'success') => {
    setToast({ msg, type })
    setTimeout(() => setToast({ msg: '', type: 'success' }), 2500)
  }

  const loadTopics = useCallback(async () => {
    try { setTopics((await topicsApi.list()) ?? []) } catch { /* ignore */ }
  }, [])

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const data = await codeSnippetsApi.list(topicFilter || undefined)
      setSnippets(data ?? [])
    } catch (e) {
      setError(e.message)
    } finally {
      setLoading(false)
    }
  }, [topicFilter])

  useEffect(() => { loadTopics() }, [loadTopics])
  useEffect(() => { load() }, [load])

  const filtered = snippets.filter(s =>
    s.title?.toLowerCase().includes(search.toLowerCase()) ||
    s.description?.toLowerCase().includes(search.toLowerCase())
  )

  const topicName = (id) => topics.find(t => t.id === id)?.title ?? id ?? '—'

  const defaultForm = { topicId: topicFilter || '', title: '', description: '', language: 'java', code: '', expectedOutput: '', xpReward: 10, order: 0, isActive: true }

  const openCreate = () => { setForm(defaultForm); setRunOutput(''); setModal({ mode: 'create' }) }
  const openEdit = (s) => {
    setForm({ topicId: s.topicId ?? '', title: s.title ?? '', description: s.description ?? '', language: s.language ?? 'java', code: s.code ?? '', expectedOutput: s.expectedOutput ?? '', xpReward: s.xpReward ?? 10, order: s.order ?? 0, isActive: s.isActive ?? true })
    setRunOutput('')
    setModal({ mode: 'edit', item: s })
  }
  const openDelete = (s) => setModal({ mode: 'delete', item: s })
  const closeModal = () => { setModal(null); setForm({}); setRunOutput('') }

  const handleSave = async () => {
    if (!form.title?.trim()) { alert('Tiêu đề không được để trống'); return }
    if (!form.topicId) { alert('Vui lòng chọn chủ đề'); return }
    setSaving(true)
    try {
      if (modal.mode === 'create') {
        await codeSnippetsApi.create(form)
        showToast('Đã tạo code snippet thành công')
      } else {
        await codeSnippetsApi.update(modal.item.id, form)
        showToast('Đã cập nhật code snippet')
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
      await codeSnippetsApi.delete(modal.item.id)
      showToast('Đã xoá code snippet')
      await load()
      closeModal()
    } catch (e) {
      alert('Lỗi: ' + e.message)
    } finally {
      setSaving(false)
    }
  }

  const handleTestRun = async () => {
    if (!form.code?.trim()) { setRunOutput('// Không có code để chạy'); return }
    setRunning(true)
    setRunOutput('⏳ Đang chạy...')
    try {
      const res = await fetch('https://emkc.org/api/v2/piston/execute', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ language: form.language || 'java', version: '*', files: [{ content: form.code }] }),
      })
      const data = await res.json()
      const out = data.run?.output || data.run?.stderr || data.compile?.stderr || '(không có output)'
      setRunOutput(out)
    } catch (e) {
      setRunOutput('Lỗi kết nối: ' + e.message)
    } finally {
      setRunning(false)
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
        await codeSnippetsApi.create(data[i])
      }
      setImportProgress('')
      showToast(`Đã import ${data.length} mục thành công`)
      await load()
    } catch (e) {
      setImportProgress('')
      showToast('Lỗi: ' + e.message, 'error')
    }
  }

  const handleExportJson = () => exportJson(filtered, 'code_snippets_export.json')
  const handleExportCsv = () => {
    const rows = filtered.map(s => ({ id: s.id, topicId: s.topicId, title: s.title, description: s.description, language: s.language, xpReward: s.xpReward, order: s.order, isActive: s.isActive }))
    exportCsv(rows, ['id', 'topicId', 'title', 'description', 'language', 'xpReward', 'order', 'isActive'], 'code_snippets.csv')
  }

  const langBadgeColor = (lang) => {
    const m = { java: '#e8f0fe', python: '#fef9c3', javascript: '#fef3c7', kotlin: '#f3e8ff', cpp: '#fee2e2', c: '#fee2e2', typescript: '#dbeafe' }
    return m[lang] || '#f1f5f9'
  }

  return (
    <div>
      <Toast msg={toast.msg} type={toast.type} />

      {/* Toolbar */}
      <div style={s.toolbar}>
        <select value={topicFilter} onChange={e => setTopicFilter(e.target.value)} style={s.select}>
          <option value="">Tất cả chủ đề</option>
          {topics.map(t => <option key={t.id} value={t.id}>{t.icon} {t.title}</option>)}
        </select>
        <input placeholder="Tìm code snippet..." value={search} onChange={e => setSearch(e.target.value)} style={s.searchInput} />
        <button onClick={load} style={s.btnSecondary}>⟳ Làm mới</button>
        <button onClick={openCreate} style={s.btnPrimary}>+ Thêm snippet</button>
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
        <span style={s.stat}>Tổng: <strong>{snippets.length}</strong></span>
        <span style={s.stat}>Hiển thị: <strong>{filtered.length}</strong></span>
      </div>

      {loading ? (
        <div style={s.loading}>⏳ Đang tải...</div>
      ) : filtered.length === 0 ? (
        <div style={s.empty}><div style={{ fontSize: 48 }}>💻</div><div style={{ color: '#94a3b8', marginTop: 8 }}>Chưa có code snippet nào</div></div>
      ) : (
        <div style={s.tableWrap}>
          <table style={s.table}>
            <thead>
              <tr style={s.thead}>
                <th style={s.th}>Chủ đề</th>
                <th style={s.th}>Tiêu đề</th>
                <th style={s.th}>Ngôn ngữ</th>
                <th style={s.th}>Mô tả</th>
                <th style={s.th}>Code preview</th>
                <th style={s.th}>XP</th>
                <th style={s.th}>Thứ tự</th>
                <th style={s.th}>Trạng thái</th>
                <th style={s.th}>Hành động</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((sn, idx) => (
                <tr key={sn.id} style={{ ...s.tr, background: idx % 2 === 0 ? '#fff' : '#f9f9f9' }}
                  onMouseEnter={e => e.currentTarget.style.background = '#f0f9eb'}
                  onMouseLeave={e => e.currentTarget.style.background = idx % 2 === 0 ? '#fff' : '#f9f9f9'}>
                  <td style={s.td}><span style={s.badge}>{topicName(sn.topicId)}</span></td>
                  <td style={s.td}><strong>{sn.title}</strong></td>
                  <td style={s.td}>
                    <span style={{ ...s.badge, background: langBadgeColor(sn.language), color: '#374151' }}>{sn.language || 'java'}</span>
                  </td>
                  <td style={{ ...s.td, color: '#64748b', maxWidth: 160 }}>
                    <span style={{ display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>
                      {sn.description || '—'}
                    </span>
                  </td>
                  <td style={s.td}>
                    <pre style={{ margin: 0, fontSize: 11, fontFamily: 'monospace', color: '#475569', background: '#f8fafc', padding: '4px 8px', borderRadius: 4, maxWidth: 200, overflow: 'hidden', whiteSpace: 'pre-wrap', wordBreak: 'break-all' }}>
                      {(sn.code || '').slice(0, 100)}{sn.code?.length > 100 ? '...' : ''}
                    </pre>
                  </td>
                  <td style={{ ...s.td, textAlign: 'center' }}>
                    <span style={{ ...s.badge, background: '#fef9c3', color: '#854d0e' }}>⭐ {sn.xpReward ?? 0}</span>
                  </td>
                  <td style={{ ...s.td, textAlign: 'center', color: '#64748b' }}>{sn.order ?? 0}</td>
                  <td style={s.td}>
                    <span style={{ ...s.statusBadge, background: sn.isActive ? '#dcfce7' : '#f1f5f9', color: sn.isActive ? '#16a34a' : '#64748b' }}>
                      {sn.isActive ? '✓ Hiện' : '— Ẩn'}
                    </span>
                  </td>
                  <td style={s.td}>
                    <div style={s.actions}>
                      <button onClick={() => openEdit(sn)} style={s.btnEdit} title="Sửa">✏️</button>
                      <button onClick={() => openDelete(sn)} style={s.btnDelete} title="Xoá">🗑️</button>
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
            <h3 style={s.modalTitle}>{modal.mode === 'create' ? 'Thêm Code Snippet' : `Sửa: ${modal.item?.title}`}</h3>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div>
                <label style={s.label}>Chủ đề *</label>
                <select style={s.input} value={form.topicId ?? ''} onChange={e => setForm({ ...form, topicId: e.target.value })}>
                  <option value="">-- Chọn chủ đề --</option>
                  {topics.map(t => <option key={t.id} value={t.id}>{t.icon} {t.title}</option>)}
                </select>
              </div>
              <div>
                <label style={s.label}>Ngôn ngữ</label>
                <select style={s.input} value={form.language ?? 'java'} onChange={e => setForm({ ...form, language: e.target.value })}>
                  {LANGUAGES.map(l => <option key={l} value={l}>{l}</option>)}
                </select>
              </div>
            </div>

            <label style={s.label}>Tiêu đề *</label>
            <input style={s.input} value={form.title ?? ''} onChange={e => setForm({ ...form, title: e.target.value })} placeholder="Tên snippet..." />

            <label style={s.label}>Mô tả</label>
            <textarea style={{ ...s.input, minHeight: 60, resize: 'vertical' }} value={form.description ?? ''} onChange={e => setForm({ ...form, description: e.target.value })} placeholder="Mô tả ngắn..." />

            <label style={s.label}>Code</label>
            <textarea style={{ ...s.input, minHeight: 200, resize: 'vertical', fontFamily: 'monospace', fontSize: 13 }} value={form.code ?? ''} onChange={e => setForm({ ...form, code: e.target.value })} placeholder="// Nhập code ở đây..." spellCheck={false} />

            <button
              onClick={handleTestRun}
              disabled={running}
              style={{ marginTop: 8, padding: '7px 16px', background: '#1e293b', color: '#fff', border: 'none', borderRadius: 6, cursor: running ? 'wait' : 'pointer', fontSize: 13, fontWeight: 600 }}
            >
              {running ? '⏳ Đang chạy...' : '▶ Test Run'}
            </button>

            {runOutput && (
              <pre style={{ marginTop: 8, background: '#0f172a', color: '#e2e8f0', padding: '12px 16px', borderRadius: 8, fontSize: 12, fontFamily: 'monospace', whiteSpace: 'pre-wrap', wordBreak: 'break-all', maxHeight: 160, overflowY: 'auto' }}>
                {runOutput}
              </pre>
            )}

            <label style={s.label}>Expected Output</label>
            <textarea style={{ ...s.input, minHeight: 60, resize: 'vertical', fontFamily: 'monospace', fontSize: 13 }} value={form.expectedOutput ?? ''} onChange={e => setForm({ ...form, expectedOutput: e.target.value })} placeholder="Kết quả mong đợi khi chạy code..." />

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div>
                <label style={s.label}>XP Reward</label>
                <input style={s.input} type="number" value={form.xpReward ?? 10} onChange={e => setForm({ ...form, xpReward: Number(e.target.value) })} />
              </div>
              <div>
                <label style={s.label}>Thứ tự</label>
                <input style={s.input} type="number" value={form.order ?? 0} onChange={e => setForm({ ...form, order: Number(e.target.value) })} />
              </div>
            </div>

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
          <div style={{ ...s.modal, maxWidth: 400 }}>
            <h3 style={s.modalTitle}>Xoá Code Snippet</h3>
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
  select: { padding: '8px 12px', border: '1.5px solid #e2e8f0', borderRadius: 8, fontSize: 14, outline: 'none', background: '#fff', cursor: 'pointer', minWidth: 160 },
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
  td: { padding: '10px 14px', verticalAlign: 'middle' },
  badge: { display: 'inline-block', padding: '2px 10px', borderRadius: 99, background: '#f1f5f9', color: '#475569', fontSize: 12, fontWeight: 500 },
  statusBadge: { display: 'inline-block', padding: '3px 10px', borderRadius: 99, fontSize: 12, fontWeight: 600 },
  actions: { display: 'flex', gap: 6 },
  btnEdit: { padding: '4px 10px', background: '#e0f2fe', border: 'none', borderRadius: 6, cursor: 'pointer', fontSize: 14 },
  btnDelete: { padding: '4px 10px', background: '#fee2e2', border: 'none', borderRadius: 6, cursor: 'pointer', fontSize: 14 },
  overlay: { position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.45)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 200 },
  modal: { background: '#fff', borderRadius: 14, padding: '28px 32px', width: 640, maxWidth: '90vw', maxHeight: '90vh', overflowY: 'auto' },
  modalTitle: { margin: '0 0 20px', fontSize: 18, fontWeight: 700, color: '#1e293b' },
  label: { display: 'block', fontSize: 13, fontWeight: 500, color: '#374151', marginBottom: 4, marginTop: 12 },
  input: { width: '100%', padding: '9px 12px', border: '1.5px solid #e2e8f0', borderRadius: 8, fontSize: 14, outline: 'none', boxSizing: 'border-box' },
  checkboxRow: { display: 'flex', alignItems: 'center', marginTop: 16, fontSize: 14, cursor: 'pointer' },
  modalActions: { display: 'flex', justifyContent: 'flex-end', gap: 12, marginTop: 24 },
  cancelBtn: { padding: '9px 20px', border: '1.5px solid #e2e8f0', borderRadius: 8, background: '#fff', cursor: 'pointer', fontWeight: 500 },
}
