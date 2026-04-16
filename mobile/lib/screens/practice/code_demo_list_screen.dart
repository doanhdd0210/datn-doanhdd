import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/api_code_snippet.dart';
import '../../models/topic.dart';
import '../../services/api_service.dart';
import 'code_demo_detail_screen.dart';

class CodeDemoListScreen extends StatefulWidget {
  const CodeDemoListScreen({super.key});

  @override
  State<CodeDemoListScreen> createState() => _CodeDemoListScreenState();
}

class _CodeDemoListScreenState extends State<CodeDemoListScreen> {
  final _api = ApiService();
  List<ApiCodeSnippet> _snippets = [];
  List<Topic> _topics = [];
  bool _isLoading = true;
  String? _selectedTopicId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _api.getCodeSnippets(topicId: _selectedTopicId),
        _api.getTopics(),
      ]);
      if (mounted) {
        setState(() {
          _snippets = results[0] as List<ApiCodeSnippet>;
          _topics = results[1] as List<Topic>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _snippets = _mockSnippets();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _filterByTopic(String? topicId) async {
    setState(() {
      _selectedTopicId = topicId;
      _isLoading = true;
    });
    try {
      final snippets = await _api.getCodeSnippets(topicId: topicId);
      if (mounted) {
        setState(() {
          _snippets = snippets;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _snippets = _mockSnippets();
        });
      }
    }
  }

  List<ApiCodeSnippet> _mockSnippets() {
    return [
      const ApiCodeSnippet(
        id: 'mock1',
        topicId: 'mock_topic1',
        title: 'Hello World',
        description: 'The classic first Java program',
        code: 'public class Main {\n    public static void main(String[] args) {\n        System.out.println("Hello, World!");\n    }\n}',
        language: 'java',
        expectedOutput: 'Hello, World!',
        order: 1,
        xpReward: 10,
      ),
      const ApiCodeSnippet(
        id: 'mock2',
        topicId: 'mock_topic1',
        title: 'Fibonacci Sequence',
        description: 'Generate Fibonacci numbers using a loop',
        code: 'public class Main {\n    public static void main(String[] args) {\n        int a = 0, b = 1;\n        for (int i = 0; i < 10; i++) {\n            System.out.print(a + " ");\n            int tmp = a + b; a = b; b = tmp;\n        }\n    }\n}',
        language: 'java',
        expectedOutput: '0 1 1 2 3 5 8 13 21 34 ',
        order: 2,
        xpReward: 15,
      ),
      const ApiCodeSnippet(
        id: 'mock3',
        topicId: 'mock_topic2',
        title: 'Bubble Sort',
        description: 'Sort an array using bubble sort algorithm',
        code: 'public class Main {\n    public static void main(String[] args) {\n        int[] arr = {5, 3, 8, 1, 9};\n        for (int i = 0; i < arr.length - 1; i++)\n            for (int j = 0; j < arr.length - i - 1; j++)\n                if (arr[j] > arr[j+1]) { int t = arr[j]; arr[j] = arr[j+1]; arr[j+1] = t; }\n        for (int x : arr) System.out.print(x + " ");\n    }\n}',
        language: 'java',
        expectedOutput: '1 3 5 8 9 ',
        order: 3,
        xpReward: 20,
      ),
    ];
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
              if (_topics.isNotEmpty) SliverToBoxAdapter(child: _buildTopicFilter()),
              if (_isLoading)
                SliverToBoxAdapter(child: _buildShimmer())
              else if (_snippets.isEmpty)
                SliverToBoxAdapter(child: _buildEmpty())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _SnippetCard(
                        snippet: _snippets[index],
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CodeDemoDetailScreen(
                                snippet: _snippets[index],
                              ),
                            ),
                          );
                        },
                      ),
                      childCount: _snippets.length,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Practice', style: AppTextStyles.heading2),
          const SizedBox(height: 4),
          Text(
            'Run and practice Java code examples',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildTopicFilter() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: [
          _FilterChip(
            label: 'All',
            isSelected: _selectedTopicId == null,
            onTap: () => _filterByTopic(null),
          ),
          ..._topics.map((topic) => _FilterChip(
                label: topic.title,
                isSelected: _selectedTopicId == topic.id,
                onTap: () => _filterByTopic(topic.id),
              )),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(4, (_) {
          return Shimmer.fromColors(
            baseColor: const Color(0xFFE0E0E0),
            highlightColor: const Color(0xFFF5F5F5),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              height: 90,
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

  Widget _buildEmpty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          children: [
            Text('💻', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text('No code examples yet', style: AppTextStyles.heading4),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textGray,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _SnippetCard extends StatelessWidget {
  final ApiCodeSnippet snippet;
  final VoidCallback onTap;

  const _SnippetCard({required this.snippet, required this.onTap});

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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('☕', style: TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(snippet.title, style: AppTextStyles.labelBold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E2E),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          snippet.language.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    snippet.description,
                    style: AppTextStyles.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.xpGold.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '⚡ ${snippet.xpReward} XP',
                          style: const TextStyle(color: AppColors.xpGold, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textGray),
          ],
        ),
      ),
    );
  }
}
