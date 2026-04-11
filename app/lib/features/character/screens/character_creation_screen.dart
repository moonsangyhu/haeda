import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/character_avatar.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/character_data.dart';
import '../providers/character_provider.dart';

class CharacterCreationScreen extends ConsumerStatefulWidget {
  const CharacterCreationScreen({super.key});

  @override
  ConsumerState<CharacterCreationScreen> createState() =>
      _CharacterCreationScreenState();
}

class _CharacterCreationScreenState
    extends ConsumerState<CharacterCreationScreen>
    with SingleTickerProviderStateMixin {
  String _selectedSkinTone = 'fair';
  String _selectedEyeStyle = 'round';
  String _selectedHairStyle = 'short';
  int _selectedBackgroundIndex = 0;
  bool _isSaving = false;

  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnimation;

  static const _skinTones = [
    ('light', '밝은', Color(0xFFFFF0DB)),
    ('fair', '기본', Color(0xFFFFCBA4)),
    ('dark', '어두운', Color(0xFF8D5524)),
  ];

  static const _eyeStyles = [
    ('round', '동그란'),
    ('sharp', '날카로운'),
    ('sleepy', '졸린'),
  ];

  static const _hairStyles = [
    ('short', '짧은'),
    ('long', '긴'),
    ('curly', '곱슬'),
  ];

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _onSelectionChanged() {
    _bounceController.forward(from: 0.0);
  }

  String _selectedBackgroundHex() {
    final color = AppTheme.characterBackgroundPalette[_selectedBackgroundIndex];
    final value = color.value & 0xFFFFFF;
    return '#${value.toRadixString(16).toUpperCase().padLeft(6, '0')}';
  }

  Future<void> _onDone() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(authStateProvider.notifier).updateProfile(
            backgroundColor: _selectedBackgroundHex(),
          );
      await ref.read(myCharacterProvider.notifier).saveAppearance(
            skinTone: _selectedSkinTone,
            eyeStyle: _selectedEyeStyle,
            hairStyle: _selectedHairStyle,
          );
      if (!mounted) return;
      context.go('/my-page');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('캐릭터 만들기'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildPreview(),
                    const SizedBox(height: 32),
                    _buildSkinSection(colorScheme),
                    const SizedBox(height: 24),
                    _buildChoiceSection(
                      label: '눈매',
                      options: _eyeStyles,
                      selected: _selectedEyeStyle,
                      onSelect: (v) {
                        setState(() => _selectedEyeStyle = v);
                        _onSelectionChanged();
                      },
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 24),
                    _buildChoiceSection(
                      label: '머리스타일',
                      options: _hairStyles,
                      selected: _selectedHairStyle,
                      onSelect: (v) {
                        setState(() => _selectedHairStyle = v);
                        _onSelectionChanged();
                      },
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 24),
                    _buildBackgroundSection(colorScheme),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            _buildDoneButton(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Center(
      child: Column(
        children: [
          const Text(
            '내 캐릭터',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _bounceAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _bounceAnimation.value,
                child: child,
              );
            },
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: AppTheme
                    .characterBackgroundPalette[_selectedBackgroundIndex],
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withAlpha(40),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: CharacterAvatar(
                  character: CharacterData(
                    skinTone: _selectedSkinTone,
                    eyeStyle: _selectedEyeStyle,
                    hairStyle: _selectedHairStyle,
                  ),
                  size: 140,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkinSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('피부색'),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _skinTones.map((entry) {
            final (value, label, color) = entry;
            final isSelected = _selectedSkinTone == value;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedSkinTone = value);
                  _onSelectionChanged();
                },
                child: Semantics(
                  label: '$label 피부색',
                  selected: isSelected,
                  button: true,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.outlineVariant,
                        width: isSelected ? 3 : 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: colorScheme.primary.withAlpha(60),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            size: 22,
                            color: value == 'dark' ? Colors.white : AppTheme.textPrimary,
                          )
                        : null,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _skinTones.map((entry) {
            final (value, label, _) = entry;
            final isSelected = _selectedSkinTone == value;
            return SizedBox(
              width: 76,
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildChoiceSection({
    required String label,
    required List<(String, String)> options,
    required String selected,
    required ValueChanged<String> onSelect,
    required ColorScheme colorScheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(label),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options.map((entry) {
            final (value, optionLabel) = entry;
            final isSelected = selected == value;
            return Semantics(
              label: '$optionLabel $label',
              selected: isSelected,
              button: true,
              child: GestureDetector(
                onTap: () => onSelect(value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primaryContainer
                        : colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: colorScheme.primary.withAlpha(30),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    optionLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? colorScheme.onPrimaryContainer
                          : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBackgroundSection(ColorScheme colorScheme) {
    final palette = AppTheme.characterBackgroundPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('배경색'),
        const SizedBox(height: 6),
        const Text(
          '내 방 탭에서 캐릭터 뒤에 표시돼요',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(palette.length, (i) {
            final color = palette[i];
            final isSelected = _selectedBackgroundIndex == i;
            return Semantics(
              label: '배경색 ${i + 1}',
              selected: isSelected,
              button: true,
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedBackgroundIndex = i);
                  _onSelectionChanged();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                      width: isSelected ? 3 : 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: colorScheme.primary.withAlpha(60),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          size: 22,
                          color: AppTheme.textPrimary,
                        )
                      : null,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildDoneButton(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _onDone,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  '완료',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
