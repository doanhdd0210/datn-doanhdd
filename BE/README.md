# DATN — Backend API (.NET 9)

REST API server dùng **Firebase Admin SDK** để quản lý người dùng, cấp quyền admin và gửi push notification FCM.

## Stack

| Layer | Tech |
|---|---|
| Runtime | .NET 9 |
| Framework | ASP.NET Core Web API |
| Firebase | FirebaseAdmin 3.x (Auth + FCM) |
| Database | Google Cloud Firestore |
| Docs | Swagger UI (`/swagger`) |

---

## Cấu trúc

```
BE/
├── DatnBackend.Api/
│   ├── Controllers/
│   │   ├── UsersController.cs        # CRUD người dùng
│   │   ├── AdminController.cs        # Quản lý admin
│   │   └── NotificationsController.cs # Push notifications
│   ├── Services/
│   │   ├── UserService.cs            # Firebase Auth + Firestore
│   │   └── NotificationService.cs   # FCM + lịch sử
│   ├── Models/                       # DTOs
│   ├── Middleware/
│   │   └── FirebaseAuthMiddleware.cs # Xác thực Firebase ID Token
│   ├── Program.cs
│   └── appsettings.json
├── Dockerfile
├── docker-compose.yml
└── README.md
```

---

## Cài đặt

### 1. Lấy Service Account JSON

1. Vào **Firebase Console** → Project Settings → Service Accounts
2. Click **Generate new private key** → tải file JSON
3. Copy vào `DatnBackend.Api/firebase-service-account.json`
4. Cập nhật `ProjectId` trong `appsettings.json`

### 2. Chạy với .NET SDK

```bash
# Cài .NET 9 SDK tại: https://dotnet.microsoft.com/download/dotnet/9.0
cd BE
dotnet restore
dotnet run --project DatnBackend.Api
```

Server chạy tại `http://localhost:5000` — Swagger UI tại `http://localhost:5000/swagger`

### 3. Chạy với Docker (không cần cài .NET)

```bash
cd BE
# Đảm bảo đã có firebase-service-account.json
docker compose up --build
```

---

## API Endpoints

### Users `/api/users`

| Method | Path | Mô tả |
|--------|------|--------|
| GET | `/api/users` | Danh sách tất cả users |
| GET | `/api/users/{uid}` | Chi tiết 1 user |
| POST | `/api/users` | Tạo user mới |
| PUT | `/api/users/{uid}` | Cập nhật user |
| DELETE | `/api/users/{uid}` | Xoá user |
| PATCH | `/api/users/{uid}/disable` | Khoá/mở khoá |
| PATCH | `/api/users/{uid}/admin` | Cấp/thu hồi admin |

### Admins `/api/admins`

| Method | Path | Mô tả |
|--------|------|--------|
| GET | `/api/admins` | Danh sách admins |
| POST | `/api/admins/{uid}` | Cấp quyền admin |
| DELETE | `/api/admins/{uid}` | Thu hồi quyền admin |

### Notifications `/api/notifications`

| Method | Path | Mô tả |
|--------|------|--------|
| POST | `/api/notifications/send` | Gửi thông báo |
| GET | `/api/notifications/history` | Lịch sử thông báo |
| POST | `/api/notifications/topic/subscribe` | Subscribe topic |
| POST | `/api/notifications/topic/unsubscribe` | Unsubscribe topic |

**Payload gửi thông báo:**
```json
{
  "title": "Tiêu đề",
  "body": "Nội dung",
  "imageUrl": "https://...",   // tuỳ chọn
  "broadcastAll": true          // hoặc uid / token / topic
}
```

---

## Xác thực

Tất cả endpoint (trừ `/health` và `/swagger`) yêu cầu:

```
Authorization: Bearer <Firebase ID Token>
```

Token phải thuộc tài khoản có custom claim `admin: true`.

**Cấp quyền admin lần đầu** (qua Firebase Console hoặc dùng script):
```bash
# Dùng Firebase CLI
firebase auth:set-custom-claims <uid> '{"admin": true}'
```

---

## Firestore Collections

| Collection | Mô tả |
|---|---|
| `users/{uid}` | Profile + FCM tokens của user |
| `notification_history` | Lịch sử thông báo đã gửi |

**Mobile app** cần ghi FCM token vào Firestore khi đăng nhập:
```dart
// Trong Flutter — sau khi lấy được FCM token
await FirebaseFirestore.instance.collection('users').doc(uid).update({
  'fcmTokens': FieldValue.arrayUnion([fcmToken]),
});
// Và subscribe topic "all" để nhận broadcast
await FirebaseMessaging.instance.subscribeToTopic('all');
```
