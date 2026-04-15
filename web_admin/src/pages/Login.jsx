import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { signIn } from '../services/auth'

const SAVED_EMAIL_KEY = 'admin_saved_email'
const SAVED_PASS_KEY = 'admin_saved_pass'

export default function Login() {
  const navigate = useNavigate()
  const [form, setForm] = useState({ email: '', password: '' })
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const [showPassword, setShowPassword] = useState(false)
  const [rememberMe, setRememberMe] = useState(false)

  useEffect(() => {
    const savedEmail = localStorage.getItem(SAVED_EMAIL_KEY)
    const savedPass = localStorage.getItem(SAVED_PASS_KEY)
    if (savedEmail) {
      setForm({ email: savedEmail, password: savedPass ?? '' })
      setRememberMe(true)
    }
  }, [])

  const handleChange = (e) => {
    setForm((prev) => ({ ...prev, [e.target.name]: e.target.value }))
    setError('')
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (!form.email || !form.password) {
      setError('Vui lòng nhập đầy đủ thông tin.')
      return
    }
    setLoading(true)
    try {
      await signIn(form.email, form.password)
      if (rememberMe) {
        localStorage.setItem(SAVED_EMAIL_KEY, form.email)
        localStorage.setItem(SAVED_PASS_KEY, form.password)
      } else {
        localStorage.removeItem(SAVED_EMAIL_KEY)
        localStorage.removeItem(SAVED_PASS_KEY)
      }
      navigate('/', { replace: true })
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div style={styles.page}>
      <div style={styles.card}>
        {/* Header */}
        <div style={styles.header}>
          <div style={styles.iconWrapper}>
            <span style={styles.icon}>⚙️</span>
          </div>
          <h1 style={styles.title}>Admin Panel</h1>
          <p style={styles.subtitle}>Đăng nhập để quản trị hệ thống</p>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} style={styles.form}>
          <div style={styles.field}>
            <label style={styles.label}>Email</label>
            <input
              type="email"
              name="email"
              value={form.email}
              onChange={handleChange}
              placeholder="admin@example.com"
              style={styles.input}
              autoComplete="email"
            />
          </div>

          <div style={styles.field}>
            <label style={styles.label}>Mật khẩu</label>
            <div style={styles.passwordWrapper}>
              <input
                type={showPassword ? 'text' : 'password'}
                name="password"
                value={form.password}
                onChange={handleChange}
                placeholder="••••••••"
                style={{ ...styles.input, paddingRight: '44px' }}
                autoComplete="current-password"
              />
              <button
                type="button"
                onClick={() => setShowPassword((v) => !v)}
                style={styles.eyeBtn}
                tabIndex={-1}
              >
                {showPassword ? '🙈' : '👁️'}
              </button>
            </div>
          </div>

          <div style={styles.rememberRow}>
            <label style={styles.rememberLabel}>
              <input
                type="checkbox"
                checked={rememberMe}
                onChange={(e) => setRememberMe(e.target.checked)}
                style={{ marginRight: '6px', cursor: 'pointer' }}
              />
              Nhớ tài khoản
            </label>
          </div>

          {error && <p style={styles.error}>{error}</p>}

          <button type="submit" disabled={loading} style={styles.button}>
            {loading ? 'Đang đăng nhập...' : 'Đăng nhập'}
          </button>
        </form>
      </div>
    </div>
  )
}

const styles = {
  page: {
    minHeight: '100vh',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    background: 'linear-gradient(135deg, #1a73e8 0%, #0d47a1 100%)',
    padding: '16px',
  },
  card: {
    background: '#fff',
    borderRadius: '16px',
    padding: '40px 32px',
    width: '100%',
    maxWidth: '400px',
    boxShadow: '0 20px 60px rgba(0,0,0,0.15)',
  },
  header: {
    textAlign: 'center',
    marginBottom: '32px',
  },
  iconWrapper: {
    width: 64,
    height: 64,
    background: '#e8f0fe',
    borderRadius: '50%',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    margin: '0 auto 16px',
  },
  icon: { fontSize: 28 },
  title: {
    margin: '0 0 8px',
    fontSize: '24px',
    fontWeight: 700,
    color: '#1a1a1a',
  },
  subtitle: { margin: 0, color: '#6b7280', fontSize: '14px' },
  form: { display: 'flex', flexDirection: 'column', gap: '16px' },
  field: { display: 'flex', flexDirection: 'column', gap: '6px' },
  label: { fontSize: '14px', fontWeight: 500, color: '#374151' },
  input: {
    padding: '10px 14px',
    border: '1.5px solid #d1d5db',
    borderRadius: '8px',
    fontSize: '15px',
    outline: 'none',
    width: '100%',
    boxSizing: 'border-box',
    transition: 'border-color 0.2s',
  },
  passwordWrapper: {
    position: 'relative',
    display: 'flex',
    alignItems: 'center',
  },
  eyeBtn: {
    position: 'absolute',
    right: '12px',
    background: 'none',
    border: 'none',
    cursor: 'pointer',
    fontSize: '18px',
    padding: '0',
    lineHeight: 1,
  },
  rememberRow: {
    display: 'flex',
    alignItems: 'center',
  },
  rememberLabel: {
    display: 'flex',
    alignItems: 'center',
    fontSize: '14px',
    color: '#374151',
    cursor: 'pointer',
    userSelect: 'none',
  },
  error: {
    color: '#dc2626',
    fontSize: '13px',
    margin: 0,
    padding: '8px 12px',
    background: '#fef2f2',
    borderRadius: '6px',
  },
  button: {
    padding: '12px',
    background: '#1a73e8',
    color: '#fff',
    border: 'none',
    borderRadius: '8px',
    fontSize: '16px',
    fontWeight: 600,
    cursor: 'pointer',
    marginTop: '8px',
  },
}
