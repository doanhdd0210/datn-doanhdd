import { useState, useEffect, useCallback, useRef } from 'react'
import { RefreshCw, Upload, Download, FileDown, X, Pencil, Trash2, ChevronDown } from 'lucide-react'
import { questionsApi, topicsApi, lessonsApi } from '../services/api'
import { exportQuestionsExcel, importQuestionsExcel, downloadQuestionsSampleExcel } from '../utils/importExport'

const ANSWER_LABELS = ['A', 'B', 'C', 'D']

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

export default function QuestionsPage() {
  const [topics, setTopics] = useState([])
  const [lessons, setLessons] = useState([])
  const [questions, setQuestions] = useState([])
  const [selectedTopic, setSelectedTopic] = useState('')
  const [selectedLesson, setSelectedLesson] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [modal, setModal] = useState(null)
  const [saving, setSaving] = useState(false)
  const [form, setForm] = useState({})
  const [toast, setToast] = useState({ msg: '', type: 'success' })
  const [importProgress, setImportProgress] = useState('')
  const [dateSortDir, setDateSortDir] = useState('desc')
  const importRef = useRef()

  const showToast = (msg, type = 'success') => {
    setToast({ msg, type })
    setTimeout(() => setToast({ msg: '', type: 'success' }), 2500)
  }

  // Load topics on mount
  useEffect(() => {
    topicsApi.list().then(d => setTopics(d ?? [])).catch(() => {})
  }, [])

  // Load lessons when topic changes
  useEffect(() => {
    if (!selectedTopic) { setLessons([]); setSelectedLesson(''); return }
    lessonsApi.list(selectedTopic).then(d => setLessons(d ?? [])).catch(() => {})
    setSelectedLesson('')
  }, [selectedTopic])

  // Load questions when lesson changes (empty lessonId = load all)
  const loadQuestions = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const data = await questionsApi.list(selectedLesson)
      setQuestions(data ?? [])
    } catch (e) {
      setError(e.message)
    } finally {
      setLoading(false)
    }
  }, [selectedLesson])

  useEffect(() => { loadQuestions() }, [loadQuestions])

  const sortedQuestions = [...questions].sort((a, b) => {
    const ta = new Date(a.createdAt ?? 0).getTime()
    const tb = new Date(b.createdAt ?? 0).getTime()
    return dateSortDir === 'desc' ? tb - ta : ta - tb
  })

  const formatDate = (d) => {
    if (!d) return '—'
    try { return new Date(d).toLocaleDateString('vi-VN', { day: '2-digit', month: '2-digit', year: 'numeric' }) }
    catch { return d }
  }

  const defaultForm = { lessonId: selectedLesson, questionText: '', options: ['', '', '', ''], correctAnswerIndex: 0, explanation: '', points: 10, order: 0 }

  const openCreate = () => { setForm({ ...defaultForm, lessonId: selectedLesson }); setModal({ mode: 'create' }) }
  const openEdit = (q) => {
    setForm({
      lessonId: q.lessonId ?? selectedLesson,
      questionText: q.questionText ?? '',
      options: q.options ?? ['', '', '', ''],
      correctAnswerIndex: q.correctAnswerIndex ?? 0,
      explanation: q.explanation ?? '',
      points: q.points ?? 10,
      order: q.order ?? 0,
    })
    setModal({ mode: 'edit', item: q })
  }
  const openDelete = (q) => setModal({ mode: 'delete', item: q })
  const closeModal = () => { setModal(null); setForm({}) }

  const handleSave = async () => {
    if (!form.questionText?.trim()) { alert('Câu hỏi không được để trống'); return }
    if (!form.lessonId) { alert('Vui lòng chọn bài học'); return }
    const opts = form.options ?? []
    if (opts.filter(o => o.trim()).length < 2) { alert('Cần ít nhất 2 đáp án'); return }
    setSaving(true)
    try {
      if (modal.mode === 'create') {
        await questionsApi.create(form)
        showToast('Đã tạo câu hỏi thành công')
      } else {
        await questionsApi.update(modal.item.id, form)
        showToast('Đã cập nhật câu hỏi')
      }
      await loadQuestions()
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
      await questionsApi.delete(modal.item.id)
      showToast('Đã xoá câu hỏi')
      await loadQuestions()
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
      const data = await importQuestionsExcel(file, selectedLesson)
      for (let i = 0; i < data.length; i++) {
        setImportProgress(`Đang import ${i + 1}/${data.length}...`)
        await questionsApi.create(data[i])
      }
      setImportProgress('')
      showToast(`Đã import ${data.length} câu hỏi thành công`)
      await loadQuestions()
    } catch (e) {
      setImportProgress('')
      showToast('Lỗi: ' + e.message, 'error')
    }
  }

  const setOption = (idx, val) => {
    const opts = [...(form.options ?? ['', '', '', ''])]
    opts[idx] = val
    setForm({ ...form, options: opts })
  }

  const selectedLessonName = lessons.find(l => l.id === selectedLesson)?.title ?? ''

  return (
    <div>
      <Toast msg={toast.msg} type={toast.type} />

      {/* Two-level selector */}
      <div style={s.selectorBar}>
        <div style={s.selectorItem}>
          <label style={s.selectorLabel}>Chủ đề</label>
          <div style={s.selectWrap}>
            <select style={s.select} value={selectedTopic} onChange={e => setSelectedTopic(e.target.value)}>
              <option value="">-- Chọn chủ đề --</option>
              {topics.map(t => <option key={t.id} value={t.id}>{t.icon} {t.title}</option>)}
            </select>
            <ChevronDown size={16} style={s.selectArrow} />
          </div>
        </div>
        <div style={{ color: '#94a3b8', alignSelf: 'flex-end', paddingBottom: 8 }}>›</div>
        <div style={s.selectorItem}>
          <label style={s.selectorLabel}>Bài học</label>
          <div style={s.selectWrap}>
            <select style={s.select} value={selectedLesson} onChange={e => setSelectedLesson(e.target.value)} disabled={!selectedTopic}>
              <option value="">-- Chọn bài học --</option>
              {lessons.map(l => <option key={l.id} value={l.id}>{l.title}</option>)}
            </select>
            <ChevronDown size={16} style={{ ...s.selectArrow, color: selectedTopic ? '#64748b' : '#cbd5e1' }} />
          </div>
        </div>
        <div style={{ alignSelf: 'flex-end', paddingBottom: 4 }}>
          <span style={{ ...s.badge, background: '#dbeafe', color: '#1d4ed8' }}>
            {questions.length} câu hỏi
          </span>
        </div>
      </div>

      {/* Toolbar */}
      <div style={s.toolbar}>
        <button onClick={loadQuestions} style={s.btnSecondary}><RefreshCw size={14} style={{marginRight:5,verticalAlign:"middle"}}/> Làm mới</button>
        <button onClick={openCreate} style={s.btnPrimary} disabled={!selectedLesson}>+ Thêm câu hỏi</button>
        <div style={s.btnGroup}>
          <button onClick={() => importRef.current?.click()} style={s.btnSm}><Upload size={14} style={{marginRight:5,verticalAlign:"middle"}}/> Import Excel</button>
          <button onClick={() => exportQuestionsExcel(questions, `questions_lesson_${selectedLesson}.xlsx`)} style={s.btnSm} disabled={!selectedLesson}><Download size={14} style={{marginRight:5,verticalAlign:"middle"}}/> Export Excel</button>
          <button onClick={downloadQuestionsSampleExcel} style={{ ...s.btnSm, color: '#1a73e8', borderColor: '#93c5fd' }}><FileDown size={14} style={{marginRight:5,verticalAlign:"middle"}}/> Tải Excel mẫu</button>
        </div>
        <input type="file" accept=".xlsx,.xls" ref={importRef} style={{ display: 'none' }} onChange={handleImport} />
      </div>

      {importProgress && <div style={s.progressBox}>{importProgress}</div>}
      {error && <div style={s.errorBox}>{error}</div>}

      {loading ? (
        <div style={s.loading}>⏳ Đang tải...</div>
      ) : questions.length === 0 ? (
        <div style={s.empty}><div style={{ fontSize: 48 }}>❓</div><div style={{ color: '#94a3b8', marginTop: 8 }}>Chưa có câu hỏi nào</div></div>
      ) : (
        <div style={s.tableWrap}>
          <table style={s.table}>
            <thead>
              <tr style={s.thead}>
                <th style={s.th}>#</th>
                <th style={s.th}>ID</th>
                <th style={s.th}>Câu hỏi</th>
                <th style={s.th}>Đáp án A</th>
                <th style={s.th}>Đáp án B</th>
                <th style={s.th}>Đáp án C</th>
                <th style={s.th}>Đáp án D</th>
                <th style={s.th}>Đúng</th>
                <th style={s.th}>Điểm</th>
                <th style={s.th}>Thứ tự</th>
                <th style={{ ...s.th, cursor: 'pointer', userSelect: 'none' }} onClick={() => setDateSortDir(d => d === 'desc' ? 'asc' : 'desc')}>
                  Ngày tạo {dateSortDir === 'desc' ? '↓' : '↑'}
                </th>
                <th style={s.th}>Hành động</th>
              </tr>
            </thead>
            <tbody>
              {sortedQuestions.map((q, idx) => (
                <tr key={q.id} style={{ ...s.tr, background: idx % 2 === 0 ? '#fff' : '#f9f9f9' }}
                  onMouseEnter={e => e.currentTarget.style.background = '#f0f9eb'}
                  onMouseLeave={e => e.currentTarget.style.background = idx % 2 === 0 ? '#fff' : '#f9f9f9'}>
                  <td style={{ ...s.td, color: '#94a3b8', fontSize: 12 }}>{idx + 1}</td>
                  <td style={{ ...s.td, fontSize: 11, color: '#94a3b8', fontFamily: 'monospace', maxWidth: 80, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }} title={q.id}>{q.id}</td>
                  <td style={{ ...s.td, maxWidth: 180 }}>
                    <span style={{ display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>
                      {q.questionText}
                    </span>
                  </td>
                  {[0, 1, 2, 3].map(i => (
                    <td key={i} style={{ ...s.td, fontSize: 12, color: q.correctAnswerIndex === i ? '#16a34a' : '#64748b' }}>
                      {q.correctAnswerIndex === i ? <strong>{q.options?.[i]}</strong> : q.options?.[i] || '—'}
                    </td>
                  ))}
                  <td style={s.td}>
                    <span style={{ background: '#dcfce7', color: '#16a34a', borderRadius: 99, padding: '2px 10px', fontSize: 12, fontWeight: 700 }}>
                      ✓ {ANSWER_LABELS[q.correctAnswerIndex ?? 0]}
                    </span>
                  </td>
                  <td style={{ ...s.td, textAlign: 'center', color: '#64748b' }}>{q.points ?? 10}</td>
                  <td style={{ ...s.td, textAlign: 'center', color: '#64748b' }}>{q.order ?? 0}</td>
                  <td style={{ ...s.td, fontSize: 12, color: '#64748b' }}>{formatDate(q.createdAt)}</td>
                  <td style={s.td}>
                    <div style={s.actions}>
                      <button onClick={() => openEdit(q)} style={s.btnEdit} title="Sửa"><Pencil size={14}/></button>
                      <button onClick={() => openDelete(q)} style={s.btnDelete} title="Xoá"><Trash2 size={14}/></button>
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
              <h3 style={s.modalTitle}>{modal.mode === 'create' ? 'Thêm câu hỏi mới' : 'Sửa câu hỏi'}</h3>
              <button onClick={closeModal} style={s.modalClose}><X size={16}/></button>
            </div>
            <div style={s.modalBody}>
              <label style={s.label}>Bài học</label>
              <div style={{ ...s.selectWrap, width: '100%' }}>
                <select style={{ ...s.select, minWidth: 'unset', width: '100%', padding: '9px 36px 9px 12px' }} value={form.lessonId ?? ''} onChange={e => setForm({ ...form, lessonId: e.target.value })}>
                  <option value="">-- Chọn bài học --</option>
                  {lessons.map(l => <option key={l.id} value={l.id}>{l.title}</option>)}
                </select>
                <ChevronDown size={16} style={s.selectArrow} />
              </div>

              <label style={s.label}>Câu hỏi *</label>
              <textarea style={{ ...s.input, minHeight: 80, resize: 'vertical' }} value={form.questionText ?? ''} onChange={e => setForm({ ...form, questionText: e.target.value })} placeholder="Nội dung câu hỏi..." />

              <label style={s.label}>Các đáp án</label>
              {ANSWER_LABELS.map((lbl, i) => (
                <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
                  <span style={{ fontWeight: 700, color: '#475569', width: 20 }}>{lbl}.</span>
                  <input
                    style={{ ...s.input, flex: 1 }}
                    value={(form.options ?? [])[i] ?? ''}
                    onChange={e => setOption(i, e.target.value)}
                    placeholder={`Đáp án ${lbl}...`}
                  />
                </div>
              ))}

              <label style={s.label}>Đáp án đúng</label>
              <div style={{ display: 'flex', gap: 16, marginTop: 4 }}>
                {ANSWER_LABELS.map((lbl, i) => (
                  <label key={i} style={{ display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer', fontWeight: form.correctAnswerIndex === i ? 700 : 400, color: form.correctAnswerIndex === i ? '#16a34a' : '#374151' }}>
                    <input type="radio" name="correct" checked={form.correctAnswerIndex === i} onChange={() => setForm({ ...form, correctAnswerIndex: i })} />
                    {lbl}
                  </label>
                ))}
              </div>

              <label style={s.label}>Giải thích (tùy chọn)</label>
              <textarea style={{ ...s.input, minHeight: 60, resize: 'vertical' }} value={form.explanation ?? ''} onChange={e => setForm({ ...form, explanation: e.target.value })} placeholder="Giải thích đáp án đúng..." />

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                <div>
                  <label style={s.label}>Điểm</label>
                  <input style={s.input} type="number" value={form.points ?? 10} onChange={e => setForm({ ...form, points: Number(e.target.value) })} />
                </div>
                <div>
                  <label style={s.label}>Thứ tự</label>
                  <input style={s.input} type="number" value={form.order ?? 0} onChange={e => setForm({ ...form, order: Number(e.target.value) })} />
                </div>
              </div>
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
              <h3 style={s.modalTitle}>Xoá câu hỏi</h3>
              <button onClick={closeModal} style={s.modalClose}><X size={16}/></button>
            </div>
            <div style={s.modalBody}>
              <p style={{ color: '#6b7280', marginBottom: 8 }}>Bạn chắc chắn muốn xoá câu hỏi này?</p>
              <p style={{ color: '#475569', fontSize: 13, marginBottom: 8, fontStyle: 'italic' }}>{modal.item?.questionText}</p>
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
  selectorBar: { display: 'flex', gap: 12, alignItems: 'flex-end', marginBottom: 16, background: '#f8fafc', padding: 16, borderRadius: 12, border: '1px solid #e2e8f0', flexWrap: 'wrap' },
  selectorItem: { display: 'flex', flexDirection: 'column', gap: 4 },
  selectorLabel: { fontSize: 12, fontWeight: 600, color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.05em' },
  toolbar: { display: 'flex', gap: 10, marginBottom: 16, alignItems: 'center', flexWrap: 'wrap' },
  searchInput: { flex: 1, minWidth: 180, padding: '8px 14px', border: '1.5px solid #e2e8f0', borderRadius: 8, fontSize: 14, outline: 'none' },
  selectWrap: { position: 'relative', display: 'inline-flex', alignItems: 'center' },
  select: { padding: '8px 36px 8px 12px', border: '1.5px solid #e2e8f0', borderRadius: 8, fontSize: 14, outline: 'none', background: '#fff', cursor: 'pointer', minWidth: 200, appearance: 'none', WebkitAppearance: 'none' },
  selectArrow: { position: 'absolute', right: 12, pointerEvents: 'none', color: '#64748b' },
  btnPrimary: { padding: '8px 18px', background: '#1a73e8', color: '#fff', border: 'none', borderRadius: 8, cursor: 'pointer', fontWeight: 600, fontSize: 14 },
  btnSecondary: { padding: '8px 14px', background: '#f1f5f9', color: '#334155', border: '1.5px solid #e2e8f0', borderRadius: 8, cursor: 'pointer', fontSize: 14 },
  btnGroup: { display: 'flex', gap: 6 },
  btnSm: { padding: '6px 12px', background: '#f8fafc', color: '#475569', border: '1.5px solid #e2e8f0', borderRadius: 6, cursor: 'pointer', fontSize: 12, fontWeight: 500 },
  errorBox: { background: '#fee2e2', color: '#dc2626', padding: '10px 16px', borderRadius: 8, marginBottom: 12 },
  progressBox: { background: '#fef9c3', color: '#854d0e', padding: '10px 16px', borderRadius: 8, marginBottom: 12 },
  loading: { textAlign: 'center', padding: 60, color: '#94a3b8', fontSize: 16 },
  empty: { textAlign: 'center', padding: 60, color: '#94a3b8' },
  tableWrap: { overflowX: 'auto', borderRadius: 12, border: '1px solid #e2e8f0', background: '#fff' },
  table: { width: '100%', borderCollapse: 'collapse', fontSize: 14 },
  thead: { background: '#f8fafc' },
  th: { padding: '12px 16px', textAlign: 'left', fontWeight: 600, color: '#374151', borderBottom: '1px solid #e2e8f0', whiteSpace: 'nowrap' },
  tr: { borderBottom: '1px solid #f1f5f9', transition: 'background 0.1s' },
  td: { padding: '10px 14px', verticalAlign: 'middle' },
  badge: { display: 'inline-block', padding: '2px 10px', borderRadius: 99, background: '#f1f5f9', color: '#475569', fontSize: 12, fontWeight: 500 },
  actions: { display: 'flex', gap: 6 },
  btnEdit: { padding: '4px 10px', background: '#e0f2fe', border: 'none', borderRadius: 6, cursor: 'pointer', fontSize: 14 },
  btnDelete: { padding: '4px 10px', background: '#fee2e2', border: 'none', borderRadius: 6, cursor: 'pointer', fontSize: 14 },
  overlay: { position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.45)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 200 },
  modal: { background: '#fff', borderRadius: 14, width: 600, maxWidth: '90vw', maxHeight: '90vh', display: 'flex', flexDirection: 'column', overflow: 'hidden' },
  modalHeader: { padding: '18px 24px', borderBottom: '1px solid #e2e8f0', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexShrink: 0 },
  modalTitle: { margin: 0, fontSize: 18, fontWeight: 700, color: '#1e293b' },
  modalBody: { padding: '20px 24px', overflowY: 'auto', flex: 1 },
  modalFooter: { padding: '14px 24px', borderTop: '1px solid #e2e8f0', display: 'flex', justifyContent: 'flex-end', gap: 12, flexShrink: 0 },
  modalClose: { background: 'none', border: 'none', cursor: 'pointer', fontSize: 20, color: '#94a3b8', padding: '2px 4px', lineHeight: 1, borderRadius: 4 },
  label: { display: 'block', fontSize: 13, fontWeight: 500, color: '#374151', marginBottom: 4, marginTop: 12 },
  input: { width: '100%', padding: '9px 12px', border: '1.5px solid #e2e8f0', borderRadius: 8, fontSize: 14, outline: 'none', boxSizing: 'border-box' },
  cancelBtn: { padding: '9px 20px', border: '1.5px solid #e2e8f0', borderRadius: 8, background: '#fff', cursor: 'pointer', fontWeight: 500 },
}
