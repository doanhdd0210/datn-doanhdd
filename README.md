# DATN - Đồ án tốt nghiệp

Monorepo gồm 2 project riêng biệt, dùng chung 1 Firebase project.

## Cấu trúc

```
├── mobile/       # Flutter app (Android/iOS) — Google Sign-In
└── web_admin/    # React + Vite — Admin dashboard (email/password)
```

---

## 1. Cài đặt Firebase (làm 1 lần)

1. Tạo project tại [Firebase Console](https://console.firebase.google.com)
2. Vào **Authentication > Sign-in method**, bật:
   - **Google** (cho mobile)
   - **Email/Password** (cho web admin)
3. Tạo tài khoản admin: **Authentication > Users > Add user**

---

## 2. Mobile (Flutter)

### Cài đặt Firebase
```bash
cd mobile
dart pub global activate flutterfire_cli
flutterfire configure   # chọn project Firebase, tự tạo firebase_options.dart
flutter pub get
```

### Chạy
```bash
flutter run
```

---

## 3. Web Admin (React + Vite)

### Cài đặt
```bash
cd web_admin
cp .env.local.example .env.local   # điền config Firebase
npm install
```

### Chạy development
```bash
npm run dev   # http://localhost:3000
```

### Build production
```bash
npm run build
```
