import { useState, useEffect, useCallback } from 'react'
import {
  Users, BookOpen, GraduationCap, HelpCircle, Code2, ShieldCheck, Bell, X,
  LayoutDashboard, BarChart2, Library, ClipboardList, MessagesSquare, Trophy, Star,
  Settings, LogOut, Bot, Crown, PanelLeftClose, PanelLeftOpen,
} from 'lucide-react'
import logo from '../assets/logo.png'
import { useNavigate } from 'react-router-dom'
import { signOut } from '../services/auth'
import { useAuth } from '../context/AuthContext'
import { usersApi, topicsApi, lessonsApi, questionsApi, codeSnippetsApi } from '../services/api'
import UsersPage from './UsersPage'
import NotificationsPage from './NotificationsPage'
import SettingsPage from './SettingsPage'
import TopicsPage from './TopicsPage'
import LessonsPage from './LessonsPage'
import QuestionsPage from './QuestionsPage'
import CodeSnippetsPage from './CodeSnippetsPage'
import QaManagementPage from './QaManagementPage'
import LeaderboardPage from './LeaderboardPage'
import AnalyticsPage from './AnalyticsPage'
import AchievementsPage from './AchievementsPage'
import AiSettingsPage from './AiSettingsPage'
import SubscriptionPage from './SubscriptionPage'

const NAV_ITEMS = [
  { id: 'overview',      label: 'Tổng quan',     Icon: LayoutDashboard },
  { id: 'analytics',     label: 'Phân tích',     Icon: BarChart2 },
  { id: 'users',         label: 'Người dùng',    Icon: Users },
  { id: 'topics',        label: 'Chủ đề',        Icon: Library },
  { id: 'lessons',       label: 'Bài học',       Icon: BookOpen },
  { id: 'questions',     label: 'Câu hỏi Quiz',  Icon: ClipboardList },
  { id: 'snippets',      label: 'Demo Code',     Icon: Code2 },
  { id: 'qa',            label: 'QA Cộng đồng',  Icon: MessagesSquare },
  { id: 'leaderboard',   label: 'Bảng xếp hạng', Icon: Trophy },
  { id: 'achievements',  label: 'Thành tích',    Icon: Star },
  { id: 'notifications', label: 'Thông báo',     Icon: Bell },
  { id: 'ai',            label: 'Cài đặt AI',    Icon: Bot },
  { id: 'subscription',  label: 'Gói VIP',       Icon: Crown },
  { id: 'settings',      label: 'Cài đặt',       Icon: Settings },
]

