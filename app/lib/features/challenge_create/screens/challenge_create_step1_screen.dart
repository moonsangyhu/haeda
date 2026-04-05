import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Flow 3 — Step 1: 기본 정보 입력 화면.
/// 카테고리, 제목, 설명(선택)을 입력 후 Step 2로 이동.
class ChallengeCreateStep1Screen extends StatefulWidget {
  const ChallengeCreateStep1Screen({super.key});

  @override
  State<ChallengeCreateStep1Screen> createState() =>
      _ChallengeCreateStep1ScreenState();
}

class _ChallengeCreateStep1ScreenState
    extends State<ChallengeCreateStep1Screen> {
  final _formKey = GlobalKey<FormState>();
  final _categoryController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _categoryController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_formKey.currentState!.validate()) {
      context.go(
        '/create/step2',
        extra: {
          'category': _categoryController.text.trim(),
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('챌린지 만들기'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StepIndicator(current: 1, total: 2),
            const SizedBox(height: 24),
            _FieldLabel('카테고리'),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('category_field'),
              controller: _categoryController,
              decoration: const InputDecoration(
                hintText: '예: 운동, 독서, 다이어트',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '카테고리를 입력해주세요.';
                return null;
              },
            ),
            const SizedBox(height: 20),
            _FieldLabel('제목'),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('title_field'),
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: '챌린지 제목을 입력해주세요.',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '제목을 입력해주세요.';
                return null;
              },
            ),
            const SizedBox(height: 20),
            _FieldLabel('설명 (선택)'),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('description_field'),
              controller: _descriptionController,
              decoration: const InputDecoration(
                hintText: '챌린지 목표나 규칙을 간단히 적어주세요.',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 32),
            FilledButton(
              key: const Key('next_button'),
              onPressed: _onNext,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('다음'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;

  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Step $current / $total',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
