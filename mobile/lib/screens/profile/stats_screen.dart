import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/daily_progress.dart';
import '../../services/api_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  List<DailyProgress> _dailyProgress = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _api.getDailyProgress(),
        _api.getUserStats(),
      ]);
      if (mounted) {
        setState(() {
          _dailyProgress = results[0] as List<DailyProgress>;
          _stats = results[1] as Map<String, dynamic>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _dailyProgress = _mockProgress();
          _stats = _mockStats();
          _isLoading = false;
        });
      }
    }
  }

  List<DailyProgress> _mockProgress() {
    final now = DateTime.now();
    return List.generate(30, (i) {
      final date = now.subtract(Duration(days: 29 - i));
      final hasActivity = i % 3 != 0;
      return DailyProgress(
        date: date,
        xpEarned: hasActivity ? 20 + (i % 5) * 10 : 0,
        lessonsCompleted: hasActivity ? 1 + (i % 3) : 0,
        minutesLearned: hasActivity ? 10 + (i % 4) * 5 : 0,
      );
    });
  }

  Map<String, dynamic> _mockStats() {
    return {
      'totalXp': 420,
      'currentStreak': 5,
      'longestStreak': 12,
      'lessonsCompleted': 18,
      'totalMinutes': 320,
      'averageDailyXp': 28,
    };
  }

  List<DailyProgress> get _last7Days {
    if (_dailyProgress.isEmpty) return [];
    return _dailyProgress.length >= 7
        ? _dailyProgress.sublist(_dailyProgress.length - 7)
        : _dailyProgress;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        title: const Text('Learning Progress', style: AppTextStyles.heading4),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStreakCard(),
                    const SizedBox(height: 16),
                    _buildWeeklyChart(),
                    const SizedBox(height: 16),
                    _buildStatsGrid(),
                    const SizedBox(height: 16),
                    _buildCalendarHeatmap(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStreakCard() {
    final currentStreak = _stats['currentStreak'] as int? ?? 0;
    final longestStreak = _stats['longestStreak'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9600), Color(0xFFFF6B00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.orange.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 40)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Current Streak',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(
                  '$currentStreak days',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Best Streak', style: TextStyle(color: Colors.white70, fontSize: 11)),
              Text(
                '$longestStreak days',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    final data = _last7Days;
    if (data.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly XP', style: AppTextStyles.heading4),
          const SizedBox(height: 4),
          Text('Last 7 days', style: AppTextStyles.bodySmall),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: data.map((d) => d.xpEarned.toDouble()).reduce((a, b) => a > b ? a : b) + 20,
                barGroups: data.asMap().entries.map((entry) {
                  final i = entry.key;
                  final dp = entry.value;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: dp.xpEarned.toDouble(),
                        color: dp.xpEarned > 0 ? AppColors.primary : AppColors.border,
                        width: 24,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                      ),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final dp = data[value.toInt()];
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            DateFormat('E').format(dp.date),
                            style: const TextStyle(fontSize: 10, color: AppColors.textGray),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const Text('');
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 9, color: AppColors.textGray),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.border,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final totalXp = _stats['totalXp'] as int? ?? 0;
    final lessonsCompleted = _stats['lessonsCompleted'] as int? ?? 0;
    final totalMinutes = _stats['totalMinutes'] as int? ?? 0;
    final avgDailyXp = _stats['averageDailyXp'] as int? ?? 0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _StatCard(icon: '⚡', label: 'Total XP', value: totalXp.toString(), color: AppColors.xpGold),
        _StatCard(icon: '📚', label: 'Lessons Done', value: lessonsCompleted.toString(), color: AppColors.primary),
        _StatCard(icon: '⏱', label: 'Minutes Learned', value: totalMinutes.toString(), color: AppColors.blue),
        _StatCard(icon: '📈', label: 'Avg Daily XP', value: avgDailyXp.toString(), color: AppColors.purple),
      ],
    );
  }

  Widget _buildCalendarHeatmap() {
    if (_dailyProgress.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activity Calendar', style: AppTextStyles.heading4),
          const SizedBox(height: 4),
          Text('Last 30 days', style: AppTextStyles.bodySmall),
          const SizedBox(height: 16),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: _dailyProgress.map((dp) {
              final hasActivity = dp.xpEarned > 0;
              final intensity = hasActivity ? (dp.xpEarned / 100).clamp(0.2, 1.0) : 0.0;
              return Tooltip(
                message: '${DateFormat('MMM d').format(dp.date)}: ${dp.xpEarned} XP',
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: hasActivity
                        ? AppColors.primary.withOpacity(intensity)
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Less', style: TextStyle(fontSize: 10, color: AppColors.textGray)),
              const SizedBox(width: 6),
              ...List.generate(5, (i) {
                final opacity = 0.15 + i * 0.2;
                return Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(opacity),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
              const SizedBox(width: 6),
              const Text('More', style: TextStyle(fontSize: 10, color: AppColors.textGray)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const Spacer(),
          Text(value, style: AppTextStyles.heading3.copyWith(color: color)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}