export default function Dashboard() {
  const { user } = useAuth()
  const navigate = useNavigate()
  const [activeNav, setActiveNav] = useState('overview')
  const [showLogoutModal, setShowLogoutModal] = useState(false)
  const [collapsed, setCollapsed] = useState(false)

  const handleLogout = async () => {
    await signOut()
    navigate('/login', { replace: true })
  }

  return (
    <div style={styles.layout}>
      {/* Sidebar */}
      <aside style={{ ...styles.sidebar, width: collapsed ? 64 : 240 }}>
        <div style={{ ...styles.sidebarHeader, justifyContent: collapsed ? 'center' : 'flex-start', padding: collapsed ? '24px 0' : '24px 20px', position: 'relative' }}>
          <img src={logo} alt="logo" style={{ width: 28, height: 28, objectFit: 'contain', borderRadius: 6, flexShrink: 0 }} />
          {!collapsed && <span style={styles.sidebarTitle}>JavaUp Admin</span>}
          <button
            onClick={() => setCollapsed(!collapsed)}
            style={{
              position: 'absolute',
              right: -12,
              top: '50%',
              transform: 'translateY(-50%)',
              width: 24,
              height: 24,
              borderRadius: '50%',
              background: '#1a73e8',
              border: '2px solid #1e293b',
              color: '#fff',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              zIndex: 10,
              padding: 0,
            }}
            title={collapsed ? 'Mở rộng' : 'Thu gọn'}
          >
            {collapsed
              ? <PanelLeftOpen size={14} strokeWidth={2} />
              : <PanelLeftClose size={14} strokeWidth={2} />}
          </button>
        </div>

        <nav style={{ ...styles.nav, padding: collapsed ? '16px 8px' : '16px 12px', alignItems: collapsed ? 'center' : 'stretch' }}>
          {NAV_ITEMS.map((item) => (
            <button
              key={item.id}
              onClick={() => setActiveNav(item.id)}
              title={collapsed ? item.label : undefined}
              style={{
                ...styles.navItem,
                ...(activeNav === item.id ? styles.navItemActive : {}),
                justifyContent: collapsed ? 'center' : 'flex-start',
                padding: collapsed ? '10px' : '10px 12px',
                width: collapsed ? 40 : '100%',
              }}
            >
              <item.Icon size={16} strokeWidth={1.75} />
              {!collapsed && <span>{item.label}</span>}
            </button>
          ))}
        </nav>

        <div style={{ ...styles.sidebarFooter, justifyContent: collapsed ? 'center' : 'flex-start', padding: collapsed ? '16px 0' : '16px' }}>
          {collapsed ? (
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 }}>
              <div style={styles.avatar} title={user?.email}>
                {user?.email?.[0]?.toUpperCase() ?? 'A'}
              </div>
              <button
                onClick={() => setShowLogoutModal(true)}
                style={styles.logoutBtn}
                title="Đăng xuất"
              >
                <LogOut size={16} strokeWidth={1.75} color="white"/>
              </button>
            </div>
          ) : (
            <>
              <div style={styles.userInfo}>
                <div style={styles.avatar}>
                  {user?.email?.[0]?.toUpperCase() ?? 'A'}
                </div>
                <div style={styles.userText}>
                  <p style={styles.userEmail}>{user?.email}</p>
                  <p style={styles.userRole}>Administrator</p>
                </div>
              </div>
              <button
                onClick={() => setShowLogoutModal(true)}
                style={styles.logoutBtn}
                title="Đăng xuất"
              >
                <LogOut size={16} strokeWidth={1.75} color="white"/>
              </button>
            </>
          )}
        </div>
        {!collapsed && <div style={styles.version}>v1.0.1</div>}
      </aside>

      {/* Main content */}
      <main style={styles.main}>
        <header style={styles.topbar}>
          <h2 style={styles.pageTitle}>
            {(() => { const I = NAV_ITEMS.find((n) => n.id === activeNav)?.Icon; return I ? <I size={20} strokeWidth={1.75} style={{ marginRight: 8, verticalAlign: 'middle' }} /> : null })()}
            {NAV_ITEMS.find((n) => n.id === activeNav)?.label}
          </h2>
        </header>

        <div style={styles.content}>
          {activeNav === 'overview'      && <OverviewCards setActiveNav={setActiveNav} />}
          {activeNav === 'analytics'     && <AnalyticsPage />}
          {activeNav === 'users'         && <UsersPage />}
          {activeNav === 'topics'        && <TopicsPage />}
          {activeNav === 'lessons'       && <LessonsPage />}
          {activeNav === 'questions'     && <QuestionsPage />}
          {activeNav === 'snippets'      && <CodeSnippetsPage />}
          {activeNav === 'qa'            && <QaManagementPage />}
          {activeNav === 'leaderboard'   && <LeaderboardPage />}
          {activeNav === 'achievements'  && <AchievementsPage />}
          {activeNav === 'notifications' && <NotificationsPage />}
          {activeNav === 'ai'            && <AiSettingsPage />}
          {activeNav === 'subscription'  && <SubscriptionPage />}
          {activeNav === 'settings'      && <SettingsPage />}
        </div>
      </main>

      {/* Logout Modal */}
      {showLogoutModal && (
        <div style={styles.overlay}>
          <div style={styles.modal}>
            <div style={styles.modalHeader}>
              <h3 style={styles.modalTitle}>Đăng xuất</h3>
              <button onClick={() => setShowLogoutModal(false)} style={styles.modalClose}><X size={16}/></button>
            </div>
            <div style={styles.modalBody}>
              <p style={{ color: '#6b7280', margin: 0 }}>
                Bạn có chắc muốn đăng xuất không?
              </p>
            </div>
            <div style={styles.modalFooter}>
              <button onClick={() => setShowLogoutModal(false)} style={styles.cancelBtn}>
                Huỷ
              </button>
              <button onClick={handleLogout} style={styles.confirmBtn}>
                Đăng xuất
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

// ─── Overview Cards ────────────────────────────────────────────────────────

function OverviewCards({ setActiveNav }) {
  const [stats, setStats] = useState({
    totalUsers: '…', activeUsers: '…', admins: '…', disabled: '…',
    totalTopics: '…', totalLessons: '…', totalQuestions: '…', totalSnippets: '…',
  })
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    Promise.allSettled([
      usersApi.list(1000),
      topicsApi.list(),
      lessonsApi.list(),
      questionsApi.count(),
      codeSnippetsApi.list(),
    ]).then(([usersRes, topicsRes, lessonsRes, qRes, snipRes]) => {
      const users    = usersRes.status  === 'fulfilled' ? (usersRes.value  ?? []) : []
      const topics   = topicsRes.status === 'fulfilled' ? (topicsRes.value ?? []) : []
      const lessons  = lessonsRes.status === 'fulfilled' ? (lessonsRes.value ?? []) : []
      const snippets = snipRes.status   === 'fulfilled' ? (snipRes.value   ?? []) : []
      const qCount   = qRes.status      === 'fulfilled' ? (qRes.value      ?? 0)  : 0
      const nonAdmins = users.filter((u) => !u.isAdmin)
      setStats({
        totalUsers:     nonAdmins.length,
        activeUsers:    nonAdmins.filter((u) => !u.disabled).length,
        admins:         users.filter((u) => u.isAdmin).length,
        disabled:       nonAdmins.filter((u) => u.disabled).length,
        totalTopics:    topics.length,
        totalLessons:   lessons.length,
        totalQuestions: qCount,
        totalSnippets:  snippets.length,
      })
    }).finally(() => setLoading(false))
  }, [])

  const cards = [
    { label: 'Tổng người dùng',  value: loading ? '…' : stats.totalUsers,    Icon: Users,       color: '#e8f0fe', iconColor: '#3b82f6' },
    { label: 'Chủ đề',           value: loading ? '…' : stats.totalTopics,   Icon: BookOpen,    color: '#fef9c3', iconColor: '#ca8a04' },
    { label: 'Bài học',          value: loading ? '…' : stats.totalLessons,  Icon: GraduationCap, color: '#f3e8ff', iconColor: '#9333ea' },
    { label: 'Câu hỏi Quiz',     value: loading ? '…' : stats.totalQuestions,Icon: HelpCircle,  color: '#ecfdf5', iconColor: '#16a34a' },
    { label: 'Demo Code',        value: loading ? '…' : stats.totalSnippets, Icon: Code2,       color: '#fffbeb', iconColor: '#d97706' },
    { label: 'Tài khoản Admin',  value: loading ? '…' : stats.admins,        Icon: ShieldCheck, color: '#ede9fe', iconColor: '#7c3aed' },
  ]

  return (
    <div>
      <div style={styles.cards}>
        {cards.map((c) => (
          <div key={c.label} style={{ ...styles.card, background: c.color }}>
            <c.Icon size={32} color={c.iconColor} strokeWidth={1.75} />
            <p style={styles.cardValue}>{c.value}</p>
            <p style={styles.cardLabel}>{c.label}</p>
          </div>
        ))}
      </div>

      <div style={styles.quickActions}>
        <h3 style={{ margin: '0 0 12px', fontSize: 16, color: '#1e293b' }}>Truy cập nhanh</h3>
        <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
          <QuickBtn label="Quản lý người dùng" Icon={Users}       iconColor="#3b82f6" desc="Thêm, sửa, xoá, khoá tài khoản"  color="#e8f0fe" onClick={() => setActiveNav('users')} />
          <QuickBtn label="Chủ đề"             Icon={BookOpen}    iconColor="#ca8a04" desc="Quản lý chủ đề học tập"           color="#fef9c3" onClick={() => setActiveNav('topics')} />
          <QuickBtn label="Bài học"            Icon={GraduationCap} iconColor="#9333ea" desc="Quản lý bài học theo chủ đề"   color="#f3e8ff" onClick={() => setActiveNav('lessons')} />
          <QuickBtn label="Câu hỏi Quiz"       Icon={HelpCircle}  iconColor="#16a34a" desc="Quiz theo từng bài học"           color="#ecfdf5" onClick={() => setActiveNav('questions')} />
          <QuickBtn label="Gửi thông báo"      Icon={Bell}        iconColor="#ea580c" desc="Push notification đến người dùng" color="#fff7ed" onClick={() => setActiveNav('notifications')} />
        </div>
      </div>
    </div>
  )
}

