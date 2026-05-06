import { useState, useEffect } from 'react'
import { Users, ShieldCheck, BookOpen, GraduationCap, Target, Star, BarChart2, Flame, Trophy, Zap, CalendarDays } from 'lucide-react'
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

      const nonAdmins = users.filter(u => !u.isAdmin)
      const adminUsers = users.filter(u => u.isAdmin)

      const usersWithXp = lb.filter(u => (u.xp ?? u.totalXp ?? 0) > 0)
      const totalXp = lb.reduce((s, u) => s + (u.xp ?? u.totalXp ?? 0), 0)
      const avgXp = lb.length > 0 ? Math.round(totalXp / lb.length) : 0
      const usersWithStreak = lb.filter(u => (u.streak ?? u.currentStreak ?? 0) > 0)
      const maxStreak = lb.reduce((m, u) => Math.max(m, u.streak ?? u.currentStreak ?? 0), 0)
      const totalLessonsCompleted = lb.reduce((s, u) => s + (u.lessonsCompleted ?? u.completedLessons ?? 0), 0)

      const now = new Date()
      const monthlyReg = Array.from({ length: 6 }, (_, i) => {
        const d = new Date(now.getFullYear(), now.getMonth() - (5 - i), 1)
        const label = d.toLocaleDateString('vi-VN', { month: 'short', year: 'numeric' })
        const count = nonAdmins.filter(u => {
          const created = new Date(u.createdAt)
          return created.getFullYear() === d.getFullYear() && created.getMonth() === d.getMonth()
        }).length
        return { label, count }
      })

      const xpBuckets = [
        { label: '0 XP',    count: lb.filter(u => (u.xp ?? u.totalXp ?? 0) === 0).length },
        { label: '1–100',   count: lb.filter(u => { const x = u.xp ?? u.totalXp ?? 0; return x >= 1 && x <= 100 }).length },
        { label: '101–500', count: lb.filter(u => { const x = u.xp ?? u.totalXp ?? 0; return x >= 101 && x <= 500 }).length },
        { label: '501–1k',  count: lb.filter(u => { const x = u.xp ?? u.totalXp ?? 0; return x >= 501 && x <= 1000 }).length },
        { label: '1k+',     count: lb.filter(u => (u.xp ?? u.totalXp ?? 0) > 1000).length },
      ]

      setData({
        users: nonAdmins, adminUsers,
        topics, lessons,
        lb, usersWithXp, totalXp, avgXp, usersWithStreak, maxStreak, totalLessonsCompleted,
        monthlyReg, xpBuckets,
        top5: lb.slice(0, 5),
      })
    }).catch(e => setError(e.message))
      .finally(() => setLoading(false))
  }, [])

  if (loading) return <div style={s.loading}>Đang tải dữ liệu phân tích...</div>
  if (error) return <div style={s.errorBox}>{error}</div>
  if (!data) return null

  const maxMonthly = Math.max(...data.monthlyReg.map(m => m.count), 1)
  const maxXpBucket = Math.max(...data.xpBuckets.map(b => b.count), 1)

  return (
    <div style={s.page}>
      <SectionTitle Icon={Users} color="#3b82f6" label="Thống kê người dùng" />
      <div style={s.cardRow}>
        <StatCard Icon={Users}       iconColor="#3b82f6" iconBg="#eff6ff" label="Tổng người dùng"  value={data.users.length}       accent="#3b82f6" />
        <StatCard Icon={ShieldCheck} iconColor="#7c3aed" iconBg="#f5f3ff" label="Admin"            value={data.adminUsers.length}  accent="#7c3aed" />
      </div>

      <SectionTitle Icon={BookOpen} color="#9333ea" label="Thống kê nội dung" />
      <div style={s.cardRow}>
        <StatCard Icon={BookOpen}      iconColor="#ca8a04" iconBg="#fefce8" label="Chủ đề"              value={data.topics.length}  accent="#ca8a04" />
        <StatCard Icon={GraduationCap} iconColor="#9333ea" iconBg="#f5f3ff" label="Bài học"             value={data.lessons.length} accent="#9333ea" />
        <StatCard Icon={Target}        iconColor="#0ea5e9" iconBg="#f0f9ff" label="Bài học TB/chủ đề"   value={data.topics.length > 0 ? (data.lessons.length / data.topics.length).toFixed(1) : '—'} accent="#0ea5e9" />
      </div>

      <SectionTitle Icon={Zap} color="#f59e0b" label="Thống kê tương tác" />
      <div style={s.cardRow}>
        <StatCard Icon={Star}          iconColor="#ca8a04" iconBg="#fefce8" label="Tổng XP hệ thống"        value={data.totalXp.toLocaleString()}           accent="#ca8a04" />
        <StatCard Icon={BarChart2}     iconColor="#3b82f6" iconBg="#eff6ff" label="XP trung bình/user"      value={data.avgXp.toLocaleString()}             accent="#3b82f6" />
        <StatCard Icon={Flame}         iconColor="#ef4444" iconBg="#fef2f2" label="Streak dài nhất"         value={`${data.maxStreak} ngày`}                accent="#ef4444" />
        <StatCard Icon={GraduationCap} iconColor="#16a34a" iconBg="#f0fdf4" label="Bài học đã hoàn thành"  value={data.totalLessonsCompleted.toLocaleString()} accent="#16a34a" />
        <StatCard Icon={Users}         iconColor="#8b5cf6" iconBg="#f5f3ff" label="Users có XP"             value={`${data.usersWithXp.length}/${data.lb.length}`} accent="#8b5cf6" />
        <StatCard Icon={Zap}           iconColor="#f59e0b" iconBg="#fffbeb" label="Users đang streak"       value={data.usersWithStreak.length}             accent="#f59e0b" />
      </div>

      <div style={s.twoCol}>
        <div style={s.card}>
          <div style={s.chartTitle}><CalendarDays size={15} color="#3b82f6" /><span>Người dùng mới theo tháng</span></div>
          <div style={s.barChart}>
            {data.monthlyReg.map(m => (
              <div key={m.label} style={s.barGroup}>
                <div style={s.barValue}>{m.count}</div>
                <div style={{ ...s.bar, height: `${Math.max(4, (m.count / maxMonthly) * 130)}px`, background: 'linear-gradient(to top, #3b82f6, #93c5fd)' }} />
                <div style={s.barLabel}>{m.label}</div>
              </div>
            ))}
          </div>
        </div>

        <div style={s.card}>
          <div style={s.chartTitle}><Star size={15} color="#a78bfa" /><span>Phân bố XP người dùng</span></div>
          <div style={s.barChart}>
            {data.xpBuckets.map(b => (
              <div key={b.label} style={s.barGroup}>
                <div style={s.barValue}>{b.count}</div>
                <div style={{ ...s.bar, height: `${Math.max(4, (b.count / maxXpBucket) * 130)}px`, background: 'linear-gradient(to top, #8b5cf6, #c4b5fd)' }} />
                <div style={s.barLabel}>{b.label}</div>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div style={s.card}>
        <div style={s.chartTitle}><Trophy size={15} color="#f59e0b" /><span>Top 5 người dùng</span></div>
        {data.top5.length === 0 ? (
          <div style={{ color: '#94a3b8', textAlign: 'center', padding: 24, fontSize: 14 }}>Chưa có dữ liệu</div>
        ) : (
          <table style={s.table}>
            <thead>
              <tr style={s.thead}>
                <th style={{ ...s.th, width: 60, textAlign: 'center' }}>Hạng</th>
                <th style={s.th}>Tên</th>
                <th style={{ ...s.th, textAlign: 'center' }}>XP</th>
                <th style={{ ...s.th, textAlign: 'center' }}>Streak</th>
                <th style={{ ...s.th, textAlign: 'center' }}>Bài học</th>
              </tr>
            </thead>
            <tbody>
              {data.top5.map((u, i) => (
                <tr key={u.uid || i} style={{ ...s.tr, background: i === 0 ? '#fffbeb' : 'transparent' }}>
                  <td style={{ ...s.td, textAlign: 'center', fontSize: 18 }}>
                    {['🥇','🥈','🥉','4','5'][i]}
                  </td>
                  <td style={{ ...s.td, fontWeight: 600, color: '#1e293b' }}>{u.displayName || u.email || '—'}</td>
                  <td style={{ ...s.td, textAlign: 'center' }}>
                    <span style={s.xpBadge}>⭐ {(u.xp ?? u.totalXp ?? 0).toLocaleString()}</span>
                  </td>
                  <td style={{ ...s.td, textAlign: 'center', color: '#ef4444', fontWeight: 600 }}>
                    {(u.streak ?? u.currentStreak ?? 0) > 0 ? `🔥 ${u.streak ?? u.currentStreak}` : '—'}
                  </td>
                  <td style={{ ...s.td, textAlign: 'center', color: '#16a34a', fontWeight: 600 }}>
                    {u.lessonsCompleted ?? u.completedLessons ?? 0}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}

function SectionTitle({ Icon, color, label }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12, marginTop: 4 }}>
      <div style={{ width: 3, height: 18, borderRadius: 2, background: color }} />
      <Icon size={16} color={color} strokeWidth={2} />
      <span style={{ fontSize: 15, fontWeight: 700, color: '#1e293b' }}>{label}</span>
    </div>
  )
}

function StatCard({ Icon, iconColor, iconBg, label, value, accent }) {
  return (
    <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #e2e8f0', borderTop: `3px solid ${accent}`, padding: '16px 14px', display: 'flex', flexDirection: 'column', gap: 10, alignItems: 'center', textAlign: 'center' }}>
      <div style={{ width: 40, height: 40, borderRadius: 10, background: iconBg, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <Icon size={20} color={iconColor} strokeWidth={1.75} />
      </div>
      <div style={{ fontSize: 24, fontWeight: 800, color: '#1e293b', lineHeight: 1 }}>{value}</div>
      <div style={{ fontSize: 12, color: '#64748b', lineHeight: 1.4 }}>{label}</div>
    </div>
  )
}

const s = {
  page: { display: 'flex', flexDirection: 'column', gap: 16 },
  card: { background: '#fff', borderRadius: 12, border: '1px solid #e2e8f0', padding: '18px 20px' },
  cardRow: { display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(155px, 1fr))', gap: 12, marginBottom: 8 },
  twoCol: { display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: 16 },
  chartTitle: { display: 'flex', alignItems: 'center', gap: 6, marginBottom: 16, fontSize: 14, fontWeight: 700, color: '#1e293b' },
  barChart: { display: 'flex', alignItems: 'flex-end', gap: 8, height: 170, paddingTop: 16 },
  barGroup: { flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 },
  barValue: { fontSize: 11, color: '#64748b', fontWeight: 600 },
  bar: { width: '100%', borderRadius: '4px 4px 0 0', minWidth: 20, transition: 'height 0.3s' },
  barLabel: { fontSize: 10, color: '#94a3b8', textAlign: 'center', wordBreak: 'break-all' },
  loading: { textAlign: 'center', padding: 60, color: '#94a3b8', fontSize: 16 },
  errorBox: { background: '#fee2e2', color: '#dc2626', padding: '10px 16px', borderRadius: 8 },
  table: { width: '100%', borderCollapse: 'collapse', fontSize: 14 },
  thead: { background: '#f8fafc' },
  th: { padding: '10px 14px', textAlign: 'left', fontWeight: 600, color: '#374151', borderBottom: '1px solid #e2e8f0', fontSize: 13 },
  tr: { borderBottom: '1px solid #f1f5f9', transition: 'background 0.15s' },
  td: { padding: '11px 14px', verticalAlign: 'middle' },
  xpBadge: { display: 'inline-block', padding: '3px 10px', borderRadius: 99, background: '#fef9c3', color: '#854d0e', fontWeight: 700, fontSize: 12 },
}
