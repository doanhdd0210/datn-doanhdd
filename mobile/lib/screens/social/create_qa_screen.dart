import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Đặt câu hỏi', style: AppTextStyles.heading3),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
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
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
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
            _buildTip(),
            const SizedBox(height: 16),
            _buildTitleField(),
            const SizedBox(height: 16),
            _buildContentField(),
            const SizedBox(height: 16),
            _buildTagsSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTip() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.blue.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: AppColors.blue, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Câu hỏi rõ ràng, có ví dụ cụ thể sẽ được trả lời nhanh hơn. Hãy mô tả vấn đề bạn gặp phải và những gì bạn đã thử.',
              style: TextStyle(fontSize: 13, color: AppColors.blue, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tiêu đề câu hỏi *',
          style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _titleController,
          maxLength: 150,
          style: AppTextStyles.bodyLarge,
          decoration: InputDecoration(
            hintText: 'VD: Sự khác nhau giữa ArrayList và LinkedList?',
            hintStyle: TextStyle(color: AppColors.textGray, fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            counterStyle: TextStyle(color: AppColors.textGray, fontSize: 11),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Vui lòng nhập tiêu đề';
            if (v.trim().length < 10) return 'Tiêu đề quá ngắn (ít nhất 10 ký tự)';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildContentField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nội dung chi tiết *',
          style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _contentController,
          maxLines: 8,
          maxLength: 2000,
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(
            hintText: 'Mô tả chi tiết vấn đề bạn gặp phải, đính kèm code nếu có...',
            hintStyle: TextStyle(color: AppColors.textGray, fontSize: 14),
            alignLabelWithHint: true,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            counterStyle: TextStyle(color: AppColors.textGray, fontSize: 11),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Vui lòng nhập nội dung';
            if (v.trim().length < 20) return 'Nội dung quá ngắn (ít nhất 20 ký tự)';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags (tối đa 5)',
          style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        // Current tags
        if (_tags.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags
                .map((tag) => Chip(
                      label: Text(tag, style: const TextStyle(fontSize: 13)),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () => _removeTag(tag),
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      deleteIconColor: AppColors.primary,
                      labelStyle: TextStyle(color: AppColors.primary),
                      side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
        ],
        // Tag input
        if (_tags.length < 5)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagController,
                  style: const TextStyle(fontSize: 14),
                  onSubmitted: _addTag,
                  decoration: InputDecoration(
                    hintText: 'Thêm tag...',
                    hintStyle: TextStyle(color: AppColors.textGray, fontSize: 13),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
        // Suggested tags
        Text(
          'Gợi ý:',
          style: TextStyle(fontSize: 12, color: AppColors.textGray),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(tag, style: TextStyle(fontSize: 12, color: AppColors.textGray)),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
