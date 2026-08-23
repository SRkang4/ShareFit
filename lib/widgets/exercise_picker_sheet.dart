import 'package:flutter/material.dart';

class ExercisePickerSheet extends StatefulWidget {
  const ExercisePickerSheet({
    super.key,
    required this.exercises,
    this.selectedExercise,
  });

  final List<String> exercises;
  final String? selectedExercise;

  @override
  State<ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<ExercisePickerSheet> {
  static const int _customExerciseMaxLength = 30;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customExerciseController =
      TextEditingController();
  String _query = '';

  List<String> get _filteredExercises {
    final normalizedQuery = _query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return widget.exercises;
    return widget.exercises
        .where((exercise) => exercise.toLowerCase().contains(normalizedQuery))
        .toList(growable: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customExerciseController.dispose();
    super.dispose();
  }

  void _submitCustomExercise() {
    final exerciseName = _customExerciseController.text.trim();
    if (exerciseName.isEmpty) return;
    Navigator.of(context).pop(exerciseName);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final filteredExercises = _filteredExercises;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SafeArea(
        top: false,
        child: FractionallySizedBox(
          heightFactor: 0.88,
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '운동 종목 선택',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: '운동 이름 검색',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: '검색어 지우기',
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                          filled: true,
                          fillColor: colors.surfaceContainer,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filteredExercises.isEmpty
                      ? Center(
                          child: Text(
                            '검색 결과가 없어요.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: filteredExercises.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            indent: 10,
                            endIndent: 10,
                            color: colors.outlineVariant,
                          ),
                          itemBuilder: (context, index) {
                            final exercise = filteredExercises[index];
                            final selected =
                                exercise == widget.selectedExercise;
                            return ListTile(
                              minTileHeight: 54,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              title: Text(
                                exercise,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              trailing: selected
                                  ? Icon(
                                      Icons.check_rounded,
                                      color: colors.primary,
                                    )
                                  : Icon(
                                      Icons.chevron_right_rounded,
                                      color: colors.onSurfaceVariant,
                                    ),
                              onTap: () => Navigator.of(context).pop(exercise),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    border: Border(
                      top: BorderSide(color: colors.outlineVariant),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '직접 입력',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _customExerciseController,
                              maxLength: _customExerciseMaxLength,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submitCustomExercise(),
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: '운동 이름을 입력하세요',
                                counterText: '',
                                filled: true,
                                fillColor: colors.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: colors.outlineVariant,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: colors.outlineVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed:
                                  _customExerciseController.text.trim().isEmpty
                                  ? null
                                  : _submitCustomExercise,
                              style: FilledButton.styleFrom(
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text('추가'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
