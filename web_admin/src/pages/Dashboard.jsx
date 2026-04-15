import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { signOut } from '../services/auth'
import { useAuth } from '../context/AuthContext'
import { usersApi } from '../services/api'
import UsersPage from './UsersPage'
import NotificationsPage from './NotificationsPage'
import SettingsPage from './SettingsPage'

const NAV_ITEMS = [
  { id: 'overview',       label: 'Tổng quan',     icon: '📊' },
  { id: 'users',          label: 'Người dùng',    icon: '👥' },
  { id: 'notifications',  label: 'Thông báo',     icon: '🔔' },
  { id: 'settings',       label: 'Cài đặt',       icon: '⚙️' },
]

export default function Dashboard() {
  const { user } = useAuth()
  const navigate = useNavigate()
  const [activeNav, setActiveNav] = useState('overview')
  const [showLogoutModal, setShowLogoutModal] = useState(false)

  const handleLogout = async () => {
    await signOut()
    navigate('/login', { replace: true })
  }

  return (
    <div style={styles.layout}>
      {/* Sidebar */}
      <aside style={styles.sidebar}>
        <div style={styles.sidebarHeader}>
          <span style={styles.sidebarIcon}>🛡️</span>
          <span style={styles.sidebarTitle}>Admin Panel</span>
        </div>

        <nav style={styles.nav}>
          {NAV_ITEMS.map((item) => (
            <button
              key={item.id}
              onClick={() => setActiveNav(item.id)}
              style={{
                ...styles.navItem,
                ...(activeNav === item.id ? styles.navItemActive : {}),
              }}
            >
              <span>{item.icon}</span>
              <span>{item.label}</span>
            </button>
          ))}
        </nav>

        <div style={styles.sidebarFooter}>
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
            🚪
          </button>
        </div>
      </aside>

      {/* Main content */}
      <main style={styles.main}>
        <header style={styles.topbar}>
          <h2 style={styles.pageTitle}>
            {NAV_ITEMS.find((n) => n.id === activeNav)?.icon}{' '}
            {NAV_ITEMS.find((n) => n.id === activeNav)?.label}
          </h2>
        </header>

        <div style={styles.content}>
          {activeNav === 'overview'      && <OverviewCards />}
          {activeNav === 'users'         && <UsersPage />}
          {activeNav === 'notifications' && <NotificationsPage />}
          {activeNav === 'settings'      && <SettingsPage />}
        </div>
      </main>

      {/* Logout Modal */}
      {showLogoutModal && (
        <div style={styles.overlay}>
          <div style={styles.modal}>
            <h3 style={{ margin: '0 0 8px' }}>Đăng xuất</h3>
            <p style={{ color: '#6b7280', margin: '0 0 24px' }}>
              Bạn có chắc muốn đăng xuất không?
            </p>
            <div style={styles.modalActions}>
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

function OverviewCards() {
  const [stats, setStats] = useState({ total: '…', admins: '…', disabled: '…', active: '…' })
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    usersApi.list(1000)
      .then((users) => {
        setStats({
          total: users.length,
          active: users.filter((u) => !u.disabled).length,
          admins: users.filter((u) => u.isAdmin).length,
          disabled: users.filter((u) => u.disabled).length,
        })
      })
      .catch(() => setStats({ total: 'Lỗi', admins: '—', disabled: '—', active: '—' }))
      .finally(() => setLoading(false))
  }, [])

  const cards = [
    { label: 'Tổng người dùng',  value: loading ? '…' : stats.total,    icon: '👥', color: '#e8f0fe' },
    { label: 'Đang hoạt động',   value: loading ? '…' : stats.active,   icon: '✅', color: '#e6f4ea' },
    { label: 'Tài khoản Admin',  value: loading ? '…' : stats.admins,   icon: '🛡️', color: '#ede9fe' },
    { label: 'Bị khoá',         value: loading ? '…' : stats.disabled,  icon: '🔒', color: '#fce8e6' },
  ]

  return (
    <div>
      <div style={styles.cards}>
        {cards.map((c) => (
          <div key={c.label} style={{ ...styles.card, background: c.color }}>
            <span style={{ fontSize: 32 }}>{c.icon}</span>
            <p style={styles.cardValue}>{c.value}</p>
            <p style={styles.cardLabel}>{c.label}</p>
          </div>
        ))}
      </div>

      <div style={styles.quickActions}>
        <h3 style={{ margin: '0 0 12px', fontSize: 16, color: '#1e293b' }}>Truy cập nhanh</h3>
        <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
          <QuickBtn label="Quản lý người dùng" icon="👥" desc="Thêm, sửa, xoá, khoá tài khoản" color="#e8f0fe" />
          <QuickBtn label="Gửi thông báo"       icon="🔔" desc="Push notification đến người dùng" color="#fff7ed" />
        </div>
      </div>
    </div>
  )
}

function QuickBtn({ icon, label, desc, color }) {
  return (
    <div style={{ background: color, padding: '16px 20px', borderRadius: 12, minWidth: 200 }}>
      <div style={{ fontSize: 24, marginBottom: 6 }}>{icon}</div>
      <div style={{ fontWeight: 700, color: '#1e293b', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 12, color: '#64748b' }}>{desc}</div>
    </div>
  )
}

// ─── Styles ────────────────────────────────────────────────────────────────

const styles = {
  layout: { display: 'flex', height: '100vh', fontFamily: 'system-ui, sans-serif' },
  sidebar: {
    width: 240,
    background: '#1e293b',
    color: '#fff',
    display: 'flex',
    flexDirection: 'column',
    flexShrink: 0,
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
  nav: { flex: 1, padding: '16px 12px', display: 'flex', flexDirection: 'column', gap: 4 },
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
  modal: { background: '#fff', borderRadius: 12, padding: '28px 32px', width: 320 },
  modalActions: { display: 'flex', justifyContent: 'flex-end', gap: 12 },
  cancelBtn: { padding: '8px 20px', border: '1.5px solid #d1d5db', borderRadius: 8, background: '#fff', cursor: 'pointer', fontWeight: 500 },
  confirmBtn: { padding: '8px 20px', border: 'none', borderRadius: 8, background: '#dc2626', color: '#fff', cursor: 'pointer', fontWeight: 500 },
}
