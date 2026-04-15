import { Navigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'

export default function PrivateRoute({ children }) {
  const { user } = useAuth()

  // Đang kiểm tra trạng thái auth
  if (user === undefined) {
    return (
      <div style={styles.loader}>
        <div style={styles.spinner} />
      </div>
    )
  }

  // Chưa đăng nhập → về trang login
  if (!user) {
    return <Navigate to="/login" replace />
  }

  return children
}

const styles = {
  loader: {
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    height: '100vh',
  },
  spinner: {
    width: 40,
    height: 40,
    border: '4px solid #e5e7eb',
    borderTop: '4px solid #1a73e8',
    borderRadius: '50%',
    animation: 'spin 0.8s linear infinite',
  },
}
