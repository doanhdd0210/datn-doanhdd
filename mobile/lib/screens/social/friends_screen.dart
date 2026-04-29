import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/app_theme.dart';
import '../../models/leaderboard_entry.dart';
import '../../models/user_follow.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabController;

  List<LeaderboardEntry> _leaderboard = [];
  List<LeaderboardEntry> _weeklyLeaderboard = [];
  List<UserFollow> _following = [];
  Set<String> _followingIds = {};
  final Set<String> _loadingIds = {};
  bool _showWeekly = false;
  String? _leaderboardError;

  bool _isLoadingLeaderboard = true;
  bool _isLoadingFriends = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadLeaderboard(), _loadFriends()]);
  }

  Future<void> _loadLeaderboard() async {
    setState(() { _isLoadingLeaderboard = true; _leaderboardError = null; });
    try {
      final results = await Future.wait([
        _api.getLeaderboard(),
        _api.getWeeklyLeaderboard(),
      ]);
      if (mounted) {
        setState(() {
          _leaderboard = results[0];
          _weeklyLeaderboard = results[1];
          _isLoadingLeaderboard = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoadingLeaderboard = false; _leaderboardError = e.toString(); });
    }
  }

  Future<void> _loadFriends() async {
    setState(() => _isLoadingFriends = true);
    try {
      final data = await _api.getFollowing();
      if (mounted) {
        setState(() {
          _following = data;
          _followingIds = data.map((u) => u.userId).toSet();
          _isLoadingFriends = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingFriends = false);
    }
  }

  void _showUserProfile(LeaderboardEntry entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _UserProfileSheet(
        entry: entry,
        isFollowing: _followingIds.contains(entry.userId),
        isLoading: _loadingIds.contains(entry.userId),
        onToggleFollow: () {
          Navigator.pop(context);
          _toggleFollow(entry);
        },
      ),
    );
  }

  Future<void> _toggleFollow(LeaderboardEntry entry) async {
    if (_loadingIds.contains(entry.userId)) return;
    setState(() => _loadingIds.add(entry.userId));

    try {
      if (_followingIds.contains(entry.userId)) {
        await _api.unfollowUser(entry.userId);
        setState(() {
          _followingIds.remove(entry.userId);
          _following.removeWhere((u) => u.userId == entry.userId);
        });
      } else {
        await _api.followUser(entry.userId, entry.name, entry.avatar);
        if (mounted) {
          context.read<UserProvider>().markFollowed();
        }
        setState(() {
          _followingIds.add(entry.userId);
          _following.add(UserFollow(
            id: '',
            userId: entry.userId,
            name: entry.name,
            avatar: entry.avatar,
            totalXp: entry.totalXp,
            streak: entry.streak,
          ));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingIds.remove(entry.userId));
    }
  }

  Future<void> _unfollow(UserFollow user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Bỏ theo dõi'),
        content: Text('Bỏ theo dõi ${user.name}?'),
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
              minimumSize: const Size(80, 38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Bỏ theo'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (_loadingIds.contains(user.userId)) return;
    setState(() => _loadingIds.add(user.userId));
    try {
      await _api.unfollowUser(user.userId);
      if (mounted) {
        setState(() {
          _following.removeWhere((u) => u.userId == user.userId);
          _followingIds.remove(user.userId);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingIds.remove(user.userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: context.surfaceColor,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bảng xếp hạng', style: AppTextStyles.heading2),
                  const SizedBox(height: 12),
                  TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 3,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textGray,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    dividerColor: context.borderColor,
                    tabs: [
                      const Tab(text: 'Xếp hạng'),
                      Tab(text: 'Đang theo dõi (${_following.length})'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLeaderboard(),
                  _buildFriends(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboard() {
    if (_isLoadingLeaderboard) return _buildShimmer();

    if (_leaderboardError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text('Không tải được dữ liệu', style: AppTextStyles.heading4),
              const SizedBox(height: 8),
              Text(_leaderboardError!, style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadLeaderboard,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final data = _showWeekly ? _weeklyLeaderboard : _leaderboard;

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _buildLeaderboardToggle(),
          const SizedBox(height: 12),
          if (data.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 52)),
                  const SizedBox(height: 12),
                  Text(
                    _showWeekly ? 'Chưa có hoạt động tuần này' : 'Chưa có dữ liệu',
                    style: AppTextStyles.heading4,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Hoàn thành bài học để xuất hiện trên bảng xếp hạng!',
                    style: AppTextStyles.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else ...[
            if (data.length >= 3) _buildPodium(data.take(3).toList()),
            const SizedBox(height: 16),
            ...data.skip(3).map((e) => _buildLeaderboardRow(e)),
          ],
        ],
      ),
    );
  }

  Widget _buildLeaderboardToggle() {
    return Builder(
      builder: (context) => Container(
      height: 36,
      decoration: BoxDecoration(
        color: context.surfaceElevatedColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _ToggleTab(label: 'Tổng', active: !_showWeekly,
              onTap: () => setState(() => _showWeekly = false)),
          _ToggleTab(label: 'Tuần này', active: _showWeekly,
              onTap: () => setState(() => _showWeekly = true)),
        ],
      ),
      ),
    );
  }

  Widget _buildPodium(List<LeaderboardEntry> top3) {
    final order = [top3[1], top3[0], top3[2]];
    final heights = [100.0, 128.0, 84.0];
    final crowns = ['🥈', '🥇', '🥉'];
    final colors = [
      const Color(0xFFC0C0C0),
      AppColors.xpGold,
      const Color(0xFFCD7F32),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.secondary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (i) {
          final entry = order[i];
          final isCenter = i == 1;
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(crowns[i], style: const TextStyle(fontSize: 26)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _showUserProfile(entry),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: colors[i]),
                    child: CircleAvatar(
                      radius: isCenter ? 32 : 24,
                      backgroundColor: colors[i].withValues(alpha: 0.2),
                      backgroundImage: entry.avatar.isNotEmpty
                          ? CachedNetworkImageProvider(entry.avatar)
                          : null,
                      child: entry.avatar.isEmpty
                          ? Text(
                              entry.name.isNotEmpty ? entry.name[0].toUpperCase() : 'U',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: isCenter ? 24 : 18,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  entry.name.split(' ').last,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: isCenter ? 13 : 11,
                    color: AppColors.textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '⚡ ${entry.totalXp} XP',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: colors[i],
                  ),
                ),
                if (entry.streak > 0)
                  Text(
                    '🔥 ${entry.streak} ngày',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                      color: AppColors.textGray,
                    ),
                  ),
                const SizedBox(height: 8),
                Container(
                  height: heights[i],
                  decoration: BoxDecoration(
                    color: colors[i].withValues(alpha: 0.15),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                    border: Border.all(color: colors[i], width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      '${entry.rank}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        color: colors[i],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLeaderboardRow(LeaderboardEntry entry) {
    final isMe = entry.isCurrentUser;

    return GestureDetector(
      onTap: () => _showUserProfile(entry),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isMe ? AppColors.primary.withValues(alpha: 0.1) : context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe ? AppColors.primary.withValues(alpha: 0.4) : context.borderColor,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '#${entry.rank}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: isMe ? AppColors.primary : AppColors.textGray,
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
            backgroundImage: entry.avatar.isNotEmpty
                ? CachedNetworkImageProvider(entry.avatar)
                : null,
            child: entry.avatar.isEmpty
                ? Text(
                    entry.name.isNotEmpty ? entry.name[0].toUpperCase() : 'U',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.name,
                        style: AppTextStyles.labelBold,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text('Bạn',
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ],
                ),
                Text(
                  '🔥 ${entry.streak} ngày  ⚡ ${entry.totalXp} XP${entry.lessonsCompleted > 0 ? '  📚 ${entry.lessonsCompleted} bài' : ''}',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textGray, size: 18),
        ],
      ),
    ),
    );
  }

  Widget _buildFriends() {
    if (_isLoadingFriends) return _buildShimmer();

    if (_following.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('👥', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 12),
            const Text('Chưa theo dõi ai', style: AppTextStyles.heading4),
            const SizedBox(height: 8),
            const Text('Theo dõi người khác từ bảng xếp hạng!',
                style: AppTextStyles.bodySmall),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => _tabController.animateTo(0),
              child: const Text('Xem bảng xếp hạng'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFriends,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _following.length,
        itemBuilder: (context, index) {
          final user = _following[index];
          return _buildFriendRow(user);
        },
      ),
    );
  }

  Widget _buildFriendRow(UserFollow user) {
    final isLoading = _loadingIds.contains(user.userId);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
            backgroundImage: user.avatar.isNotEmpty
                ? CachedNetworkImageProvider(user.avatar)
                : null,
            child: user.avatar.isEmpty
                ? Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: AppTextStyles.labelBold),
                Text('⚡ ${user.totalXp} XP  🔥 ${user.streak} ngày',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          GestureDetector(
            onTap: isLoading ? null : () => _unfollow(user),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textGray),
                    )
                  : const Text(
                      'Bỏ theo',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textGray),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Builder(
      builder: (context) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(6, (_) {
          return Shimmer.fromColors(
            baseColor: context.surfaceColor,
            highlightColor: context.surfaceElevatedColor,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              height: 64,
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );
        }),
      ),
      ),
    );
  }
}

// ── User Profile Bottom Sheet ─────────────────────────────────────────────────

class _UserProfileSheet extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isFollowing;
  final bool isLoading;
  final VoidCallback onToggleFollow;

  const _UserProfileSheet({
    required this.entry,
    required this.isFollowing,
    required this.isLoading,
    required this.onToggleFollow,
  });

  @override
  Widget build(BuildContext context) {
    final rankColors = {
      1: AppColors.xpGold,
      2: const Color(0xFFC0C0C0),
      3: const Color(0xFFCD7F32),
    };
    final rankColor = rankColors[entry.rank] ?? AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: context.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Avatar
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: rankColor.withValues(alpha: 0.2),
                backgroundImage: entry.avatar.isNotEmpty
                    ? CachedNetworkImageProvider(entry.avatar)
                    : null,
                child: entry.avatar.isEmpty
                    ? Text(
                        entry.name.isNotEmpty ? entry.name[0].toUpperCase() : 'U',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: rankColor,
                        ),
                      )
                    : null,
              ),
              if (entry.rank <= 3)
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: rankColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.surfaceColor, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      '#${entry.rank}',
                      style: const TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Name
          Text(
            entry.name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
          if (entry.isCurrentUser) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Đây là bạn',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatChip(label: 'XP', value: '${entry.totalXp}', emoji: '⚡', color: AppColors.xpGold),
              Container(width: 1, height: 36, color: context.borderColor),
              _StatChip(label: 'Streak', value: '${entry.streak} ngày', emoji: '🔥', color: AppColors.orange),
              if (entry.lessonsCompleted > 0) ...[
                Container(width: 1, height: 36, color: context.borderColor),
                _StatChip(label: 'Bài học', value: '${entry.lessonsCompleted}', emoji: '📚', color: AppColors.primary),
              ],
            ],
          ),
          const SizedBox(height: 24),
          // Follow button — ẩn nếu là chính mình
          if (!entry.isCurrentUser)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : onToggleFollow,
                icon: isLoading
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(
                        isFollowing ? Icons.person_remove_rounded : Icons.person_add_rounded,
                        size: 18,
                      ),
                label: Text(isFollowing ? 'Bỏ theo dõi' : '+ Theo dõi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFollowing ? context.surfaceElevatedColor : AppColors.primary,
                  foregroundColor: isFollowing ? AppColors.red : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: isFollowing
                        ? BorderSide(color: AppColors.red.withValues(alpha: 0.4))
                        : BorderSide.none,
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  elevation: 0,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final String emoji;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.emoji,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: context.textSecondary, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// ── Toggle Tab ────────────────────────────────────────────────────────────────

class _ToggleTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToggleTab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppColors.textGray,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
