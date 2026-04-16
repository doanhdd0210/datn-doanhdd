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
                SliverToBoxAdapter(child: _buildHeader(context, user, provider)),
                SliverToBoxAdapter(child: _buildStatsRow(provider)),
                SliverToBoxAdapter(child: _buildMenuSection(context)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, User? user, UserProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Profile', style: AppTextStyles.heading2),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Avatar
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 3),
            ),
            child: CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.primary.withOpacity(0.2),
              child: user?.photoURL != null
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: user!.photoURL!,
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _defaultAvatar(user),
                      ),
                    )
                  : _defaultAvatar(user),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user?.displayName ?? 'Java Learner',
            style: AppTextStyles.heading3,
          ),
          const SizedBox(height: 4),
          Text(user?.email ?? '', style: AppTextStyles.bodySmall),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _defaultAvatar(User? user) {
    return Text(
      (user?.displayName?.isNotEmpty == true ? user!.displayName![0] : 'J').toUpperCase(),
      style: const TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildStatsRow(UserProvider provider) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                _StatCell(
                  value: provider.totalXp.toString(),
                  label: 'Total XP',
                  icon: '⚡',
                  color: AppColors.xpGold,
                ),
                _Divider(),
                _StatCell(
                  value: provider.streak.toString(),
                  label: 'Day Streak',
                  icon: '🔥',
                  color: AppColors.orange,
                ),
                _Divider(),
                _StatCell(
                  value: provider.lessonsCompleted.toString(),
                  label: 'Lessons',
                  icon: '📚',
                  color: AppColors.primary,
                ),
                _Divider(),
                _StatCell(
                  value: provider.rank,
                  label: 'Rank',
                  icon: '🏆',
                  color: AppColors.purple,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context) {
    final authService = AuthService();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _SectionLabel(label: 'Learning'),
          _MenuItem(
            icon: Icons.bar_chart_rounded,
            label: 'Learning Statistics',
            color: AppColors.primary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StatsScreen()),
            ),
          ),
          const SizedBox(height: 16),
          _SectionLabel(label: 'Account'),
          _MenuItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            color: AppColors.blue,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          _MenuItem(
            icon: Icons.logout_rounded,
            label: 'Sign Out',
            color: AppColors.red,
            textColor: AppColors.red,
            onTap: () => _confirmSignOut(context, authService),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'JavaLearn v1.0.0',
              style: AppTextStyles.bodySmall,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out?', style: AppTextStyles.heading4),
        content: const Text('You will be returned to the login screen.', style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await authService.signOut();
            },
            child: const Text('Sign Out', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final String icon;
  final Color color;

  const _StatCell({required this.value, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.heading4.copyWith(color: color)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 40, color: AppColors.border);
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(label, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
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
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(
          label,
          style: AppTextStyles.labelBold.copyWith(color: textColor),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textGray, size: 18),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
