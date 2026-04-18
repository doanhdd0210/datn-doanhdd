import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';
import '../settings/settings_screen.dart';
import 'stats_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer<UserProvider>(
          builder: (context, provider, _) {
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                    child: _buildHero(context, user, provider)),
                SliverToBoxAdapter(child: _buildStatCards(provider)),
                SliverToBoxAdapter(
                    child: _buildWeeklyStreak(provider)),
                SliverToBoxAdapter(
                    child: _buildMenuSection(context)),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────

  Widget _buildHero(
      BuildContext context, User? user, UserProvider provider) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Hồ sơ', style: AppTextStyles.heading2),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SettingsScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.settings_rounded,
                      size: 20, color: AppColors.textGray),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Avatar with ring
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: AppColors.surface,
                  child: CircleAvatar(
                    radius: 43,
                    backgroundColor:
                        AppColors.primary.withOpacity(0.2),
                    child: user?.photoURL != null
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: user!.photoURL!,
                              width: 86,
                              height: 86,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  _avatarText(user),
                            ),
                          )
                        : _avatarText(user),
                  ),
                ),
              ),
              // Level badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.xpGold,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  'Lv.${_calcLevel(provider.totalXp)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            user?.displayName ?? 'Người học Java',
            style: AppTextStyles.heading3,
          ),
          const SizedBox(height: 4),
          Text(user?.email ?? '', style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }

  Widget _avatarText(User? user) {
    return Text(
      (user?.displayName?.isNotEmpty == true
              ? user!.displayName![0]
              : 'J')
          .toUpperCase(),
      style: const TextStyle(
        fontSize: 38,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    );
  }

  int _calcLevel(int xp) => (xp / 100).floor() + 1;

  // ── Stat Cards ────────────────────────────────────────────────────────────

  Widget _buildStatCards(UserProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          _StatCard(
            icon: '⚡',
            value: provider.totalXp.toString(),
            label: 'Tổng XP',
            color: AppColors.xpGold,
            bgColor: AppColors.surface,
          ),
          const SizedBox(width: 10),
          _StatCard(
            icon: '🔥',
            value: provider.streak.toString(),
            label: 'Chuỗi ngày',
            color: AppColors.streakOrange,
            bgColor: AppColors.surface,
          ),
          const SizedBox(width: 10),
          _StatCard(
            icon: '📚',
            value: provider.lessonsCompleted.toString(),
            label: 'Bài học',
            color: AppColors.primary,
            bgColor: AppColors.surface,
          ),
        ],
      ),
    );
  }

  // ── Weekly Streak Calendar ────────────────────────────────────────────────

  Widget _buildWeeklyStreak(UserProvider provider) {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final today = DateTime.now().weekday - 1; // 0=Mon
    final streak = provider.streak.clamp(0, 7);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text('Chuỗi hàng tuần', style: AppTextStyles.labelBold),
              const Spacer(),
              Text(
                '${provider.streak} ngày',
                style: const TextStyle(
                  color: AppColors.streakOrange,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              final isToday = i == today;
              final isActive = i <= today && (today - i) < streak;
              return Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? AppColors.streakOrange
                          : isToday
                              ? AppColors.streakOrange.withOpacity(0.15)
                              : AppColors.surfaceElevated,
                      border: isToday && !isActive
                          ? Border.all(
                              color: AppColors.streakOrange, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        isActive ? '🔥' : days[i],
                        style: TextStyle(
                          fontSize: isActive ? 16 : 12,
                          color: isActive
                              ? Colors.white
                              : isToday
                                  ? AppColors.streakOrange
                                  : AppColors.textLight,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Menu ──────────────────────────────────────────────────────────────────

  Widget _buildMenuSection(BuildContext context) {
    final authService = AuthService();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: 'HỌC TẬP'),
          _MenuItem(
            icon: Icons.bar_chart_rounded,
            label: 'Thống kê học tập',
            color: AppColors.primary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StatsScreen()),
            ),
          ),
          const SizedBox(height: 16),
          _SectionLabel(label: 'TÀI KHOẢN'),
          _MenuItem(
            icon: Icons.settings_rounded,
            label: 'Cài đặt',
            color: AppColors.blue,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const SettingsScreen()),
            ),
          ),
          _MenuItem(
            icon: Icons.logout_rounded,
            label: 'Đăng xuất',
            color: AppColors.heartRed,
            textColor: AppColors.heartRed,
            onTap: () => _confirmSignOut(context, authService),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text('JavaLearn v1.0.0',
                style: AppTextStyles.bodySmall),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Đăng xuất?', style: AppTextStyles.heading4),
        content: const Text('Bạn sẽ quay lại màn hình đăng nhập.',
            style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await authService.signOut();
            },
            child: const Text('Đăng xuất',
                style: TextStyle(color: AppColors.heartRed)),
          ),
        ],
      ),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  final Color color;
  final Color bgColor;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              offset: const Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textGray,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textGray,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color? textColor;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.color,
    this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          label,
          style: AppTextStyles.labelBold.copyWith(color: textColor),
        ),
        trailing: const Icon(Icons.chevron_right_rounded,
            color: AppColors.textGray, size: 20),
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
