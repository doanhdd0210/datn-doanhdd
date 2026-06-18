import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../widgets/football_refresh_indicator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/ai_usage_provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/app_theme.dart';
import '../../models/qa_post.dart';
import '../../models/qa_answer.dart';
import '../../services/api_service.dart';
import '../../services/ai_service.dart';
import '../../widgets/ai_limit_dialog.dart';
import '../../widgets/app_loading.dart';
import '../../widgets/app_snackbar.dart';

class QaDetailScreen extends StatefulWidget {
  final QaPost post;

  const QaDetailScreen({super.key, required this.post});

  @override
  State<QaDetailScreen> createState() => _QaDetailScreenState();
}

class _QaDetailScreenState extends State<QaDetailScreen> {
  final _api = ApiService();
  final _aiService = AiService();
  final _answerController = TextEditingController();
  List<QaAnswer> _answers = [];
  bool _isLoadingAnswers = true;
  bool _isSubmitting = false;

  // AI state
  String? _aiAnswer;
  bool _aiLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAnswers();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _loadAnswers() async {
    setState(() => _isLoadingAnswers = true);
    try {
      final answers = await _api.getQaAnswers(widget.post.id);
      if (mounted) setState(() { _answers = answers; _isLoadingAnswers = false; });
    } catch (_) {
      if (mounted) setState(() { _answers = []; _isLoadingAnswers = false; });
    }
  }

