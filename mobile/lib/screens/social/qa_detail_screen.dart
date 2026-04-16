import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/qa_post.dart';
import '../../models/qa_answer.dart';
import '../../services/api_service.dart';

class QaDetailScreen extends StatefulWidget {
  final QaPost post;

  const QaDetailScreen({super.key, required this.post});

  @override
  State<QaDetailScreen> createState() => _QaDetailScreenState();
}

class _QaDetailScreenState extends State<QaDetailScreen> {
  final _api = ApiService();
  final _answerController = TextEditingController();
  List<QaAnswer> _answers = [];
  bool _isLoadingAnswers = true;
  bool _isSubmitting = false;

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

  Future<void> _submitAnswer() async {
    final content = _answerController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await _api.createQaAnswer(widget.post.id, content);
      _answerController.clear();
      await _loadAnswers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Answer posted!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 7) return DateFormat('MMM d, yyyy').format(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        title: const Text('Question', style: AppTextStyles.heading4),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadAnswers,
              color: AppColors.primary,
              child: CustomScrollView(
                slivers: [
                  // Question
                  SliverToBoxAdapter(child: _buildQuestion()),
                  // Answers header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        '${widget.post.answerCount} Answers',
                        style: AppTextStyles.heading4,
                      ),
                    ),
                  ),
                  if (_isLoadingAnswers)
                    const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
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
                              Text('No answers yet. Be the first!', style: AppTextStyles.bodySmall),
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
                          onAccept: () {},
                        ),
                        childCount: _answers.length,
                      ),
                    ),
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

  Widget _buildQuestion() {
    final post = widget.post;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
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
                  color: AppColors.blue.withOpacity(0.1),
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
                backgroundColor: AppColors.primary.withOpacity(0.2),
                child: Text(
                  post.authorName.isNotEmpty ? post.authorName[0].toUpperCase() : 'U',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 8),
              Text(post.authorName, style: AppTextStyles.labelGray.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(_timeAgo(post.createdAt), style: AppTextStyles.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2))],
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
                  hintText: 'Write your answer...',
                  hintStyle: AppTextStyles.labelGray,
                  filled: true,
                  fillColor: AppColors.background,
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
                  color: _isSubmitting ? AppColors.primary.withOpacity(0.5) : AppColors.primary,
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
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: answer.isAccepted ? AppColors.primary.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: answer.isAccepted ? Border.all(color: AppColors.primary.withOpacity(0.3)) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
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
                  Text('Accepted Answer', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          Text(answer.content, style: AppTextStyles.bodyMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.blue.withOpacity(0.2),
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
              Text(answer.authorName, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
              const Text(' · ', style: TextStyle(color: AppColors.textGray, fontSize: 12)),
              Text(_timeAgo(answer.createdAt), style: AppTextStyles.bodySmall),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.thumb_up_outlined, size: 14, color: AppColors.textGray),
                  const SizedBox(width: 4),
                  Text('${answer.upvotes}', style: AppTextStyles.bodySmall),
                ],
              ),
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
                    child: const Text('Accept', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
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
