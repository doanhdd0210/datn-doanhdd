import { useState, useEffect, useCallback } from 'react'
import { achievementsApi } from '../services/api'

const CONDITION_TYPES = [
  { value: 'lessonCount', label: 'Số bài học hoàn thành' },
  { value: 'xpRequired', label: 'Tổng XP tích lũy' },
  { value: 'streakDays', label: 'Số ngày streak liên tiếp' },
]

const CONDITION_LABEL = Object.fromEntries(CONDITION_TYPES.map(c => [c.value, c.label]))

const EMPTY_FORM = {
  title: '',
  description: '',
  icon: '🏅',
  conditionType: 'lessonCount',
  conditionValue: 1,
  xpReward: 0,
  isActive: true,
}

export default function AchievementsPage() {
  const [items, setItems] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [modal, setModal] = useState(null) // null | { mode: 'create'|'edit'|'delete', item? }
  const [form, setForm] = useState(EMPTY_FORM)
  const [saving, setSaving] = useState(false)
  const [saveError, setSaveError] = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const data = await achievementsApi.list()
      setItems(data ?? [])
    } catch (e) {
      setError(e.message)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { load() }, [load])

  const openCreate = () => {
    setForm({ ...EMPTY_FORM })
    setModal({ mode: 'create' })
  }

  const openEdit = (item) => {
    setForm({
      title: item.title,
      description: item.description,
      icon: item.icon,
      conditionType: item.conditionType,
      conditionValue: item.conditionValue,
      xpReward: item.xpReward,
      isActive: item.isActive,
    })
    setModal({ mode: 'edit', item })
  }

  const openDelete = (item) => setModal({ mode: 'delete', item })
  const closeModal = () => { setModal(null); setForm(EMPTY_FORM); setSaveError('') }

  const handleSave = async () => {
    if (!form.title.trim()) return alert('Vui lòng nhập tên achievement')
    setSaving(true)
    try {
      if (modal.mode === 'create') {
        await achievementsApi.create(form)
      } else {
        await achievementsApi.update(modal.item.id, form)
      }
      await load()
      closeModal()
    } catch (e) {
      setSaveError(e.message)
    } finally {
      setSaving(false)
    }
  }

  const handleDelete = async () => {
    setSaving(true)
    try {
      await achievementsApi.delete(modal.item.id)
      await load()
      closeModal()
    } catch (e) {
      alert('Lỗi: ' + e.message)
    } finally {
      setSaving(false)
    }
  }

  const setF = (key, val) => setForm(f => ({ ...f, [key]: val }))

  return (
    <div>
      <div style={s.toolbar}>
        <button onClick={load} style={s.btnSecondary}>⟳ Làm mới</button>
        <button onClick={openCreate} style={s.btnPrimary}>+ Thêm Achievement</button>
      </div>

      {error && <div style={s.errorBox}>{error}</div>}

      <div style={s.statsRow}>
        <span style={s.stat}>Tổng: <strong>{items.length}</strong></span>
        <span style={s.stat}>Đang bật: <strong>{items.filter(i => i.isActive).length}</strong></span>
      </div>

      {loading ? (
        <div style={s.loading}>⏳ Đang tải...</div>
      ) : items.length === 0 ? (
        <div style={s.empty}><div style={{ fontSize: 48 }}>🏅</div><div style={{ color: '#94a3b8', marginTop: 8 }}>Chưa có achievement nào. Thêm mới để bắt đầu!</div></div>
      ) : (
        <div style={s.grid}>
          {items.map(item => (
            <div key={item.id} style={{ ...s.card, opacity: item.isActive ? 1 : 0.6 }}>
              <div style={s.cardHeader}>
                <span style={s.cardIcon}>{item.icon}</span>
                <div style={{ flex: 1 }}>
                  <div style={s.cardTitle}>{item.title}</div>
                  <div style={s.cardSub}>{item.description}</div>
                </div>
                {!item.isActive && <span style={s.inactiveBadge}>Tắt</span>}
              </div>
              <div style={s.cardBody}>
                <div style={s.condRow}>
                  <span style={s.condLabel}>Điều kiện:</span>
                  <span style={s.condValue}>{CONDITION_LABEL[item.conditionType] ?? item.conditionType} ≥ {item.conditionValue}</span>
                </div>
                <div style={s.condRow}>
                  <span style={s.condLabel}>Thưởng XP:</span>
                  <span style={{ ...s.condValue, color: '#854d0e', fontWeight: 700 }}>⭐ {item.xpReward}</span>
                </div>
              </div>
              <div style={s.cardActions}>
                <button onClick={() => openEdit(item)} style={s.btnEdit}>✏️ Sửa</button>
                <button onClick={() => openDelete(item)} style={s.btnDelete}>🗑️ Xoá</button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Modal Create / Edit */}
      {modal && modal.mode !== 'delete' && (
        <div style={s.overlay}>
          <div style={s.modal}>
            <div style={s.modalHeader}>
              <h3 style={s.modalTitle}>{modal.mode === 'create' ? 'Thêm Achievement mới' : `Sửa: ${modal.item?.title}`}</h3>
              <button onClick={closeModal} style={s.modalClose}>✕</button>
            </div>
            <div style={s.modalBody}>
              <label style={s.label}>Icon (emoji)</label>
              <input style={s.input} value={form.icon} onChange={e => setF('icon', e.target.value)} placeholder="🏅" />

              <label style={s.label}>Tên achievement</label>
              <input style={s.input} value={form.title} onChange={e => setF('title', e.target.value)} placeholder="VD: Người khởi đầu" />

              <label style={s.label}>Mô tả</label>
              <textarea style={{ ...s.input, height: 72, resize: 'vertical' }} value={form.description} onChange={e => setF('description', e.target.value)} placeholder="Mô tả ngắn về achievement..." />

              <label style={s.label}>Loại điều kiện</label>
              <select style={s.input} value={form.conditionType} onChange={e => setF('conditionType', e.target.value)}>
                {CONDITION_TYPES.map(c => <option key={c.value} value={c.value}>{c.label}</option>)}
              </select>

              <label style={s.label}>Giá trị điều kiện</label>
              <input style={s.input} type="number" min={1} value={form.conditionValue} onChange={e => setF('conditionValue', parseInt(e.target.value) || 1)} />

              <label style={s.label}>Thưởng XP</label>
              <input style={s.input} type="number" min={0} value={form.xpReward} onChange={e => setF('xpReward', parseInt(e.target.value) || 0)} />

              <label style={s.checkboxRow}>
                <input type="checkbox" checked={form.isActive} onChange={e => setF('isActive', e.target.checked)} />
                <span style={{ marginLeft: 8 }}>Bật achievement</span>
              </label>

              {saveError && <div style={{ color: '#dc2626', fontSize: 13, marginTop: 8 }}>⚠️ {saveError}</div>}
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
          <div style={{ ...s.modal, maxWidth: 400 }}>
            <div style={s.modalHeader}>
              <h3 style={s.modalTitle}>Xoá Achievement</h3>
              <button onClick={closeModal} style={s.modalClose}>✕</button>
            </div>
            <div style={s.modalBody}>
              <p style={{ color: '#6b7280', margin: 0 }}>
                Bạn chắc chắn muốn xoá <strong>{modal.item?.icon} {modal.item?.title}</strong>?
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
  toolbar: { display: 'flex', gap: 10, marginBottom: 16, alignItems: 'center', justifyContent: 'flex-end' },
  btnPrimary: { padding: '8px 18px', background: '#1a73e8', color: '#fff', border: 'none', borderRadius: 8, cursor: 'pointer', fontWeight: 600, fontSize: 14 },
  btnSecondary: { padding: '8px 14px', background: '#f1f5f9', color: '#334155', border: '1.5px solid #e2e8f0', borderRadius: 8, cursor: 'pointer', fontSize: 14 },
  errorBox: { background: '#fee2e2', color: '#dc2626', padding: '10px 16px', borderRadius: 8, marginBottom: 12 },
  statsRow: { display: 'flex', gap: 20, marginBottom: 16, flexWrap: 'wrap' },
  stat: { fontSize: 14, color: '#64748b' },
  loading: { textAlign: 'center', padding: 60, color: '#94a3b8', fontSize: 16 },
  empty: { textAlign: 'center', padding: 60, color: '#94a3b8' },
  grid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', gap: 16 },
  card: { background: '#fff', borderRadius: 12, border: '1px solid #e2e8f0', padding: 18, display: 'flex', flexDirection: 'column', gap: 12 },
  cardHeader: { display: 'flex', alignItems: 'flex-start', gap: 12 },
  cardIcon: { fontSize: 32, lineHeight: 1 },
  cardTitle: { fontWeight: 700, color: '#1e293b', fontSize: 15 },
  cardSub: { fontSize: 13, color: '#64748b', marginTop: 2 },
  inactiveBadge: { padding: '2px 8px', background: '#f1f5f9', color: '#94a3b8', borderRadius: 99, fontSize: 11, fontWeight: 500, flexShrink: 0 },
  cardBody: { display: 'flex', flexDirection: 'column', gap: 6, padding: '10px 0', borderTop: '1px solid #f1f5f9', borderBottom: '1px solid #f1f5f9' },
  condRow: { display: 'flex', gap: 8, alignItems: 'center', fontSize: 13 },
  condLabel: { color: '#94a3b8', minWidth: 90 },
  condValue: { color: '#334155', fontWeight: 500 },
  cardActions: { display: 'flex', gap: 8 },
  btnEdit: { flex: 1, padding: '6px 0', background: '#e0f2fe', border: 'none', borderRadius: 6, cursor: 'pointer', fontSize: 13, fontWeight: 500 },
  btnDelete: { flex: 1, padding: '6px 0', background: '#fee2e2', border: 'none', borderRadius: 6, cursor: 'pointer', fontSize: 13, fontWeight: 500 },
  overlay: { position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.45)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 200 },
  modal: { background: '#fff', borderRadius: 14, width: 440, maxWidth: '90vw', maxHeight: '90vh', display: 'flex', flexDirection: 'column', overflow: 'hidden' },
  modalHeader: { padding: '18px 24px', borderBottom: '1px solid #e2e8f0', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexShrink: 0 },
  modalTitle: { margin: 0, fontSize: 18, fontWeight: 700, color: '#1e293b' },
  modalBody: { padding: '20px 24px', overflowY: 'auto', flex: 1 },
  modalFooter: { padding: '14px 24px', borderTop: '1px solid #e2e8f0', display: 'flex', justifyContent: 'flex-end', gap: 12, flexShrink: 0 },
  modalClose: { background: 'none', border: 'none', cursor: 'pointer', fontSize: 20, color: '#94a3b8', padding: '2px 4px', lineHeight: 1, borderRadius: 4 },
  label: { display: 'block', fontSize: 13, fontWeight: 500, color: '#374151', marginBottom: 4, marginTop: 12 },
  input: { width: '100%', padding: '9px 12px', border: '1.5px solid #e2e8f0', borderRadius: 8, fontSize: 14, outline: 'none', boxSizing: 'border-box' },
  checkboxRow: { display: 'flex', alignItems: 'center', marginTop: 16, fontSize: 14, cursor: 'pointer' },
  cancelBtn: { padding: '9px 20px', border: '1.5px solid #e2e8f0', borderRadius: 8, background: '#fff', cursor: 'pointer', fontWeight: 500 },
}
