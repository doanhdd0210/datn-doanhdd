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
  bool _isLoadingLeaderboard = true;
  bool _isLoadingFriends = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLeaderboard();
    _loadFriends();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoadingLeaderboard = true);
    try {
      final data = await _api.getLeaderboard();
      if (mounted) {
        setState(() {
          _leaderboard = data;
          _isLoadingLeaderboard = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _leaderboard = _mockLeaderboard();
          _isLoadingLeaderboard = false;
        });
      }
    }
  }

  Future<void> _loadFriends() async {
    setState(() => _isLoadingFriends = true);
    try {
      final data = await _api.getFollowing();
      if (mounted) {
        setState(() {
          _following = data;
          _isLoadingFriends = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _following = [];
          _isLoadingFriends = false;
        });
      }
    }
  }

  List<LeaderboardEntry> _mockLeaderboard() {
    return List.generate(
      10,
      (i) => LeaderboardEntry(
        userId: 'user_$i',
        name: [
          'Alice',
          'Bob',
          'Charlie',
          'Diana',
          'Eve',
          'Frank',
          'Grace',
          'Hank',
          'Iris',
          'Jack'
        ][i],
        avatar: '',
        totalXp: 1000 - i * 80,
        streak: 10 - i,
        rank: i + 1,
        isCurrentUser: i == 3,
      ),
    );
  }

  Future<void> _unfollow(UserFollow user) async {
    try {
      await _api.unfollowUser(user.userId);
      if (mounted) setState(() => _following.remove(user));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              behavior: SnackBarBehavior.floating),
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
            // Header
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ranking', style: AppTextStyles.heading2),
                  const SizedBox(height: 12),
                  TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 3,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textGray,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14),
                    unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    dividerColor: AppColors.border,
                    tabs: const [
                      Tab(text: 'Leaderboard'),
                      Tab(text: 'Following'),
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

    final top3 = _leaderboard.take(3).toList();
    final rest = _leaderboard.skip(3).toList();

    return RefreshIndicator(
      onRefresh: _loadLeaderboard,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          // Podium top 3
          if (top3.length >= 3) _buildPodium(top3),
          const SizedBox(height: 20),
          // Rest of the list
          ...rest.map((entry) => _LeaderboardRow(entry: entry)),
        ],
      ),
    );
  }

  Widget _buildPodium(List<LeaderboardEntry> top3) {
    // Order: #2 left, #1 center, #3 right
    final order = [top3[1], top3[0], top3[2]];
    final heights = [100.0, 120.0, 88.0];
    final crowns = ['🥈', '🥇', '🥉'];
    final colors = [
      const Color(0xFFC0C0C0), // silver
      AppColors.xpGold,         // gold
      const Color(0xFFCD7F32), // bronze
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.15),
            AppColors.secondary.withOpacity(0.1),
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
                // Crown
                Text(crowns[i], style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 6),
                // Avatar
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors[i],
                  ),
                  child: CircleAvatar(
                    radius: isCenter ? 30 : 24,
                    backgroundColor: colors[i].withOpacity(0.2),
                    backgroundImage: entry.avatar.isNotEmpty
                        ? CachedNetworkImageProvider(entry.avatar)
                        : null,
                    child: entry.avatar.isEmpty
                        ? Text(
                            entry.name.isNotEmpty
                                ? entry.name[0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: isCenter ? 22 : 18,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                // Name
                Text(
                  entry.name.split(' ').first,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: isCenter ? 14 : 12,
                    color: AppColors.textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // XP
                Text(
                  '${entry.totalXp} XP',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: colors[i],
                  ),
                ),
                const SizedBox(height: 8),
                // Podium block
                Container(
                  height: heights[i],
                  decoration: BoxDecoration(
                    color: colors[i].withOpacity(0.2),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                    border: Border.all(color: colors[i], width: 2),
                  ),
                  child: Center(
                    child: Text(
                      '#${entry.rank}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
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

  Widget _buildFriends() {
    if (_isLoadingFriends) return _buildShimmer();

    if (_following.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('👥', style: TextStyle(fontSize: 52)),
            SizedBox(height: 12),
            Text('No one followed yet', style: AppTextStyles.heading4),
            SizedBox(height: 8),
            Text('Follow users from the leaderboard!',
                style: AppTextStyles.bodySmall),
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
          return _FriendRow(
              user: user, onUnfollow: () => _unfollow(user));
        },
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

// ─── Leaderboard Row (#4+) ────────────────────────────────────────────────────

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;

  const _LeaderboardRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isMe = entry.isCurrentUser;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? AppColors.primary.withOpacity(0.12) : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe ? AppColors.primary.withOpacity(0.5) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 32,
            child: Text(
              '#${entry.rank}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: isMe ? AppColors.primaryDark : AppColors.textGray,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withOpacity(0.2),
            backgroundImage: entry.avatar.isNotEmpty
                ? CachedNetworkImageProvider(entry.avatar)
                : null,
            child: entry.avatar.isEmpty
                ? Text(
                    entry.name.isNotEmpty
                        ? entry.name[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          // Name + streak
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
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('You',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ],
                ),
                Text(
                  '🔥 ${entry.streak} day streak',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          // XP
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.totalXp}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppColors.xpGold,
                ),
              ),
              const Text('XP',
                  style: TextStyle(
                      fontSize: 10, color: AppColors.textGray)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Friend Row ───────────────────────────────────────────────────────────────

class _FriendRow extends StatelessWidget {
  final UserFollow user;
  final VoidCallback onUnfollow;

  const _FriendRow({required this.user, required this.onUnfollow});

  @override
  Widget build(BuildContext context) {
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
                    user.name.isNotEmpty
                        ? user.name[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: AppTextStyles.labelBold),
                Text(
                  '⚡ ${user.totalXp} XP  🔥 ${user.streak} days',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onUnfollow,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: const Text(
                'Unfollow',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textGray,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
