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
import '../../widgets/app_snackbar.dart';

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
    if (mounted) AppSnackBar.success(context, 'Đã cập nhật địa chỉ server');
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
            child: Text('Hủy', style: TextStyle(color: context.textSecondary)),
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
      // popUntil TRƯỚC signOut: tránh race condition context.mounted=false
      Navigator.of(context).popUntil((route) => route.isFirst);
      context.read<UserProvider>().reset();
      await _authService.signOut();
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
        backgroundColor: context.bgColor,
        foregroundColor: context.textPrimary,
        title: Text('Cài đặt',
            style: AppTextStyles.heading3.copyWith(color: context.textPrimary)),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(context, 'Tài khoản', [
            _buildInfoTile(
              context: context,
              icon: Icons.person_outline,
              label: 'Tên hiển thị',
              value: user?.displayName ?? 'Chưa đặt tên',
              onTap: () => _showEditNameDialog(),
            ),
            _buildInfoTile(
              context: context,
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
              context: context,
              icon: Icons.notifications_outlined,
              label: 'Nhận thông báo',
              value: _notificationsEnabled,
              onChanged: (v) {
                setState(() => _notificationsEnabled = v);
                _savePrefs();
              },
            ),
            _buildSwitchTile(
              context: context,
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
              context: context,
              icon: Icons.info_outline,
              label: 'Phiên bản',
              value: '1.0.0',
            ),
            _buildInfoTile(
              context: context,
              icon: Icons.description_outlined,
              label: 'Điều khoản sử dụng',
              onTap: () => _showTextDialog(
                title: 'Điều khoản sử dụng',
                content:
                    'Bằng cách sử dụng JavaUp, bạn đồng ý:\n\n'
                    '• Sử dụng ứng dụng cho mục đích học tập cá nhân.\n'
                    '• Không chia sẻ tài khoản với người khác.\n'
                    '• Không phát tán nội dung vi phạm pháp luật trên Q&A.\n'
                    '• Chúng tôi có quyền tạm khóa tài khoản vi phạm quy định.\n\n'
                    'Ứng dụng được phát triển phục vụ mục đích học thuật (DATN).',
              ),
            ),
            _buildInfoTile(
              context: context,
              icon: Icons.privacy_tip_outlined,
              label: 'Chính sách bảo mật',
              onTap: () => _showTextDialog(
                title: 'Chính sách bảo mật',
                content:
                    'JavaUp thu thập và sử dụng dữ liệu như sau:\n\n'
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
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: context.textSecondary,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.borderColor,
            ),
          ),
          child: Column(
            children: List.generate(children.length, (i) {
              return Column(
                children: [
                  children[i],
                  if (i < children.length - 1)
                    Divider(
                      height: 1,
                      color: context.borderColor,
                      indent: 56,
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile({
    required BuildContext context,
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
      title: Text(label, style: AppTextStyles.bodyLarge.copyWith(color: context.textPrimary)),
      subtitle: value != null
          ? Text(value, style: AppTextStyles.bodyMedium.copyWith(color: context.textSecondary))
          : null,
      trailing: onTap != null
          ? Icon(Icons.chevron_right, color: context.textSecondary)
          : null,
      onTap: onTap,
    );
  }

  Widget _buildThemeTile() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      themeProvider.mode == ThemeMode.dark
                          ? Icons.dark_mode_rounded
                          : themeProvider.mode == ThemeMode.light
                              ? Icons.light_mode_rounded
                              : Icons.brightness_auto_rounded,
                      color: AppColors.secondaryLight,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Giao diện', style: AppTextStyles.bodyLarge.copyWith(color: context.textPrimary)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildThemeOption(
                    context: context,
                    provider: themeProvider,
                    mode: ThemeMode.system,
                    icon: Icons.brightness_auto_rounded,
                    label: 'Hệ thống',
                  ),
                  const SizedBox(width: 8),
                  _buildThemeOption(
                    context: context,
                    provider: themeProvider,
                    mode: ThemeMode.light,
                    icon: Icons.light_mode_rounded,
                    label: 'Sáng',
                  ),
                  const SizedBox(width: 8),
                  _buildThemeOption(
                    context: context,
                    provider: themeProvider,
                    mode: ThemeMode.dark,
                    icon: Icons.dark_mode_rounded,
                    label: 'Tối',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required ThemeProvider provider,
    required ThemeMode mode,
    required IconData icon,
    required String label,
  }) {
    final isSelected = provider.mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => provider.setMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.15)
                : context.bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : context.borderColor,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected ? AppColors.primary : context.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected ? AppColors.primary : context.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required BuildContext context,
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
      title: Text(label, style: AppTextStyles.bodyLarge.copyWith(color: context.textPrimary)),
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
              Text('Địa chỉ server API', style: AppTextStyles.bodyLarge.copyWith(color: context.textPrimary)),
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
                    hintStyle: TextStyle(color: context.textSecondary),
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
                  minimumSize: Size.zero,
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
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cập nhật tên',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Tên hiển thị',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.textSecondary,
                        side: BorderSide(color: context.borderColor),
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Hủy', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final name = _nameController.text.trim();
                        if (name.isNotEmpty) {
                          await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
                          if (!mounted) return;
                          context.read<UserProvider>().refreshStats();
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          if (context.mounted) AppSnackBar.success(context, 'Đã cập nhật tên!');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Lưu', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
