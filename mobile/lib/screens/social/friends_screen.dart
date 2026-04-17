import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/leaderboard_entry.dart';
import '../../models/user_follow.dart';
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
  List<UserFollow> _following = [];
  Set<String> _followingIds = {};
  Set<String> _loadingIds = {};

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
    setState(() => _isLoadingLeaderboard = true);
    try {
      final data = await _api.getLeaderboard();
      if (mounted) setState(() { _leaderboard = data; _isLoadingLeaderboard = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingLeaderboard = false);
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
    try {
      await _api.unfollowUser(user.userId);
      setState(() {
        _following.removeWhere((u) => u.userId == user.userId);
        _followingIds.remove(user.userId);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bảng xếp hạng', style: AppTextStyles.heading2),
                  const SizedBox(height: 12),
                  TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 3,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textGray,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    dividerColor: AppColors.border,
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

    if (_leaderboard.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🏆', style: TextStyle(fontSize: 52)),
            SizedBox(height: 12),
            Text('Chưa có dữ liệu', style: AppTextStyles.heading4),
          ],
        ),
      );
    }

    final top3 = _leaderboard.take(3).toList();
    final rest = _leaderboard.skip(3).toList();

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          if (top3.length >= 3) _buildPodium(top3),
          const SizedBox(height: 16),
          ...rest.map((entry) => _buildLeaderboardRow(entry)),
        ],
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
            AppColors.primary.withOpacity(0.12),
            AppColors.secondary.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
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
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: colors[i]),
                  child: CircleAvatar(
                    radius: isCenter ? 32 : 24,
                    backgroundColor: colors[i].withOpacity(0.2),
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
                const SizedBox(height: 8),
                Container(
                  height: heights[i],
                  decoration: BoxDecoration(
                    color: colors[i].withOpacity(0.15),
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
    final isFollowing = _followingIds.contains(entry.userId);
    final isLoading = _loadingIds.contains(entry.userId);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isMe ? AppColors.primary.withOpacity(0.1) : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe ? AppColors.primary.withOpacity(0.4) : AppColors.border,
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
            backgroundColor: AppColors.primary.withOpacity(0.2),
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
                Text('🔥 ${entry.streak} ngày  ⚡ ${entry.totalXp} XP',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          if (!isMe)
            GestureDetector(
              onTap: isLoading ? null : () => _toggleFollow(entry),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isFollowing ? AppColors.primary.withOpacity(0.1) : AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isFollowing ? AppColors.primary.withOpacity(0.4) : AppColors.primary,
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      )
                    : Text(
                        isFollowing ? 'Đang theo' : '+ Theo dõi',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isFollowing ? AppColors.primary : Colors.white,
                        ),
                      ),
              ),
            ),
        ],
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary.withOpacity(0.2),
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
            onTap: () => _unfollow(user),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: const Text(
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(6, (_) {
          return Shimmer.fromColors(
            baseColor: AppColors.surface,
            highlightColor: AppColors.surfaceElevated,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );
        }),
      ),
    );
  }
}