function QuickBtn({ Icon, iconColor, label, desc, color, onClick }) {
  return (
    <div
      onClick={onClick}
      style={{ background: color, padding: '16px 20px', borderRadius: 12, minWidth: 180, cursor: 'pointer', transition: 'opacity 0.15s' }}
      onMouseEnter={e => e.currentTarget.style.opacity = '0.8'}
      onMouseLeave={e => e.currentTarget.style.opacity = '1'}
    >
      <div style={{ marginBottom: 8 }}><Icon size={24} color={iconColor} strokeWidth={1.75} /></div>
      <div style={{ fontWeight: 700, color: '#1e293b', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 12, color: '#64748b' }}>{desc}</div>
    </div>
  )
}

// ─── Styles ────────────────────────────────────────────────────────────────

const styles = {
  layout: { display: 'flex', height: '100vh', fontFamily: 'system-ui, sans-serif' },
  sidebar: {
    height: '100vh',
    background: '#1e293b',
    color: '#fff',
    display: 'flex',
    flexDirection: 'column',
    flexShrink: 0,
    overflow: 'hidden',
    transition: 'width 0.22s ease',
    position: 'relative',
  },
  sidebarHeader: {
    padding: '24px 20px',
    display: 'flex',
    alignItems: 'center',
    gap: 10,
    borderBottom: '1px solid #334155',
  },
  sidebarIcon: { fontSize: 24 },
  sidebarTitle: { fontWeight: 700, fontSize: 18 },
  version: { textAlign: 'center', fontSize: 11, color: '#475569', padding: '8px 0' },
  nav: { flex: 1, padding: '16px 12px', display: 'flex', flexDirection: 'column', gap: 4, overflowY: 'auto' },
  navItem: {
    display: 'flex',
    alignItems: 'center',
    gap: 10,
    padding: '10px 12px',
    borderRadius: 8,
    border: 'none',
    background: 'transparent',
    color: '#94a3b8',
    cursor: 'pointer',
    fontSize: 14,
    width: '100%',
    textAlign: 'left',
    transition: 'all 0.15s',
  },
  navItemActive: { background: '#1a73e8', color: '#fff' },
  sidebarFooter: {
    padding: '16px',
    borderTop: '1px solid #334155',
    display: 'flex',
    alignItems: 'center',
    gap: 8,
  },
  userInfo: { display: 'flex', alignItems: 'center', gap: 10, flex: 1, overflow: 'hidden' },
  avatar: {
    width: 36,
    height: 36,
    borderRadius: '50%',
    background: '#1a73e8',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontWeight: 700,
    flexShrink: 0,
  },
  userText: { overflow: 'hidden' },
  userEmail: { margin: 0, fontSize: 12, color: '#e2e8f0', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' },
  userRole: { margin: 0, fontSize: 11, color: '#64748b' },
  logoutBtn: { background: 'transparent', border: 'none', cursor: 'pointer', fontSize: 18, flexShrink: 0 },
  main: { flex: 1, display: 'flex', flexDirection: 'column', overflow: 'auto', background: '#f8fafc' },
  topbar: { padding: '18px 28px', borderBottom: '1px solid #e2e8f0', background: '#fff' },
  pageTitle: { margin: 0, fontSize: 20, fontWeight: 700, color: '#1e293b', display: 'flex', alignItems: 'center', gap: 8 },
  content: { padding: 28, flex: 1, overflowY: 'auto' },
  cards: { display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: 16, marginBottom: 28 },
  card: { borderRadius: 12, padding: 24, display: 'flex', flexDirection: 'column', gap: 6 },
  cardValue: { margin: 0, fontSize: 32, fontWeight: 700, color: '#1e293b' },
  cardLabel: { margin: 0, fontSize: 13, color: '#64748b' },
  quickActions: { background: '#fff', borderRadius: 12, border: '1px solid #e2e8f0', padding: 20 },
  overlay: {
    position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.4)',
    display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100,
  },
  modal: { background: '#fff', borderRadius: 14, width: 340, maxWidth: '90vw', display: 'flex', flexDirection: 'column', overflow: 'hidden' },
  modalHeader: { padding: '18px 24px', borderBottom: '1px solid #e2e8f0', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexShrink: 0 },
  modalTitle: { margin: 0, fontSize: 18, fontWeight: 700, color: '#1e293b' },
  modalBody: { padding: '20px 24px', overflowY: 'auto', flex: 1 },
  modalFooter: { padding: '14px 24px', borderTop: '1px solid #e2e8f0', display: 'flex', justifyContent: 'flex-end', gap: 12, flexShrink: 0 },
  modalClose: { background: 'none', border: 'none', cursor: 'pointer', fontSize: 20, color: '#94a3b8', padding: '2px 4px', lineHeight: 1, borderRadius: 4 },
  cancelBtn: { padding: '8px 20px', border: '1.5px solid #d1d5db', borderRadius: 8, background: '#fff', cursor: 'pointer', fontWeight: 500 },
  confirmBtn: { padding: '8px 20px', border: 'none', borderRadius: 8, background: '#dc2626', color: '#fff', cursor: 'pointer', fontWeight: 500 },
}
