import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/topic.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import 'lessons_screen.dart';

class TopicsScreen extends StatefulWidget {
  const TopicsScreen({super.key});

  @override
  State<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends State<TopicsScreen> {
  final _api = ApiService();
  List<Topic> _topics = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final topics = await _api.getTopics();
      if (mounted) {
        setState(() {
          _topics = topics;
          _isLoading = false;
        });
        // Load progress in background
        context.read<UserProvider>().loadTopicProgress();
        context.read<UserProvider>().loadStats();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _topics = _mockTopics();
        });
      }
    }
  }

  List<Topic> _mockTopics() {
    return [
      const Topic(
        id: 'mock1',
        title: 'Java Basics',
        description: 'Variables, data types, operators and control flow',
        icon: '☕',
        color: '#58CC02',
        order: 1,
        totalLessons: 8,
        isActive: true,
      ),
      const Topic(
        id: 'mock2',
        title: 'Object-Oriented',
        description: 'Classes, objects, inheritance and polymorphism',
        icon: '🏗️',
        color: '#1CB0F6',
        order: 2,
        totalLessons: 10,
        isActive: true,
      ),
      const Topic(
        id: 'mock3',
        title: 'Data Structures',
        description: 'Arrays, lists, stacks, queues and maps',
        icon: '📊',
        color: '#FF9600',
        order: 3,
        totalLessons: 12,
        isActive: true,
      ),
      const Topic(
        id: 'mock4',
        title: 'Algorithms',
        description: 'Sorting, searching and recursion',
        icon: '🔄',
        color: '#CE82FF',
        order: 4,
        totalLessons: 8,
        isActive: true,
      ),
    ];
  }

  List<Topic> get _filteredTopics {
    if (_searchQuery.isEmpty) return _topics;
    return _topics.where((t) =>
        t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        t.description.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  Color _topicColor(Topic topic, int index) {
    if (topic.color.startsWith('#')) {
      try {
        return Color(int.parse('FF${topic.color.substring(1)}', radix: 16));
      } catch (_) {}
    }
    return AppColors.topicColors[index % AppColors.topicColors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildSearchBar()),
              if (_isLoading)
                SliverToBoxAdapter(child: _buildShimmer())
              else if (_error != null && _topics.isEmpty)
                SliverToBoxAdapter(child: _buildError())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final topic = _filteredTopics[index];
                        return _TopicCard(
                          topic: topic,
                          color: _topicColor(topic, index),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LessonsScreen(topic: topic),
                              ),
                            );
                          },
                        );
                      },
                      childCount: _filteredTopics.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Consumer<UserProvider>(
      builder: (context, provider, _) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          color: AppColors.background,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Java Learning',
                      style: AppTextStyles.heading2,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Keep learning every day!',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              // Streak badge
              _StatBadge(
                icon: '🔥',
                value: provider.streak.toString(),
                color: const Color(0xFFFF9600),
              ),
              const SizedBox(width: 8),
              // XP badge
              _StatBadge(
                icon: '⚡',
                value: provider.totalXp.toString(),
                color: AppColors.xpGold,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search topics...',
          hintStyle: AppTextStyles.labelGray,
          prefixIcon: const Icon(Icons.search, color: AppColors.textGray, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        children: List.generate(4, (_) {
          return Shimmer.fromColors(
            baseColor: const Color(0xFFE0E0E0),
            highlightColor: const Color(0xFFF5F5F5),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.wifi_off, size: 48, color: AppColors.textGray),
            const SizedBox(height: 12),
            Text('Could not load topics', style: AppTextStyles.heading4),
            const SizedBox(height: 8),
            Text('Check your connection and try again', style: AppTextStyles.bodySmall),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String icon;
  final String value;
  final Color color;

  const _StatBadge({required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  final Topic topic;
  final Color color;
  final VoidCallback onTap;

  const _TopicCard({
    required this.topic,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, provider, _) {
        final completed = provider.topicCompletedCount(topic.id);
        final total = topic.totalLessons > 0 ? topic.totalLessons : 1;
        final progress = (completed / total).clamp(0.0, 1.0);

        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: [
                  // Color strip + icon
                  Container(
                    width: 80,
                    height: 100,
                    color: color.withOpacity(0.15),
                    child: Center(
                      child: Text(
                        topic.icon,
                        style: const TextStyle(fontSize: 36),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(topic.title, style: AppTextStyles.heading4),
                          const SizedBox(height: 4),
                          Text(
                            topic.description,
                            style: AppTextStyles.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          // Progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: color.withOpacity(0.15),
                              valueColor: AlwaysStoppedAnimation(color),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                '$completed / ${topic.totalLessons} lessons',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              if (completed == topic.totalLessons && topic.totalLessons > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('✓ Done',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      )),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(Icons.chevron_right, color: color, size: 22),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
