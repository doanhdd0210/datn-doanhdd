import { useState, useEffect } from 'react'
import { usersApi, topicsApi, lessonsApi, statsApi, qaApi } from '../services/api'

export default function AnalyticsPage() {
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    Promise.allSettled([
      usersApi.list(1000),
      topicsApi.list(),
      lessonsApi.list(),
      statsApi.leaderboard(500),
      qaApi.list(1),
    ]).then(([usersRes, topicsRes, lessonsRes, lbRes, qaRes]) => {
      const users = usersRes.status === 'fulfilled' ? (usersRes.value ?? []) : []
      const topics = topicsRes.status === 'fulfilled' ? (topicsRes.value ?? []) : []
      const lessons = lessonsRes.status === 'fulfilled' ? (lessonsRes.value ?? []) : []
      const lb = lbRes.status === 'fulfilled' ? (lbRes.value ?? []) : []

      const activeUsers = users.filter(u => !u.disabled)
      const adminUsers = users.filter(u => u.isAdmin)
      const disabledUsers = users.filter(u => u.disabled)

      const usersWithXp = lb.filter(u => (u.xp ?? u.totalXp ?? 0) > 0)
      const totalXp = lb.reduce((s, u) => s + (u.xp ?? u.totalXp ?? 0), 0)
      const avgXp = lb.length > 0 ? Math.round(totalXp / lb.length) : 0
      const usersWithStreak = lb.filter(u => (u.streak ?? u.currentStreak ?? 0) > 0)
      const maxStreak = lb.reduce((m, u) => Math.max(m, u.streak ?? u.currentStreak ?? 0), 0)
      const totalLessonsCompleted = lb.reduce((s, u) => s + (u.lessonsCompleted ?? u.completedLessons ?? 0), 0)

      // User registration by month (last 6 months)
      const now = new Date()
      const monthlyReg = Array.from({ length: 6 }, (_, i) => {
        const d = new Date(now.getFullYear(), now.getMonth() - (5 - i), 1)
        const label = d.toLocaleDateString('vi-VN', { month: 'short', year: 'numeric' })
        const count = users.filter(u => {
          const created = new Date(u.createdAt)
          return created.getFullYear() === d.getFullYear() && created.getMonth() === d.getMonth()
        }).length
        return { label, count }
      })

      // XP distribution buckets
      const xpBuckets = [
        { label: '0 XP', count: lb.filter(u => (u.xp ?? u.totalXp ?? 0) === 0).length },
        { label: '1–100', count: lb.filter(u => { const x = u.xp ?? u.totalXp ?? 0; return x >= 1 && x <= 100 }).length },
        { label: '101–500', count: lb.filter(u => { const x = u.xp ?? u.totalXp ?? 0; return x >= 101 && x <= 500 }).length },
        { label: '501–1000', count: lb.filter(u => { const x = u.xp ?? u.totalXp ?? 0; return x >= 501 && x <= 1000 }).length },
        { label: '1000+', count: lb.filter(u => (u.xp ?? u.totalXp ?? 0) > 1000).length },
      ]

      setData({
        users, activeUsers, adminUsers, disabledUsers,
        topics, lessons,
        lb, usersWithXp, totalXp, avgXp, usersWithStreak, maxStreak, totalLessonsCompleted,
        monthlyReg, xpBuckets,
        top5: lb.slice(0, 5),
      })
    }).catch(e => setError(e.message))
      .finally(() => setLoading(false))
  }, [])

  if (loading) return <div style={s.loading}>⏳ Đang tải dữ liệu phân tích...</div>
  if (error) return <div style={s.errorBox}>{error}</div>
  if (!data) return null

  const maxMonthly = Math.max(...data.monthlyReg.map(m => m.count), 1)
  const maxXpBucket = Math.max(...data.xpBuckets.map(b => b.count), 1)

  return (
    <div style={s.page}>
      {/* Section: Người dùng */}
      <section style={s.section}>
        <h3 style={s.sectionTitle}>👥 Thống kê người dùng</h3>
        <div style={s.cardRow}>
          <StatCard icon="👥" label="Tổng người dùng" value={data.users.length} color="#e8f0fe" />
          <StatCard icon="✅" label="Đang hoạt động" value={data.activeUsers.length} color="#e6f4ea" />
          <StatCard icon="🔒" label="Bị khoá" value={data.disabledUsers.length} color="#fce8e6" />
          <StatCard icon="🛡️" label="Admin" value={data.adminUsers.length} color="#ede9fe" />
        </div>
      </section>

      {/* Section: Nội dung */}
      <section style={s.section}>
        <h3 style={s.sectionTitle}>📚 Thống kê nội dung</h3>
        <div style={s.cardRow}>
          <StatCard icon="📚" label="Chủ đề" value={data.topics.length} color="#fef9c3" />
          <StatCard icon="📖" label="Bài học" value={data.lessons.length} color="#f3e8ff" />
          <StatCard icon="🎯" label="Bài học TB/chủ đề" value={data.topics.length > 0 ? (data.lessons.length / data.topics.length).toFixed(1) : '—'} color="#e0f2fe" />
        </div>
      </section>

      {/* Section: Engagement */}
      <section style={s.section}>
        <h3 style={s.sectionTitle}>🎮 Thống kê tương tác</h3>
        <div style={s.cardRow}>
          <StatCard icon="⭐" label="Tổng XP toàn hệ thống" value={data.totalXp.toLocaleString()} color="#fef9c3" />
          <StatCard icon="📊" label="XP trung bình/user" value={data.avgXp.toLocaleString()} color="#e8f0fe" />
          <StatCard icon="🔥" label="Streak dài nhất" value={`${data.maxStreak} ngày`} color="#fff7ed" />
          <StatCard icon="📚" label="Tổng bài học đã hoàn thành" value={data.totalLessonsCompleted.toLocaleString()} color="#e6f4ea" />
          <StatCard icon="🙋" label="Users có XP" value={`${data.usersWithXp.length}/${data.lb.length}`} color="#f3e8ff" />
          <StatCard icon="💪" label="Users đang streak" value={data.usersWithStreak.length} color="#fff7ed" />
        </div>
      </section>

      <div style={s.twoCol}>
        {/* Đăng ký theo tháng */}
        <section style={{ ...s.section, ...s.card }}>
          <h3 style={s.sectionTitle}>📅 Người dùng mới theo tháng (6 tháng gần nhất)</h3>
          <div style={s.barChart}>
            {data.monthlyReg.map(m => (
              <div key={m.label} style={s.barGroup}>
                <div style={s.barValue}>{m.count}</div>
                <div style={{ ...s.bar, height: `${Math.max(4, (m.count / maxMonthly) * 140)}px` }} />
                <div style={s.barLabel}>{m.label}</div>
              </div>
            ))}
          </div>
        </section>

        {/* XP Distribution */}
        <section style={{ ...s.section, ...s.card }}>
          <h3 style={s.sectionTitle}>⭐ Phân bố XP người dùng</h3>
          <div style={s.barChart}>
            {data.xpBuckets.map(b => (
              <div key={b.label} style={s.barGroup}>
                <div style={s.barValue}>{b.count}</div>
                <div style={{ ...s.bar, height: `${Math.max(4, (b.count / maxXpBucket) * 140)}px`, background: '#a78bfa' }} />
                <div style={s.barLabel}>{b.label}</div>
              </div>
            ))}
          </div>
        </section>
      </div>

      {/* Top 5 */}
      <section style={{ ...s.section, ...s.card }}>
        <h3 style={s.sectionTitle}>🏆 Top 5 người dùng</h3>
        {data.top5.length === 0 ? (
          <div style={{ color: '#94a3b8', textAlign: 'center', padding: 24 }}>Chưa có dữ liệu</div>
        ) : (
          <table style={s.table}>
            <thead>
              <tr style={s.thead}>
                <th style={s.th}>Hạng</th>
                <th style={s.th}>Tên</th>
                <th style={s.th}>XP</th>
                <th style={s.th}>Streak</th>
                <th style={s.th}>Bài học</th>
              </tr>
            </thead>
            <tbody>
              {data.top5.map((u, i) => (
                <tr key={u.uid || i} style={s.tr}>
                  <td style={{ ...s.td, textAlign: 'center', fontWeight: 700 }}>
                    {['🥇', '🥈', '🥉', '#4', '#5'][i]}
                  </td>
                  <td style={s.td}>{u.displayName || u.email || '—'}</td>
                  <td style={s.td}><span style={s.xpBadge}>⭐ {(u.xp ?? u.totalXp ?? 0).toLocaleString()}</span></td>
                  <td style={{ ...s.td, textAlign: 'center' }}>🔥 {u.streak ?? u.currentStreak ?? 0}</td>
                  <td style={{ ...s.td, textAlign: 'center' }}>{u.lessonsCompleted ?? u.completedLessons ?? 0}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>
    </div>
  )
}

function StatCard({ icon, label, value, color }) {
  return (
    <div style={{ ...s.statCard, background: color }}>
      <span style={{ fontSize: 28 }}>{icon}</span>
      <div style={s.statValue}>{value}</div>
      <div style={s.statLabel}>{label}</div>
    </div>
  )
}

const s = {
  page: { display: 'flex', flexDirection: 'column', gap: 24 },
  section: { marginBottom: 0 },
  sectionTitle: { margin: '0 0 14px', fontSize: 16, fontWeight: 700, color: '#1e293b' },
  card: { background: '#fff', borderRadius: 12, border: '1px solid #e2e8f0', padding: 20 },
  cardRow: { display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(160px, 1fr))', gap: 12 },
  statCard: { borderRadius: 10, padding: '18px 14px', display: 'flex', flexDirection: 'column', gap: 6, alignItems: 'center', textAlign: 'center' },
  statValue: { fontSize: 26, fontWeight: 700, color: '#1e293b' },
  statLabel: { fontSize: 12, color: '#64748b' },
  twoCol: { display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(340px, 1fr))', gap: 20 },
  barChart: { display: 'flex', alignItems: 'flex-end', gap: 8, height: 180, paddingTop: 20 },
  barGroup: { flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 },
  barValue: { fontSize: 11, color: '#64748b', fontWeight: 600 },
  bar: { width: '100%', background: '#60a5fa', borderRadius: '4px 4px 0 0', minWidth: 20, transition: 'height 0.3s' },
  barLabel: { fontSize: 10, color: '#94a3b8', textAlign: 'center', wordBreak: 'break-all' },
  loading: { textAlign: 'center', padding: 60, color: '#94a3b8', fontSize: 16 },
  errorBox: { background: '#fee2e2', color: '#dc2626', padding: '10px 16px', borderRadius: 8 },
  table: { width: '100%', borderCollapse: 'collapse', fontSize: 14 },
  thead: { background: '#f8fafc' },
  th: { padding: '10px 14px', textAlign: 'left', fontWeight: 600, color: '#374151', borderBottom: '1px solid #e2e8f0' },
  tr: { borderBottom: '1px solid #f1f5f9' },
  td: { padding: '10px 14px', verticalAlign: 'middle' },
  xpBadge: { display: 'inline-block', padding: '2px 10px', borderRadius: 99, background: '#fef9c3', color: '#854d0e', fontWeight: 600, fontSize: 12 },
}