  Future<void> _acceptAnswer(String answerId) async {
    // Confirm trước khi accept
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Chấp nhận câu trả lời?', style: AppTextStyles.heading4),
              const SizedBox(height: 10),
              const Text(
                'Câu trả lời này sẽ được đánh dấu là giải quyết vấn đề của bạn.',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.textSecondary,
                        side: BorderSide(color: context.borderColor, width: 1.5),
                        fixedSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Huỷ', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        fixedSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Chấp nhận', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.acceptAnswer(answerId);
      await _loadAnswers();
      if (mounted) AppSnackBar.success(context, 'Đã đánh dấu câu hỏi là đã giải quyết!');
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'Lỗi: $e');
    }
  }

  Future<void> _askAi() async {
    if (_aiLoading) return;
    setState(() { _aiLoading = true; _aiAnswer = null; });
    try {
      final result = await _aiService.suggestQaAnswer(
        title: widget.post.title,
        body: widget.post.content,
      );
      if (!mounted) return;
      context.read<AiUsageProvider>().load();
      setState(() { _aiLoading = false; _aiAnswer = result; });
    } on AiLimitException catch (e) {
      if (!mounted) return;
      setState(() => _aiLoading = false);
      showAiLimitDialog(context, e.message);
    }
  }

  Future<void> _submitAnswer() async {
    final content = _answerController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await _api.createQaAnswer(widget.post.id, content);
      _answerController.clear();
      await _loadAnswers();
      if (mounted) AppSnackBar.success(context, 'Đã đăng câu trả lời!');
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'Không thể đăng: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 7) return DateFormat('d MMM, yyyy').format(date);
    if (diff.inDays > 0) return '${diff.inDays} ngày trước';
    if (diff.inHours > 0) return '${diff.inHours} giờ trước';
    if (diff.inMinutes > 0) return '${diff.inMinutes} phút trước';
    return 'Vừa xong';
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        foregroundColor: context.textDark,
        elevation: 0,
        title: const Text('Câu hỏi', style: AppTextStyles.heading4),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Builder(builder: (ctx) => Container(height: 1, color: ctx.borderColor)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: FootballRefreshIndicator(
              onRefresh: _loadAnswers,
              child: CustomScrollView(
                slivers: [
                  // Question
                  SliverToBoxAdapter(child: _buildQuestion()),
                  // Answers header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        '${_isLoadingAnswers ? widget.post.answerCount : _answers.length} Câu trả lời',
                        style: AppTextStyles.heading4,
                      ),
                    ),
                  ),
                  if (_isLoadingAnswers)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: AppLoadingCenter(),
                      ),
                    )
                  else if (_answers.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            children: [
                              const Text('💬', style: TextStyle(fontSize: 32)),
                              const SizedBox(height: 8),
                              Text('Chưa có câu trả lời. Hãy là người đầu tiên!', style: AppTextStyles.bodySmall.copyWith(color: context.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _AnswerCard(
                          answer: _answers[index],
                          isPostAuthor: currentUser?.uid == widget.post.authorId,
                          onAccept: () => _acceptAnswer(_answers[index].id),
                        ),
                        childCount: _answers.length,
                      ),
                    ),
                  // AI suggest answer card
                  SliverToBoxAdapter(child: _buildAiCard()),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
              ),
            ),
          ),
          // Answer input
          if (currentUser != null) _buildAnswerInput(),
        ],
      ),
    );
  }

  Widget _buildAiCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A237E).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3949AB).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🤖', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              const Text('Trợ lý AI', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF3949AB))),
              const Spacer(),
              if (_aiAnswer != null)
                GestureDetector(
                  onTap: _askAi,
                  child: const Text('Hỏi lại', style: TextStyle(fontSize: 11, color: Color(0xFF3949AB))),
                ),
            ],
          ),
          if (_aiAnswer == null && !_aiLoading) ...[
            const SizedBox(height: 8),
            Builder(builder: (ctx) {
              final aiUsage = ctx.watch<AiUsageProvider>();
              final exhausted = aiUsage.isExhausted;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        exhausted
                            ? 'Đã hết lượt AI hôm nay.'
                            : 'AI có thể gợi ý câu trả lời cho câu hỏi này.',
                        style: TextStyle(fontSize: 12, color: context.textSecondary),
                      ),
                      if (aiUsage.loaded) ...[
                        const Spacer(),
                        Text(
                          aiUsage.isUnlimited ? '${aiUsage.used}/∞ lượt' : '${aiUsage.used}/${aiUsage.limit} lượt',
                          style: TextStyle(fontSize: 11, color: context.textSecondary),
                        ),
                      ],
                    ],
                  ),
                  if (!exhausted) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _askAi,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3949AB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text('Hỏi AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            }),
          ],
          if (_aiLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppLoading.small(color: Color(0xFF3949AB)),
                  SizedBox(width: 10),
                  Text('AI đang soạn câu trả lời...', style: TextStyle(fontSize: 12, color: Color(0xFF3949AB))),
                ],
              ),
            ),
          if (_aiAnswer != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A237E).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_aiAnswer!, style: TextStyle(fontSize: 13, height: 1.5, color: context.textDark)),
            ),
            const SizedBox(height: 8),
            Text('⚠️ Đây là gợi ý từ AI, hãy xác minh lại trước khi áp dụng.',
                style: TextStyle(fontSize: 10, color: context.textSecondary, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestion() {
    final post = widget.post;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(post.title, style: AppTextStyles.heading3),
          const SizedBox(height: 12),
          if (post.tags.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: post.tags.map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(tag, style: const TextStyle(color: AppColors.blue, fontSize: 11, fontWeight: FontWeight.w600)),
              )).toList(),
            ),
          const SizedBox(height: 12),
          Text(post.content, style: AppTextStyles.bodyMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                child: Text(
                  post.authorName.isNotEmpty ? post.authorName[0].toUpperCase() : 'U',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 8),
              Text(post.authorName, style: AppTextStyles.labelGray.copyWith(color: context.textSecondary, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(_timeAgo(post.createdAt), style: AppTextStyles.bodySmall.copyWith(color: context.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerInput() {
    return Builder(
      builder: (context) => Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(top: BorderSide(color: context.borderColor)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _answerController,
                maxLines: null,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'Viết câu trả lời của bạn...',
                  hintStyle: AppTextStyles.labelGray.copyWith(color: context.textSecondary),
                  filled: true,
                  fillColor: context.bgColor,
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _isSubmitting ? null : _submitAnswer,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _isSubmitting ? AppColors.primary.withValues(alpha: 0.5) : AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: _isSubmitting
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  final QaAnswer answer;
  final bool isPostAuthor;
  final VoidCallback onAccept;

  const _AnswerCard({required this.answer, required this.isPostAuthor, required this.onAccept});

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 7) return DateFormat('d MMM, yyyy').format(date);
    if (diff.inDays > 0) return '${diff.inDays} ngày trước';
    if (diff.inHours > 0) return '${diff.inHours} giờ trước';
    if (diff.inMinutes > 0) return '${diff.inMinutes} phút trước';
    return 'Vừa xong';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: answer.isAccepted ? AppColors.primary.withValues(alpha: 0.15) : context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: answer.isAccepted ? Border.all(color: AppColors.primary.withValues(alpha: 0.3)) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (answer.isAccepted)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 12, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Câu trả lời được chấp nhận', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          Text(answer.content, style: AppTextStyles.bodyMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.blue.withValues(alpha: 0.2),
                backgroundImage: answer.authorAvatar.isNotEmpty
                    ? CachedNetworkImageProvider(answer.authorAvatar)
                    : null,
                child: answer.authorAvatar.isEmpty
                    ? Text(
                        answer.authorName.isNotEmpty ? answer.authorName[0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.blue),
                      )
                    : null,
              ),
              const SizedBox(width: 6),
              Text(answer.authorName, style: AppTextStyles.bodySmall.copyWith(color: context.textSecondary, fontWeight: FontWeight.w600)),
              Text(' · ', style: TextStyle(color: context.textSecondary, fontSize: 12)),
              Text(_timeAgo(answer.createdAt), style: AppTextStyles.bodySmall.copyWith(color: context.textSecondary)),
              const Spacer(),
              if (isPostAuthor && !answer.isAccepted) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onAccept,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Chấp nhận', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
