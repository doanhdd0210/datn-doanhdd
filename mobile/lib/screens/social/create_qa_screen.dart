import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/app_theme.dart';
import '../../services/api_service.dart';

class CreateQaScreen extends StatefulWidget {
  const CreateQaScreen({super.key});

  @override
  State<CreateQaScreen> createState() => _CreateQaScreenState();
}

class _CreateQaScreenState extends State<CreateQaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagController = TextEditingController();
  final ApiService _api = ApiService();

  final List<String> _tags = [];
  bool _isSubmitting = false;

  final List<String> _suggestedTags = [
    'Java cơ bản', 'OOP', 'Vòng lặp', 'Mảng', 'String',
    'Exception', 'Collection', 'Stream', 'Lambda', 'Thread',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isNotEmpty && !_tags.contains(trimmed) && _tags.length < 5) {
      setState(() {
        _tags.add(trimmed);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await _api.createQaPost(
        _titleController.text.trim(),
        _contentController.text.trim(),
        tags: _tags,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã đăng câu hỏi thành công!'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _fieldDecoration({
    required BuildContext context,
    required String hint,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: context.textSecondary.withValues(alpha: 0.6), fontSize: 14),
      filled: true,
      fillColor: context.surfaceColor,
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
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.red.withValues(alpha: 0.8)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.red, width: 2),
      ),
      counterStyle: TextStyle(color: context.textSecondary, fontSize: 11),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        title: Text('Đặt câu hỏi',
            style: AppTextStyles.heading3.copyWith(color: context.textPrimary)),
        foregroundColor: context.textPrimary,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          color: context.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: context.borderColor),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Đăng', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildTip(context),
            const SizedBox(height: 20),
            _buildLabel(context, 'Tiêu đề câu hỏi *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              maxLength: 150,
              style: TextStyle(color: context.textPrimary, fontSize: 15),
              decoration: _fieldDecoration(
                context: context,
                hint: 'VD: Sự khác nhau giữa ArrayList và LinkedList?',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Vui lòng nhập tiêu đề';
                if (v.trim().length < 10) return 'Tiêu đề quá ngắn (ít nhất 10 ký tự)';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildLabel(context, 'Nội dung chi tiết *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _contentController,
              maxLines: 8,
              maxLength: 2000,
              style: TextStyle(color: context.textPrimary, fontSize: 14, height: 1.5),
              decoration: _fieldDecoration(
                context: context,
                hint: 'Mô tả chi tiết vấn đề bạn gặp phải, đính kèm code nếu có...',
              ).copyWith(alignLabelWithHint: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Vui lòng nhập nội dung';
                if (v.trim().length < 20) return 'Nội dung quá ngắn (ít nhất 20 ký tự)';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTagsSection(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: context.textPrimary,
      ),
    );
  }

  Widget _buildTip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, color: AppColors.blue, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Câu hỏi rõ ràng, có ví dụ cụ thể sẽ được trả lời nhanh hơn. Hãy mô tả vấn đề bạn gặp phải và những gì bạn đã thử.',
              style: TextStyle(fontSize: 13, color: AppColors.blue, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(context, 'Tags (tối đa 5)'),
        const SizedBox(height: 8),
        if (_tags.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags
                .map((tag) => Chip(
                      label: Text(tag, style: const TextStyle(fontSize: 13)),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () => _removeTag(tag),
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      deleteIconColor: AppColors.primary,
                      labelStyle: const TextStyle(color: AppColors.primary),
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
        ],
        if (_tags.length < 5)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagController,
                  style: TextStyle(fontSize: 14, color: context.textPrimary),
                  onSubmitted: _addTag,
                  decoration: InputDecoration(
                    hintText: 'Thêm tag...',
                    hintStyle: TextStyle(
                        color: context.textSecondary.withValues(alpha: 0.6), fontSize: 13),
                    filled: true,
                    fillColor: context.surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _addTag(_tagController.text),
                icon: const Icon(Icons.add_circle, color: AppColors.primary),
              ),
            ],
          ),
        const SizedBox(height: 12),
        Text(
          'Gợi ý:',
          style: TextStyle(fontSize: 12, color: context.textSecondary),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _suggestedTags
              .where((t) => !_tags.contains(t))
              .take(8)
              .map((tag) => GestureDetector(
                    onTap: () => _addTag(tag),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: context.borderColor),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(fontSize: 12, color: context.textSecondary),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
