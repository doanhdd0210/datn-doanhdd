import { useState, useEffect, useCallback, useRef } from 'react'
import Editor from '@monaco-editor/react'
import { Signal, Battery, RefreshCw, Upload, Download, FileDown, X, Pencil, Trash2, ChevronDown } from 'lucide-react'
import { lessonsApi, topicsApi } from '../services/api'

function renderLikeFlutter(content) {
  const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  const inline = text => esc(text)
    .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
    .replace(/`(.*?)`/g, '<code>$1</code>')

  const parts = []
  for (const para of content.split('\n\n')) {
    const t = para.trim()
    if (!t) continue
    if (t.startsWith('```')) {
      const lang = (t.match(/^```([a-zA-Z]*)/) || [])[1] || 'Java'
      const code = t.replace(/^```[a-z]*\n?/, '').replace(/```\s*$/, '').trim()
      parts.push(`<div class="cb"><div class="cbh"><span>${esc(lang || 'Java')}</span><button onclick="navigator.clipboard.writeText(this.closest('.cb').querySelector('pre').innerText).then(()=>{this.textContent='✓';setTimeout(()=>this.textContent='⧉',1200)})">⧉</button></div><pre>${esc(code)}</pre></div>`)
    } else if (t.startsWith('# ')) {
      parts.push(`<h1>${inline(t.substring(2))}</h1>`)
    } else if (t.startsWith('## ')) {
      parts.push(`<h2>${inline(t.substring(3))}</h2>`)
    } else if (t.split('\n').some(l => l.startsWith('- ') || l.startsWith('* '))) {
      const items = t.split('\n').filter(l => l.startsWith('- ') || l.startsWith('* '))
      parts.push(`<ul>${items.map(l => `<li>${inline(l.substring(2))}</li>`).join('')}</ul>`)
    } else {
      parts.push(`<p>${t.split('\n').map(inline).join('<br>')}</p>`)
    }
  }
  return parts.join('')
}

const MOBILE_CSS = `
  body{background:#181A20;color:#FAFAFA;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;padding:14px 16px;margin:0;font-size:14px;line-height:1.5}
  h1{font-size:18px;font-weight:700;margin:16px 0 8px}
  h2{font-size:16px;font-weight:700;margin:12px 0 6px}
  p{margin:4px 0}
  ul{list-style:none;padding:0;margin:0}
  li{display:flex;align-items:flex-start;padding:2px 0}
  li::before{content:'';display:inline-block;width:6px;height:6px;border-radius:50%;background:#304FFE;margin:7px 8px 0 0;flex-shrink:0}
  strong{font-weight:700}
  code{background:#35383F;padding:2px 5px;border-radius:4px;font-size:13px;font-family:monospace}
  .cb{background:#1E1E2E;border-radius:12px;margin:12px 0}
  .cbh{display:flex;justify-content:space-between;align-items:center;padding:8px 14px;background:#2D2D3F;border-radius:12px 12px 0 0}
  .cbh span{color:#4FC3F7;font-size:11px;font-weight:600}
  .cbh button{background:none;border:none;color:#666;cursor:pointer;font-size:14px;padding:0}
  pre{padding:14px;margin:0;font-family:monospace;font-size:13px;line-height:1.55;color:#fff;white-space:pre-wrap;overflow-x:auto}
`
function buildMobilePreviewDoc(content, title, summary, xpReward, topicTitle) {
  const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  const renderedContent = renderLikeFlutter(content)
  return `<!DOCTYPE html><html><head>
<meta charset="utf-8">
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{background:#181A20;color:#FAFAFA;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;font-size:10px;line-height:1.5;overflow-x:hidden;overflow-y:auto}
.appbar{padding:4px 10px 2px;background:#181A20}
.topic{color:#F5A623;font-size:8px;font-weight:600;display:flex;align-items:center;gap:3px}
.lesson-hdr{color:#FAFAFA;font-size:10px;font-weight:700;margin-top:2px;padding-left:14px}
.card{background:#1F222A;margin:6px 8px 8px;border-radius:11px;padding:9px}
.card-row{display:flex;align-items:center;gap:8px;margin-bottom:4px}
.card-icon{width:32px;height:32px;background:#2D3038;border-radius:8px;display:flex;align-items:center;justify-content:center;font-size:17px;flex-shrink:0}
.card-name{font-size:11px;font-weight:700;color:#FAFAFA;line-height:1.2}
.card-summary{font-size:8px;color:#9E9E9E;line-height:1.4;margin-bottom:6px}
.xp{display:inline-flex;align-items:center;gap:2px;background:#2D2415;color:#F5A623;font-size:8px;font-weight:700;padding:2px 7px;border-radius:12px}
.content{padding:3px 10px 60px}
h1{font-size:12px;font-weight:700;margin:9px 0 4px}
h2{font-size:11px;font-weight:700;margin:7px 0 3px}
p{margin:2px 0}
ul{list-style:none;padding:0;margin:2px 0}
li{display:flex;align-items:flex-start;padding:1px 0}
li::before{content:'';display:inline-block;width:4px;height:4px;border-radius:50%;background:#304FFE;margin:5px 5px 0 0;flex-shrink:0}
strong{font-weight:700}
code{background:#35383F;padding:1px 3px;border-radius:3px;font-size:8px;font-family:monospace}
.cb{background:#1E1E2E;border-radius:8px;margin:6px 0}
.cbh{display:flex;justify-content:space-between;align-items:center;padding:4px 9px;background:#2D2D3F;border-radius:8px 8px 0 0}
.cbh span{color:#4FC3F7;font-size:8px;font-weight:600}
.cbh button{background:none;border:none;color:#888;cursor:pointer;font-size:9px;padding:1px}
pre{padding:7px 9px;margin:0;font-family:monospace;font-size:8px;line-height:1.5;color:#fff;white-space:pre-wrap;overflow-x:auto}
.bottom-bar{position:fixed;bottom:0;left:0;right:0;background:linear-gradient(transparent,#181A20 30%);padding:6px 10px 8px}
.quiz-btn{background:#1a73e8;color:#fff;text-align:center;padding:8px;border-radius:9px;font-size:9px;font-weight:600}
</style></head><body>
<div class="appbar">
<div class="topic">← ${esc(topicTitle || 'Chủ đề')}</div>
<div class="lesson-hdr">${esc(title || 'Tiêu đề bài học')}</div>
</div>
<div class="card">
<div class="card-row"><div class="card-icon">☕</div><div class="card-name">${esc(title || 'Tiêu đề bài học')}</div></div>
<div class="card-summary">${esc(summary || 'Mô tả bài học...')}</div>
<div class="xp">⚡ ${esc(String(xpReward || 10))} XP</div>
</div>
<div class="content">${renderedContent}</div>
<div class="bottom-bar"><div class="quiz-btn">❓ Bắt đầu trắc nghiệm</div></div>
</body></html>`
}

import { exportLessonsExcel, importLessonsExcel, downloadLessonsSampleExcel } from '../utils/importExport'

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

export default function LessonsPage() {
  const [lessons, setLessons] = useState([])
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
  const [editorLang, setEditorLang] = useState('markdown')
  const importRef = useRef()

  const showToast = (msg, type = 'success') => {
    setToast({ msg, type })
    setTimeout(() => setToast({ msg: '', type: 'success' }), 2500)
  }

  const loadTopics = useCallback(async () => {
    try {
      const data = await topicsApi.list()
      setTopics(data ?? [])
    } catch { /* ignore */ }
  }, [])

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const data = await lessonsApi.list(topicFilter || undefined)
      setLessons(data ?? [])
    } catch (e) {
      setError(e.message)
    } finally {
      setLoading(false)
    }
  }, [topicFilter])

  useEffect(() => { loadTopics() }, [loadTopics])
  useEffect(() => { load() }, [load])

  const filtered = lessons.filter(l =>
    l.title?.toLowerCase().includes(search.toLowerCase()) ||
    l.summary?.toLowerCase().includes(search.toLowerCase())
  )

  const topicName = (id) => topics.find(t => t.id === id)?.title ?? id ?? '—'

  const defaultForm = { topicId: topicFilter || '', title: '', summary: '', content: '', xpReward: 10, estimatedMinutes: 5, order: 0, isActive: true }

  const openCreate = () => { setForm(defaultForm); setModal({ mode: 'create' }) }
  const openEdit = (l) => {
    setForm({ topicId: l.topicId ?? '', title: l.title ?? '', summary: l.summary ?? '', content: l.content ?? '', xpReward: l.xpReward ?? 10, estimatedMinutes: l.estimatedMinutes ?? 5, order: l.order ?? 0, isActive: l.isActive ?? true })
    setModal({ mode: 'edit', item: l })
  }
  const openDelete = (l) => setModal({ mode: 'delete', item: l })
  const closeModal = () => { setModal(null); setForm({}) }

  const handleSave = async () => {
    if (!form.title?.trim()) { alert('Tiêu đề không được để trống'); return }
    if (!form.topicId) { alert('Vui lòng chọn chủ đề'); return }
    setSaving(true)
    try {
      if (modal.mode === 'create') {
        await lessonsApi.create(form)
        showToast('Đã tạo bài học thành công')
      } else {
        await lessonsApi.update(modal.item.id, form)
        showToast('Đã cập nhật bài học')
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
      await lessonsApi.delete(modal.item.id)
      showToast('Đã xoá bài học')
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
      const data = await importLessonsExcel(file)
      for (let i = 0; i < data.length; i++) {
        setImportProgress(`Đang import ${i + 1}/${data.length}...`)
        await lessonsApi.create(data[i])
      }
      setImportProgress('')
      showToast(`Đã import ${data.length} mục thành công`)
      await load()
    } catch (e) {
      setImportProgress('')
      showToast('Lỗi: ' + e.message, 'error')
    }
  }

  return (
    <div>
      <Toast msg={toast.msg} type={toast.type} />

      {/* Toolbar */}
      <div style={s.toolbar}>
        <div style={{ position:'relative', display:'inline-flex', alignItems:'center' }}>
          <select value={topicFilter} onChange={e => setTopicFilter(e.target.value)} style={s.select}>
            <option value="">Tất cả chủ đề</option>
            {topics.map(t => <option key={t.id} value={t.id}>{t.icon} {t.title}</option>)}
          </select>
          <ChevronDown size={16} style={{ position:'absolute', right:10, pointerEvents:'none', color:'#64748b' }} />
        </div>
        <input
          placeholder="Tìm bài học..."
          value={search}
          onChange={e => setSearch(e.target.value)}
          style={s.searchInput}
        />
        <button onClick={load} style={s.btnSecondary}><RefreshCw size={14} style={{marginRight:5,verticalAlign:"middle"}}/> Làm mới</button>
        <button onClick={openCreate} style={s.btnPrimary}>+ Thêm bài học</button>
        <div style={s.btnGroup}>
          <button onClick={() => importRef.current?.click()} style={s.btnSm}><Upload size={14} style={{marginRight:5,verticalAlign:"middle"}}/> Import Excel</button>
          <button onClick={() => exportLessonsExcel(filtered, 'lessons_export.xlsx')} style={s.btnSm}><Download size={14} style={{marginRight:5,verticalAlign:"middle"}}/> Export Excel</button>
          <button onClick={downloadLessonsSampleExcel} style={{ ...s.btnSm, color: '#1a73e8', borderColor: '#93c5fd' }}><FileDown size={14} style={{marginRight:5,verticalAlign:"middle"}}/> Tải Excel mẫu</button>
        </div>
        <input type="file" accept=".xlsx,.xls" ref={importRef} style={{ display: 'none' }} onChange={handleImport} />
      </div>

      {importProgress && <div style={s.progressBox}>{importProgress}</div>}
      {error && <div style={s.errorBox}>{error}</div>}

      <div style={s.statsRow}>
        <span style={s.stat}>Tổng: <strong>{lessons.length}</strong></span>
        <span style={s.stat}>Hiển thị: <strong>{filtered.length}</strong></span>
      </div>

      {loading ? (
        <div style={s.loading}>⏳ Đang tải...</div>
      ) : filtered.length === 0 ? (
        <div style={s.empty}><div style={{ fontSize: 48 }}>📖</div><div style={{ color: '#94a3b8', marginTop: 8 }}>Chưa có bài học nào</div></div>
      ) : (
        <div style={s.tableWrap}>
          <table style={s.table}>
            <thead>
              <tr style={s.thead}>
                <th style={s.th}>#</th>
                <th style={s.th}>Chủ đề</th>
                <th style={s.th}>Tên bài học</th>
                <th style={s.th}>Tóm tắt</th>
                <th style={s.th}>XP</th>
                <th style={s.th}>Thứ tự</th>
                <th style={s.th}>Trạng thái</th>
                <th style={s.th}>Hành động</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((l, idx) => (
                <tr key={l.id} style={{ ...s.tr, background: idx % 2 === 0 ? '#fff' : '#f9f9f9' }}
                  onMouseEnter={e => e.currentTarget.style.background = '#f0f9eb'}
                  onMouseLeave={e => e.currentTarget.style.background = idx % 2 === 0 ? '#fff' : '#f9f9f9'}>
                  <td style={{ ...s.td, color: '#94a3b8', fontSize: 12 }}>{idx + 1}</td>
                  <td style={s.td}>
                    <span style={s.badge}>{topicName(l.topicId)}</span>
                  </td>
                  <td style={s.td}><strong style={{ color: '#1e293b' }}>{l.title}</strong></td>
                  <td style={{ ...s.td, color: '#64748b', maxWidth: 200 }}>
                    <span style={{ display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>
                      {l.summary || '—'}
                    </span>
                  </td>
                  <td style={{ ...s.td, textAlign: 'center' }}>
                    <span style={{ ...s.badge, background: '#fef9c3', color: '#854d0e' }}>⭐ {l.xpReward ?? 0}</span>
                  </td>
                  <td style={{ ...s.td, textAlign: 'center', color: '#64748b' }}>{l.order ?? 0}</td>
                  <td style={s.td}>
                    <span style={{ ...s.statusBadge, background: l.isActive ? '#dcfce7' : '#f1f5f9', color: l.isActive ? '#16a34a' : '#64748b' }}>
                      {l.isActive ? '✓ Hiện' : '— Ẩn'}
                    </span>
                  </td>
                  <td style={s.td}>
                    <div style={s.actions}>
                      <button onClick={() => openEdit(l)} style={s.btnEdit} title="Sửa"><Pencil size={14}/></button>
                      <button onClick={() => openDelete(l)} style={s.btnDelete} title="Xoá"><Trash2 size={14}/></button>
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
            <div style={s.modalHeader}>
              <h3 style={s.modalTitle}>{modal.mode === 'create' ? 'Thêm bài học mới' : `Sửa: ${modal.item?.title}`}</h3>
              <button onClick={closeModal} style={s.modalClose}><X size={16}/></button>
            </div>
            <div style={s.modalBody}>
              <label style={s.label}>Chủ đề *</label>
              <div style={s.selectWrap}>
                <select style={s.selectInput} value={form.topicId ?? ''} onChange={e => setForm({ ...form, topicId: e.target.value })}>
                  <option value="">-- Chọn chủ đề --</option>
                  {topics.map(t => <option key={t.id} value={t.id}>{t.icon} {t.title}</option>)}
                </select>
                <ChevronDown size={16} style={s.selectArrow} />
              </div>

              <label style={s.label}>Tiêu đề *</label>
              <input style={s.input} value={form.title ?? ''} onChange={e => setForm({ ...form, title: e.target.value })} placeholder="Tên bài học..." />

              <label style={s.label}>Tóm tắt</label>
              <textarea style={{ ...s.input, minHeight: 60, resize: 'vertical' }} value={form.summary ?? ''} onChange={e => setForm({ ...form, summary: e.target.value })} placeholder="Mô tả ngắn..." />

              <label style={s.label}>Nội dung (Markdown)</label>
              <div style={{ border: '1.5px solid #e2e8f0', borderRadius: 8, overflow: 'hidden' }}>
                <div style={{ display: 'flex', alignItems: 'center', background: '#f8fafc', borderBottom: '1px solid #e2e8f0', padding: '5px 10px', gap: 6 }}>
                  <span style={{ fontSize: 12, color: '#64748b', fontWeight: 500, marginRight: 4 }}>Chế độ:</span>
                  {[['markdown', 'MARKDOWN'], ['raw', 'RAW']].map(([lang, label]) => (
                    <button key={lang} type="button" onClick={() => setEditorLang(lang)} style={{
                      padding: '2px 10px', borderRadius: 6, border: 'none', cursor: 'pointer', fontSize: 12, fontWeight: 500,
                      background: editorLang === lang ? '#1a73e8' : '#e2e8f0',
                      color: editorLang === lang ? '#fff' : '#64748b',
                    }}>{label}</button>
                  ))}
                  <span style={{ marginLeft: 'auto', fontSize: 11, color: '#94a3b8' }}>Editor · Preview</span>
                </div>
                <div style={{ display: 'flex', height: 480 }}>
                  <div style={{ flex: 1, overflow: 'hidden', borderRight: '1px solid #e2e8f0' }}>
                    <Editor
                      height="100%"
                      language="markdown"
                      value={form.content ?? ''}
                      onChange={val => setForm(f => ({ ...f, content: val ?? '' }))}
                      options={{
                        minimap: { enabled: false },
                        fontSize: 13,
                        lineNumbers: 'on',
                        wordWrap: 'on',
                        scrollBeyondLastLine: false,
                        padding: { top: 8 },
                      }}
                    />
                  </div>
                  <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden', background: editorLang === 'raw' ? '#1e1e1e' : '#dce1e9' }}>
                    <div style={{ padding: '3px 10px', background: editorLang === 'raw' ? '#252526' : '#c5ccd8', borderBottom: `1px solid ${editorLang === 'raw' ? '#333' : '#b0b8c8'}`, fontSize: 10, color: editorLang === 'raw' ? '#888' : '#555', fontWeight: 700, letterSpacing: 1 }}>
                      {editorLang === 'raw' ? 'RAW TEXT' : 'MOBILE PREVIEW'}
                    </div>
                    {editorLang === 'raw' ? (
                      <div style={{ flex: 1, overflow: 'auto', padding: 14, fontFamily: 'monospace', fontSize: 12, color: '#d4d4d4', lineHeight: 1.6, whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>
                        {form.content ?? ''}
                      </div>
                    ) : (
                      <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '8px 12px', overflow: 'hidden' }}>
                        {/* Phone mockup frame */}
                        <div style={{
                          display: 'flex', flexDirection: 'column',
                          background: '#18181e',
                          borderRadius: 36,
                          padding: '6px 5px 4px',
                          boxShadow: '0 0 0 1px #3a3a4e, 0 0 0 5px #202028, 0 20px 60px rgba(0,0,0,0.6), inset 0 1px 0 rgba(255,255,255,0.07)',
                          flexShrink: 0,
                          height: 456,
                          width: 222,
                        }}>
                          <div style={{ flex: 1, borderRadius: 28, overflow: 'hidden', display: 'flex', flexDirection: 'column', background: '#181A20' }}>
                            {/* Status bar */}
                            <div style={{ height: 22, flexShrink: 0, background: '#181A20', display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 14px', position: 'relative' }}>
                              <div style={{ position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%,-50%)', width: 16, height: 6, background: '#18181e', borderRadius: 3 }} />
                              <span style={{ fontSize: 9, fontWeight: 700, color: '#fff', zIndex: 1 }}>6:28</span>
                              <div style={{ display: 'flex', gap: 3, alignItems: 'center', zIndex: 1 }}>
                                <span style={{ fontSize: 8, color: '#fff', fontWeight: 700 }}>G</span>
                                <Signal size={10} color="#fff" />
                                <Battery size={14} color="#fff" />
                              </div>
                            </div>
                            {/* Content iframe */}
                            <iframe
                              srcDoc={buildMobilePreviewDoc(form.content ?? '', form.title ?? '', form.summary ?? '', form.xpReward ?? 10, topicName(form.topicId))}
                              style={{ flex: 1, border: 'none', width: '100%', display: 'block' }}
                              title="Mobile Preview"
                              sandbox="allow-same-origin allow-scripts"
                            />
                          </div>
                          {/* Home indicator */}
                          <div style={{ height: 12, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                            <div style={{ width: 48, height: 3.5, background: '#3a3a4e', borderRadius: 2 }} />
                          </div>
                        </div>
                      </div>
                    )}
                  </div>
                </div>
              </div>

              {(
                <div style={{ background: '#f0f7ff', border: '1px solid #bfdbfe', borderRadius: 8, padding: '10px 14px', fontSize: 12, color: '#1e40af' }}>
                  <div style={{ fontWeight: 700, marginBottom: 8 }}>📝 Cú pháp Markdown được hỗ trợ trên mobile:</div>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '4px 20px', fontFamily: 'monospace' }}>
                    {[
                      ['# Tiêu đề lớn', 'Heading cỡ lớn (18px)'],
                      ['## Tiêu đề nhỏ', 'Heading cỡ nhỏ (16px)'],
                      ['**in đậm**', 'Chữ in đậm'],
                      ['`inline code`', 'Code nội tuyến'],
                      ['- mục 1', 'Danh sách bullet'],
                      ['```java\\ncode\\n```', 'Khối code (có nút copy)'],
                    ].map(([syntax, desc]) => (
                      <div key={syntax} style={{ display: 'flex', gap: 8, alignItems: 'baseline' }}>
                        <span style={{ color: '#1d4ed8', minWidth: 150, flexShrink: 0 }}>{syntax}</span>
                        <span style={{ color: '#64748b', fontFamily: 'sans-serif' }}>→ {desc}</span>
                      </div>
                    ))}
                  </div>
                  <div style={{ marginTop: 8, color: '#64748b', fontFamily: 'sans-serif' }}>
                    ⚠️ <strong>Không hỗ trợ:</strong> ### heading, bảng <code>|col|</code> — sẽ hiển thị dạng text thô.
                  </div>
                </div>
              )}

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
            </div>
            <div style={s.modalFooter}>
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
            <div style={s.modalHeader}>
              <h3 style={s.modalTitle}>Xoá bài học</h3>
              <button onClick={closeModal} style={s.modalClose}><X size={16}/></button>
            </div>
            <div style={s.modalBody}>
              <p style={{ color: '#6b7280', marginBottom: 8 }}>Bạn chắc chắn muốn xoá <strong>{modal.item?.title}</strong>?</p>
              <p style={{ color: '#ef4444', fontSize: 13, margin: 0 }}>Hành động này không thể hoàn tác.</p>
            </div>
            <div style={s.modalFooter}>
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
  select: { padding: '8px 36px 8px 12px', border: '1.5px solid #e2e8f0', borderRadius: 8, fontSize: 14, outline: 'none', background: '#fff', cursor: 'pointer', minWidth: 160, appearance: 'none', WebkitAppearance: 'none' },
  btnPrimary: { padding: '8px 18px', background: '#1a73e8', color: '#fff', border: 'none', borderRadius: 8, cursor: 'pointer', fontWeight: 600, fontSize: 14 },
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
  modal: { background: '#fff', borderRadius: 14, width: 1000, maxWidth: '95vw', maxHeight: '92vh', display: 'flex', flexDirection: 'column', overflow: 'hidden' },
  modalHeader: { padding: '18px 24px', borderBottom: '1px solid #e2e8f0', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexShrink: 0 },
  modalTitle: { margin: 0, fontSize: 18, fontWeight: 700, color: '#1e293b' },
  modalBody: { padding: '20px 24px', overflowY: 'auto', flex: 1 },
  modalFooter: { padding: '14px 24px', borderTop: '1px solid #e2e8f0', display: 'flex', justifyContent: 'flex-end', gap: 12, flexShrink: 0 },
  modalClose: { background: 'none', border: 'none', cursor: 'pointer', fontSize: 20, color: '#94a3b8', padding: '2px 4px', lineHeight: 1, borderRadius: 4 },
  label: { display: 'block', fontSize: 13, fontWeight: 500, color: '#374151', marginBottom: 4, marginTop: 12 },
  input: { width: '100%', padding: '9px 12px', border: '1.5px solid #e2e8f0', borderRadius: 8, fontSize: 14, outline: 'none', boxSizing: 'border-box' },
  selectWrap: { position: 'relative', display: 'inline-flex', alignItems: 'center', width: '100%' },
  selectInput: { width: '100%', padding: '9px 36px 9px 12px', border: '1.5px solid #e2e8f0', borderRadius: 8, fontSize: 14, outline: 'none', boxSizing: 'border-box', appearance: 'none', WebkitAppearance: 'none', background: '#fff', cursor: 'pointer' },
  selectArrow: { position: 'absolute', right: 12, pointerEvents: 'none', color: '#64748b' },
  checkboxRow: { display: 'flex', alignItems: 'center', marginTop: 16, fontSize: 14, cursor: 'pointer' },
  cancelBtn: { padding: '9px 20px', border: '1.5px solid #e2e8f0', borderRadius: 8, background: '#fff', cursor: 'pointer', fontWeight: 500 },
}
