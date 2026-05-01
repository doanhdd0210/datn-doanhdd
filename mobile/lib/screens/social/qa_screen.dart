import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/app_theme.dart';
import '../../models/qa_post.dart';
import '../../services/api_service.dart';
import 'qa_detail_screen.dart';
import 'create_qa_screen.dart';
import '../../widgets/app_loading.dart';

class QaScreen extends StatefulWidget {
  const QaScreen({super.key});

  @override
  State<QaScreen> createState() => _QaScreenState();
}

class _QaScreenState extends State<QaScreen> {
  final _api = ApiService();
  final _searchController = TextEditingController();
  List<QaPost> _posts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _filter = 'all';
  String _searchQuery = '';
  int _page = 1;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();
  Set<String> _upvotedPostIds = {};

  @override
  void initState() {
    super.initState();
    _loadUpvotedIds();
    _loadPosts();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUpvotedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('upvoted_posts') ?? [];
    if (mounted) setState(() => _upvotedPostIds = ids.toSet());
  }

  void _onUpvoteChanged(String postId, bool upvoted) {
    setState(() {
      if (upvoted) _upvotedPostIds.add(postId);
      else _upvotedPostIds.remove(postId);
    });
  }

  void _onScroll() {
    if (_searchQuery.isNotEmpty) return; // don't paginate while searching
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) _loadMore();
    }
  }

  Future<void> _loadPosts({bool reset = false}) async {
    if (reset) {
      setState(() { _page = 1; _posts = []; _hasMore = true; });
    }
    setState(() => _isLoading = reset ? true : _isLoading);
    try {
      final data = await _api.getQaPosts(page: _page);
      if (mounted) {
        setState(() {
          if (reset || _page == 1) {
            _posts = data;
          } else {
            _posts.addAll(data);
          }
          _hasMore = data.length >= 20;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _posts = _mockPosts();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() { _isLoadingMore = true; _page++; });
    try {
      final data = await _api.getQaPosts(page: _page);
      if (mounted) {
        setState(() {
          _posts.addAll(data);
          _hasMore = data.length >= 20;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  List<QaPost> _mockPosts() {
    return [
      QaPost(
        id: 'mock1',
        title: 'Sự khác nhau giữa == và .equals() trong Java?',
        content: 'Tôi bị nhầm lẫn khi nào dùng == vs .equals() để so sánh String.',
        authorId: 'user1',
        authorName: 'Alice',
        authorAvatar: '',
        tags: ['string', 'so sánh', 'cơ bản'],
        answerCount: 3,
        upvotes: 12,
        isSolved: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      QaPost(
        id: 'mock2',
        title: 'Garbage Collection trong Java hoạt động như thế nào?',
        content: 'Ai giải thích cơ chế GC của Java được không?',
        authorId: 'user2',
        authorName: 'Bob',
        authorAvatar: '',
        tags: ['memory', 'jvm', 'nâng cao'],
        answerCount: 0,
        upvotes: 5,
        isSolved: false,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }

  List<QaPost> get _filteredPosts {
    var result = _posts;

    // Apply tab filter
    if (_filter == 'unanswered') {
      result = result.where((p) => p.answerCount == 0).toList();
    } else if (_filter == 'solved') {
      result = result.where((p) => p.isSolved).toList();
    }

    // Apply search
    if (_searchQuery.isNotEmpty) {
      result = result.where((p) {
        final titleMatch = p.title.toLowerCase().contains(_searchQuery);
        final tagMatch = p.tags.any((t) => t.toLowerCase().contains(_searchQuery));
        final authorMatch = p.authorName.toLowerCase().contains(_searchQuery);
        return titleMatch || tagMatch || authorMatch;
      }).toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildFilterBar(),
            Expanded(
              child: _isLoading
                  ? _buildShimmer()
                  : RefreshIndicator(
                      onRefresh: () => _loadPosts(reset: true),
                      color: AppColors.primary,
                      child: _filteredPosts.isEmpty
                          ? _buildEmpty()
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                              itemCount: _filteredPosts.length + (_isLoadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _filteredPosts.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: AppLoadingCenter(),
                                  );
                                }
                                final post = _filteredPosts[index];
                                return _QaPostCard(
                                  post: post,
                                  initialUpvoted: _upvotedPostIds.contains(post.id),
                                  onUpvoteChanged: (v) => _onUpvoteChanged(post.id, v),
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => QaDetailScreen(post: post),
                                      ),
                                    );
                                    _loadPosts(reset: true);
                                  },
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        // extendBody=true nên cần bù thêm chiều cao bottom nav (64) + padding (20) + safe area
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 84,
        ),
        child: FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateQaScreen()),
            );
            _loadPosts(reset: true);
          },
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Đặt câu hỏi',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Q&A Cộng đồng', style: AppTextStyles.heading2),
          const SizedBox(height: 2),
          Text('Đặt câu hỏi, chia sẻ kiến thức', style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Builder(
      builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: AppColors.textDark, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Tìm kiếm câu hỏi, tag...',
          hintStyle: const TextStyle(color: AppColors.textGray, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textGray, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: const Icon(Icons.close_rounded, color: AppColors.textGray, size: 18),
                )
              : null,
          filled: true,
          fillColor: context.surfaceColor,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = [
      ('all', 'Tất cả'),
      ('unanswered', 'Chưa trả lời'),
      ('solved', 'Đã giải quyết'),
    ];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: filters.map((f) {
          final isSelected = _filter == f.$1;
          return GestureDetector(
            onTap: () => setState(() => _filter = f.$1),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : context.surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? AppColors.primary : context.borderColor),
              ),
              child: Text(
                f.$2,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textGray,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmpty() {
    final isSearch = _searchQuery.isNotEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(isSearch ? '🔍' : '💬', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            isSearch ? 'Không tìm thấy kết quả' : 'Chưa có câu hỏi nào',
            style: AppTextStyles.heading4,
          ),
          const SizedBox(height: 6),
          Text(
            isSearch ? 'Thử từ khoá khác' : 'Hãy là người đặt câu hỏi đầu tiên!',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Builder(
      builder: (context) => ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: 5,
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: context.surfaceColor,
          highlightColor: context.surfaceElevatedColor,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 100,
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

// ── QA Post Card ──────────────────────────────────────────────────────────────

class _QaPostCard extends StatefulWidget {
  final QaPost post;
  final VoidCallback onTap;
  final bool initialUpvoted;
  final ValueChanged<bool> onUpvoteChanged;

  const _QaPostCard({
    required this.post,
    required this.onTap,
    required this.initialUpvoted,
    required this.onUpvoteChanged,
  });

  @override
  State<_QaPostCard> createState() => _QaPostCardState();
}

class _QaPostCardState extends State<_QaPostCard> {
  final _api = ApiService();
  late bool _upvoted;
  late int _upvoteCount;
  bool _isUpvoting = false;

  @override
  void initState() {
    super.initState();
    _upvoted = widget.initialUpvoted;
    _upvoteCount = widget.post.upvotes;
  }

  @override
  void didUpdateWidget(_QaPostCard old) {
    super.didUpdateWidget(old);
    if (old.initialUpvoted != widget.initialUpvoted && !_isUpvoting) {
      _upvoted = widget.initialUpvoted;
    }
  }

  Future<void> _toggleUpvote() async {
    if (_isUpvoting) return;
    final wasUpvoted = _upvoted;
    _isUpvoting = true;
    setState(() {
      _upvoted = !wasUpvoted;
      _upvoteCount += wasUpvoted ? -1 : 1;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList('upvoted_posts') ?? [];
      if (wasUpvoted) {
        await _api.unupvotePost(widget.post.id);
        ids.remove(widget.post.id);
      } else {
        await _api.upvotePost(widget.post.id);
        ids.add(widget.post.id);
      }
      await prefs.setStringList('upvoted_posts', ids);
      widget.onUpvoteChanged(!wasUpvoted);
    } catch (_) {
      if (mounted) setState(() { _upvoted = wasUpvoted; _upvoteCount += wasUpvoted ? 1 : -1; });
    } finally {
      _isUpvoting = false;
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 7) return DateFormat('d MMM').format(date);
    if (diff.inDays > 0) return '${diff.inDays} ngày trước';
    if (diff.inHours > 0) return '${diff.inHours} giờ trước';
    if (diff.inMinutes > 0) return '${diff.inMinutes} phút trước';
    return 'Vừa xong';
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    post.title,
                    style: AppTextStyles.labelBold,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (post.isSolved)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.correct.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('✓ Giải quyết',
                        style: TextStyle(color: AppColors.correct, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (post.tags.isNotEmpty)
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: post.tags.take(3).map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(tag,
                        style: const TextStyle(color: AppColors.blue, fontSize: 10, fontWeight: FontWeight.w600)),
                  );
                }).toList(),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(post.authorName,
                    style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                const Text(' · ', style: TextStyle(color: AppColors.textGray, fontSize: 12)),
                Text(_timeAgo(post.createdAt), style: AppTextStyles.bodySmall),
                const Spacer(),
                // Answer count
                const Icon(Icons.chat_bubble_outline, size: 14, color: AppColors.textGray),
                const SizedBox(width: 3),
                Text('${post.answerCount}', style: AppTextStyles.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
