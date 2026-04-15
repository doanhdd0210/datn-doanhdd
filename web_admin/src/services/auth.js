import {
  signInWithEmailAndPassword,
  signOut as firebaseSignOut,
  onAuthStateChanged,
} from 'firebase/auth'
import { auth } from '../firebase'

// Đăng nhập bằng email/password (dành cho admin)
export async function signIn(email, password) {
  try {
    const credential = await signInWithEmailAndPassword(auth, email, password)
    return credential.user
  } catch (error) {
    throw new Error(mapAuthError(error.code))
  }
}

// Đăng xuất
export async function signOut() {
  await firebaseSignOut(auth)
}

// Lắng nghe trạng thái auth (trả về unsubscribe fn)
export function onAuthChange(callback) {
  return onAuthStateChanged(auth, callback)
}

// Map Firebase error code sang tiếng Việt
function mapAuthError(code) {
  const errors = {
    'auth/invalid-email': 'Email không hợp lệ.',
    'auth/user-disabled': 'Tài khoản đã bị vô hiệu hoá.',
    'auth/user-not-found': 'Không tìm thấy tài khoản.',
    'auth/wrong-password': 'Sai mật khẩu.',
    'auth/invalid-credential': 'Email hoặc mật khẩu không đúng.',
    'auth/too-many-requests': 'Quá nhiều lần thử. Vui lòng thử lại sau.',
  }
  return errors[code] || 'Đăng nhập thất bại. Vui lòng thử lại.'
}
