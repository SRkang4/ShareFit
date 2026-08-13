import 'dart:io';

import 'package:flutter/material.dart';

import '../models/workout_record.dart';

class WorkoutHistoryCard extends StatefulWidget {
  const WorkoutHistoryCard({
    super.key,
    required this.workout,
    this.title,
    this.imageFile,
    this.onPhotoPressed,
  });

  final WorkoutRecord workout;
  final String? title;
  final File? imageFile;
  final VoidCallback? onPhotoPressed;

  @override
  State<WorkoutHistoryCard> createState() => _WorkoutHistoryCardState();
}

class _WorkoutHistoryCardState extends State<WorkoutHistoryCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final workout = widget.workout;
    final isStrength = workout.type == 'strength';
    final strength = workout.strength;
    final running = workout.running;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F5F7),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.title != null) ...[
              Text(
                widget.title!,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 22),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _SummaryRow(
                        title: '운동 종류',
                        value: isStrength ? '헬스' : '러닝',
                      ),
                      const SizedBox(height: 14),
                      _SummaryRow(
                        title: '운동 시간',
                        value: _formatDuration(workout.durationSeconds),
                      ),
                      if (isStrength) ...[
                        const SizedBox(height: 14),
                        _SummaryRow(
                          title: '운동 종목',
                          value: '${strength?.exercises.length ?? 0}개',
                        ),
                        const SizedBox(height: 14),
                        _SummaryRow(
                          title: '완료 세트',
                          value: '${strength?.completedSetCount ?? 0}세트',
                        ),
                        const SizedBox(height: 14),
                        _SummaryRow(
                          title: '총 볼륨',
                          value:
                              '${_formatNumber(strength?.totalVolumeKg ?? 0)}kg',
                        ),
                      ] else ...[
                        const SizedBox(height: 14),
                        _SummaryRow(
                          title: '거리',
                          value:
                              '${((running?.distanceMeters ?? 0) / 1000).toStringAsFixed(2)} km',
                        ),
                        const SizedBox(height: 14),
                        _SummaryRow(
                          title: '평균 페이스',
                          value:
                              '${_formatPace(running?.averagePaceSecondsPerKm)}/km',
                        ),
                      ],
                    ],
                  ),
                ),
                if (isStrength) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => setState(() => _expanded = !_expanded),
                    borderRadius: BorderRadius.circular(22),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFF5B5FFF),
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (isStrength && _expanded) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Divider(height: 1, color: Color(0xFFD8DCE3)),
              ),
              ...?strength?.exercises.map(_buildExercise),
            ],
            if (widget.imageFile != null || workout.photoUrl != null) ...[
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: widget.imageFile != null
                    ? Image.file(
                        widget.imageFile!,
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        workout.photoUrl!,
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
              ),
            ],
            if (widget.onPhotoPressed != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: widget.onPhotoPressed,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(
                    widget.imageFile == null && workout.photoUrl == null
                        ? '인증샷 추가'
                        : '인증샷 변경',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF5B5FFF),
                    side: const BorderSide(
                      color: Color(0xFF5B5FFF),
                      width: 1.3,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExercise(StrengthExerciseData exercise) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exercise.name,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < exercise.sets.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  Text(
                    '${index + 1}세트',
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_formatNumber(exercise.sets[index].weightKg)}kg × ${exercise.sets[index].reps}회',
                    style: const TextStyle(
                      color: Color(0xFF111111),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) return '$hours시간 $minutes분';
    return '$minutes분';
  }

  String _formatPace(double? secondsPerKm) {
    if (secondsPerKm == null) return '-';
    final rounded = secondsPerKm.round();
    return '${rounded ~/ 60}\'${(rounded % 60).toString().padLeft(2, '0')}"';
  }

  String _formatNumber(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF666666),
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            color: Color(0xFF111111),
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
