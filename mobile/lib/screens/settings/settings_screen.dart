import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/app_theme.dart';
import '../../providers/theme_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';
import '../login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService();
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  String _baseUrl = 'https://datn-backend.onrender.com';
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    final user = FirebaseAuth.instance.currentUser;
    _nameController.text = user?.displayName ?? '';
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _baseUrl = prefs.getString('api_base_url') ?? 'https://datn-backend.onrender.com';
      _urlController.text = _baseUrl;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('sound_enabled', _soundEnabled);
  }

  Future<void> _updateBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', _urlController.text.trim());
    setState(() => _baseUrl = _urlController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật địa chỉ server'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textGray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        elevation: 0,
        title: const Text('Cài đặt', style: AppTextStyles.heading3),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(context, 'Tài khoản', [
            _buildInfoTile(
              icon: Icons.person_outline,
              label: 'Tên hiển thị',
              value: user?.displayName ?? 'Chưa đặt tên',
              onTap: () => _showEditNameDialog(),
            ),
            _buildInfoTile(
              icon: Icons.email_outlined,
              label: 'Email',
              value: user?.email ?? '',
            ),
          ]),
          const SizedBox(height: 16),
          _buildSection(context, 'Giao diện', [
            _buildThemeTile(),
          ]),
          const SizedBox(height: 16),
          _buildSection(context, 'Thông báo', [
            _buildSwitchTile(
              icon: Icons.notifications_outlined,
              label: 'Nhận thông báo',
              value: _notificationsEnabled,
              onChanged: (v) {
                setState(() => _notificationsEnabled = v);
                _savePrefs();
              },
            ),
            _buildSwitchTile(
              icon: Icons.volume_up_outlined,
              label: 'Âm thanh',
              value: _soundEnabled,
              onChanged: (v) {
                setState(() => _soundEnabled = v);
                _savePrefs();
              },
            ),
          ]),
          const SizedBox(height: 16),
          _buildSection(context, 'Nhà phát triển', [
            _buildUrlTile(),
          ]),
          const SizedBox(height: 16),
          _buildSection(context, 'Ứng dụng', [
            _buildInfoTile(
              icon: Icons.info_outline,
              label: 'Phiên bản',
              value: '1.0.0',
            ),
            _buildInfoTile(
              icon: Icons.description_outlined,
              label: 'Điều khoản sử dụng',
              onTap: () => _showTextDialog(
                title: 'Điều khoản sử dụng',
                content:
                    'Bằng cách sử dụng JavaLearn, bạn đồng ý:\n\n'
                    '• Sử dụng ứng dụng cho mục đích học tập cá nhân.\n'
                    '• Không chia sẻ tài khoản với người khác.\n'
                    '• Không phát tán nội dung vi phạm pháp luật trên Q&A.\n'
                    '• Chúng tôi có quyền tạm khóa tài khoản vi phạm quy định.\n\n'
                    'Ứng dụng được phát triển phục vụ mục đích học thuật (DATN).',
              ),
            ),
            _buildInfoTile(
              icon: Icons.privacy_tip_outlined,
              label: 'Chính sách bảo mật',
              onTap: () => _showTextDialog(
                title: 'Chính sách bảo mật',
                content:
                    'JavaLearn thu thập và sử dụng dữ liệu như sau:\n\n'
                    '• Email và tên hiển thị: dùng để xác thực và hiển thị hồ sơ.\n'
                    '• Tiến độ học tập: lưu trên server để đồng bộ giữa các thiết bị.\n'
                    '• FCM token: dùng để gửi thông báo học tập.\n\n'
                    'Chúng tôi không bán dữ liệu cá nhân cho bên thứ ba.\n'
                    'Dữ liệu được bảo vệ bằng Firebase Authentication.',
              ),
            ),
          ]),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Đăng xuất', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textGray,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(
            children: List.generate(children.length, (i) {
              return Column(
                children: [
                  children[i],
                  if (i < children.length - 1)
                    Divider(height: 1, color: context.borderColor, indent: 56),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    String? value,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(label, style: AppTextStyles.bodyLarge),
      subtitle: value != null
          ? Text(value, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textGray))
          : null,
      trailing: onTap != null
          ? const Icon(Icons.chevron_right, color: AppColors.textGray)
          : null,
      onTap: onTap,
    );
  }

  Widget _buildThemeTile() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final isDark = themeProvider.isDark;
        return ListTile(
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: isDark ? AppColors.secondaryLight : AppColors.streakOrange,
              size: 20,
            ),
          ),
          title: Text(
            isDark ? 'Giao diện tối' : 'Giao diện sáng',
            style: AppTextStyles.bodyLarge,
          ),
          subtitle: Text(
            isDark ? 'Nhấn để chuyển sang sáng' : 'Nhấn để chuyển sang tối',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textGray),
          ),
          trailing: GestureDetector(
            onTap: () => themeProvider.toggle(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 52,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: isDark ? AppColors.primary : AppColors.border,
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        size: 12,
                        color: isDark ? AppColors.primary : AppColors.streakOrange,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          onTap: () => themeProvider.toggle(),
        );
      },
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(label, style: AppTextStyles.bodyLarge),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary,
      ),
    );
  }

  Widget _buildUrlTile() {
    return Builder(
      builder: (context) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.dns_outlined, color: AppColors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Địa chỉ server API', style: AppTextStyles.bodyLarge),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'https://...',
                    hintStyle: const TextStyle(color: AppColors.textGray),
                    filled: true,
                    fillColor: context.bgColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.borderColor),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _updateBaseUrl,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Text('Lưu'),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  void _showTextDialog({required String title, required String content}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(content, style: const TextStyle(height: 1.6)),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(80, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cập nhật tên'),
        content: TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Tên hiển thị',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textGray)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = _nameController.text.trim();
              if (name.isNotEmpty) {
                await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
                if (!mounted) return;
                final provider = context.read<UserProvider>();
                final messenger = ScaffoldMessenger.of(context);
                provider.refreshStats();
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Đã cập nhật tên'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
