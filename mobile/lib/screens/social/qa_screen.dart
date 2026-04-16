import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/qa_post.dart';
import '../../services/api_service.dart';
import 'qa_detail_screen.dart';
import 'create_qa_screen.dart';

class QaScreen extends StatefulWidget {
  const QaScreen({super.key});

  @override
  State<QaScreen> createState() => _QaScreenState();
}

class _QaScreenState extends State<QaScreen> {
  final _api = ApiService();
  List<QaPost> _posts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _filter = 'all';
  int _page = 1;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _loadMore();
      }
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
        title: 'What is the difference between == and .equals() in Java?',
        content: 'I am confused about when to use == vs .equals() for string comparison.',
        authorId: 'user1',
        authorName: 'Alice',
        authorAvatar: '',
        tags: ['strings', 'comparison', 'basics'],
        answerCount: 3,
        upvotes: 12,
        isSolved: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      QaPost(
        id: 'mock2',
        title: 'How does garbage collection work in Java?',
        content: 'Can someone explain the Java garbage collection mechanism?',
        authorId: 'user2',
        authorName: 'Bob',
        authorAvatar: '',
        tags: ['memory', 'jvm', 'advanced'],
        answerCount: 1,
        upvotes: 5,
        isSolved: false,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }

  List<QaPost> get _filteredPosts {
    // In a real app, filter by endpoint. For now just show all
    return _posts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilterBar(),
            Expanded(
              child: _isLoading
                  ? _buildShimmer()
                  : RefreshIndicator(
                      onRefresh: () => _loadPosts(reset: true),
                      color: AppColors.primary,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredPosts.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _filteredPosts.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(color: AppColors.primary),
                              ),
                            );
                          }
                          final post = _filteredPosts[index];
                          return _QaPostCard(
                            post: post,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => QaDetailScreen(post: post),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateQaScreen()),
          );
          _loadPosts(reset: true);
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Ask', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Community Q&A', style: AppTextStyles.heading2),
          const SizedBox(height: 4),
          Text('Ask questions, share knowledge', style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = [
      ('all', 'All'),
      ('unanswered', 'Unanswered'),
      ('solved', 'Solved'),
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
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
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

  Widget _buildShimmer() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(5, (_) {
          return Shimmer.fromColors(
            baseColor: const Color(0xFFE0E0E0),
            highlightColor: const Color(0xFFF5F5F5),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _QaPostCard extends StatelessWidget {
  final QaPost post;
  final VoidCallback onTap;

  const _QaPostCard({required this.post, required this.onTap});

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 7) return DateFormat('MMM d').format(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('✓ Solved',
                        style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Tags
            if (post.tags.isNotEmpty)
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: post.tags.take(3).map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(color: AppColors.blue, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(post.authorName, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                const Text(' · ', style: TextStyle(color: AppColors.textGray, fontSize: 12)),
                Text(_timeAgo(post.createdAt), style: AppTextStyles.bodySmall),
                const Spacer(),
                Icon(Icons.chat_bubble_outline, size: 14, color: AppColors.textGray),
                const SizedBox(width: 4),
                Text('${post.answerCount}', style: AppTextStyles.bodySmall),
                const SizedBox(width: 10),
                Icon(Icons.thumb_up_outlined, size: 14, color: AppColors.textGray),
                const SizedBox(width: 4),
                Text('${post.upvotes}', style: AppTextStyles.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
