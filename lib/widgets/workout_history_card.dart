import 'dart:io';

import 'package:flutter/material.dart';

import '../models/workout_record.dart';
import '../theme/app_theme.dart';
import 'sharefit_ui.dart';

class WorkoutHistoryCard extends StatefulWidget {
  const WorkoutHistoryCard({
    super.key,
    required this.workout,
    this.title,
    this.imageFile,
    this.onPhotoPressed,
    this.onSavePhotoPressed,
  });

  final WorkoutRecord workout;
  final String? title;
  final File? imageFile;
  final VoidCallback? onPhotoPressed;
  final Future<void> Function()? onSavePhotoPressed;

  @override
  State<WorkoutHistoryCard> createState() => _WorkoutHistoryCardState();
}

class _WorkoutHistoryCardState extends State<WorkoutHistoryCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  bool _isSavingPhoto = false;

  Future<void> _savePhoto() async {
    if (_isSavingPhoto || widget.onSavePhotoPressed == null) return;
    setState(() => _isSavingPhoto = true);
    try {
      await widget.onSavePhotoPressed!();
    } finally {
      if (mounted) setState(() => _isSavingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final workout = widget.workout;
    final isStrength = workout.type == 'strength';
    final strength = workout.strength;
    final running = workout.running;
    final photoUrl = workout.validPhotoUrl;
    final hasRemotePhoto = photoUrl != null;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: ShareFitCard(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.title != null) ...[
              Text(
                widget.title!,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: colors.onSurface,
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
                        color: colors.primary,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (isStrength && _expanded) ...[
              Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Divider(height: 1, color: colors.outlineVariant),
              ),
              ...?strength?.exercises.map(_buildExercise),
            ],
            if (widget.imageFile != null || hasRemotePhoto) ...[
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
                        photoUrl!,
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
              ),
            ],
            if (hasRemotePhoto && widget.onSavePhotoPressed != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _isSavingPhoto ? null : _savePhoto,
                  icon: _isSavingPhoto
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.download_rounded),
                  label: Text(_isSavingPhoto ? '저장 중' : '사진 저장'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary, width: 1.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
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
                    widget.imageFile == null && !hasRemotePhoto
                        ? '인증사진 촬영'
                        : '인증사진 다시 촬영',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary, width: 1.3),
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
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
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
                    style: TextStyle(
                      color: context.secondaryForegroundFor(
                        Theme.of(context).colorScheme.surfaceContainer,
                      ),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_formatNumber(exercise.sets[index].weightKg)}kg × ${exercise.sets[index].reps}회',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
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
          style: TextStyle(
            fontSize: 15,
            color: context.secondaryForegroundFor(
              Theme.of(context).colorScheme.surfaceContainer,
            ),
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
