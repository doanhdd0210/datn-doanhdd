import { useState, useEffect, useCallback } from 'react'
import { statsApi } from '../services/api'
import { exportCsv } from '../utils/importExport'

const RANK_STYLES = {
  0: { background: '#fef9c3', color: '#854d0e', badge: '🥇' },
  1: { background: '#f1f5f9', color: '#475569', badge: '🥈' },
  2: { background: '#fff7ed', color: '#c2410c', badge: '🥉' },
}

export default function LeaderboardPage() {
  const [users, setUsers] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const data = await statsApi.leaderboard()
      setUsers(data ?? [])
    } catch (e) {
      setError(e.message)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { load() }, [load])

  const filtered = users.filter(u => {
    const q = search.toLowerCase()
    return !q || u.displayName?.toLowerCase().includes(q) || u.email?.toLowerCase().includes(q)
  })

  const handleExportCsv = () => {
    const rows = filtered.map((u, i) => ({
      rank: i + 1,
      name: u.displayName || u.email || '—',
      email: u.email || '—',
      xp: u.xp ?? u.totalXp ?? 0,
      streak: u.streak ?? u.currentStreak ?? 0,
      lessonsCompleted: u.lessonsCompleted ?? u.completedLessons ?? 0,
      lastStudied: u.lastStudied ?? u.lastActiveAt ?? '—',
    }))
    exportCsv(rows, ['rank', 'name', 'email', 'xp', 'streak', 'lessonsCompleted', 'lastStudied'], 'leaderboard.csv')
  }

  const formatDate = (d) => {
    if (!d) return '—'
    try { return new Date(d).toLocaleDateString('vi-VN') }
    catch { return d }
  }

  return (
    <div>
      {/* Toolbar */}
      <div style={s.toolbar}>
        <input placeholder="Tìm theo tên, email..." value={search} onChange={e => setSearch(e.target.value)} style={s.searchInput} />
        <button onClick={load} style={s.btnSecondary}>⟳ Làm mới</button>
        <button onClick={handleExportCsv} style={s.btnSm}>📊 Export CSV</button>
      </div>

      {error && <div style={s.errorBox}>{error}</div>}

      <div style={s.statsRow}>
        <span style={s.stat}>Tổng: <strong>{users.length}</strong></span>
        <span style={s.stat}>Hiển thị: <strong>{filtered.length}</strong></span>
      </div>

      {loading ? (
        <div style={s.loading}>⏳ Đang tải...</div>
      ) : filtered.length === 0 ? (
        <div style={s.empty}><div style={{ fontSize: 48 }}>🏆</div><div style={{ color: '#94a3b8', marginTop: 8 }}>Chưa có dữ liệu bảng xếp hạng</div></div>
      ) : (
        <div style={s.tableWrap}>
          <table style={s.table}>
            <thead>
              <tr style={s.thead}>
                <th style={s.th}>Hạng</th>
                <th style={s.th}>Người dùng</th>
                <th style={s.th}>Email</th>
                <th style={s.th}>XP</th>
                <th style={s.th}>Streak</th>
                <th style={s.th}>Số bài học</th>
                <th style={s.th}>Ngày cuối học</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((u, idx) => {
                const rankStyle = RANK_STYLES[idx] ?? {}
                const isTop3 = idx < 3
                const xp = u.xp ?? u.totalXp ?? 0
                const streak = u.streak ?? u.currentStreak ?? 0
                const lessons = u.lessonsCompleted ?? u.completedLessons ?? 0
                const avatar = u.photoUrl || u.avatarUrl

                return (
                  <tr key={u.uid || u.id || idx} style={{ ...s.tr, background: isTop3 ? rankStyle.background : idx % 2 === 0 ? '#fff' : '#f9f9f9' }}
                    onMouseEnter={e => e.currentTarget.style.background = '#f0f9eb'}
                    onMouseLeave={e => e.currentTarget.style.background = isTop3 ? rankStyle.background : idx % 2 === 0 ? '#fff' : '#f9f9f9'}>
                    <td style={{ ...s.td, textAlign: 'center', fontWeight: 700, fontSize: 18 }}>
                      {isTop3 ? rankStyle.badge : <span style={{ color: '#94a3b8', fontSize: 14 }}>#{idx + 1}</span>}
                    </td>
                    <td style={s.td}>
                      <div style={s.userCell}>
                        <div style={s.avatar}>
                          {avatar
                            ? <img src={avatar} alt="" style={s.avatarImg} />
                            : <span>{(u.displayName || u.email || '?')[0].toUpperCase()}</span>}
                        </div>
                        <span style={{ fontWeight: 600, color: isTop3 ? rankStyle.color : '#1e293b' }}>
                          {u.displayName || '—'}
                        </span>
                      </div>
                    </td>
                    <td style={{ ...s.td, fontSize: 13, color: '#64748b' }}>{u.email || '—'}</td>
                    <td style={s.td}>
                      <span style={{ ...s.badge, background: '#fef9c3', color: '#854d0e', fontWeight: 700 }}>
                        ⭐ {xp.toLocaleString()}
                      </span>
                    </td>
                    <td style={{ ...s.td, textAlign: 'center' }}>
                      <span style={{ ...s.badge, background: streak > 0 ? '#fff7ed' : '#f1f5f9', color: streak > 0 ? '#c2410c' : '#94a3b8' }}>
                        🔥 {streak}
                      </span>
                    </td>
                    <td style={{ ...s.td, textAlign: 'center' }}>
                      <span style={s.badge}>{lessons}</span>
                    </td>
                    <td style={{ ...s.td, fontSize: 13, color: '#64748b' }}>{formatDate(u.lastStudied ?? u.lastActiveAt)}</td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}

const s = {
  toolbar: { display: 'flex', gap: 10, marginBottom: 16, alignItems: 'center', flexWrap: 'wrap' },
  searchInput: { flex: 1, minWidth: 200, padding: '8px 14px', border: '1.5px solid #e2e8f0', borderRadius: 8, fontSize: 14, outline: 'none' },
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
  tr: { borderBottom: '1px solid #f1f5f9', transition: 'background 0.15s' },
  td: { padding: '12px 16px', verticalAlign: 'middle' },
  userCell: { display: 'flex', alignItems: 'center', gap: 10 },
  avatar: { width: 36, height: 36, borderRadius: '50%', background: '#e0e7ff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, color: '#4f46e5', flexShrink: 0, overflow: 'hidden' },
  avatarImg: { width: 36, height: 36, objectFit: 'cover' },
  badge: { display: 'inline-block', padding: '2px 10px', borderRadius: 99, background: '#f1f5f9', color: '#475569', fontSize: 12, fontWeight: 500 },
}
