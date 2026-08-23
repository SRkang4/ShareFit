import 'package:flutter/material.dart';

import '../models/workout_record.dart';
import 'sharefit_ui.dart';

class WorkoutRecordSummaryCard extends StatelessWidget {
  const WorkoutRecordSummaryCard({
    super.key,
    required this.workout,
    required this.onTap,
  });

  final WorkoutRecord workout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isStrength = workout.type == 'strength';
    final strength = workout.strength;
    final running = workout.running;
    final photoUrl = workout.validPhotoUrl;

    return ShareFitCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isStrength
                  ? Icons.fitness_center_rounded
                  : Icons.directions_run_rounded,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isStrength ? '헬스' : '러닝',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      _formatTime(workout.endedAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  isStrength
                      ? _strengthSummary(strength, workout.durationSeconds)
                      : _runningSummary(running),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          if (photoUrl != null) ...[
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                photoUrl,
                width: 66,
                height: 66,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _strengthSummary(StrengthWorkoutData? data, int duration) {
    final bodyParts = data?.bodyParts.join(', ') ?? '';
    final prefix = bodyParts.isEmpty ? '운동 부위 미설정' : bodyParts;
    return '$prefix · ${_formatDuration(duration)}\n'
        '${data?.exercises.length ?? 0}종목 · ${data?.completedSetCount ?? 0}세트 · '
        '${_formatNumber(data?.totalVolumeKg ?? 0)}kg';
  }

  String _runningSummary(RunningWorkoutData? data) {
    return '${_formatDuration(workout.durationSeconds)} · '
        '${((data?.distanceMeters ?? 0) / 1000).toStringAsFixed(2)}km\n'
        '평균 페이스 ${_formatPace(data?.averagePaceSecondsPerKm)}/km';
  }
}

class WorkoutRecordDetailSheet extends StatefulWidget {
  const WorkoutRecordDetailSheet({
    super.key,
    required this.workout,
    required this.onDelete,
    this.onPhotoPressed,
    this.onSavePhotoPressed,
  });

  final WorkoutRecord workout;
  final Future<void> Function() onDelete;
  final Future<void> Function()? onPhotoPressed;
  final Future<void> Function()? onSavePhotoPressed;

  @override
  State<WorkoutRecordDetailSheet> createState() =>
      _WorkoutRecordDetailSheetState();
}

class _WorkoutRecordDetailSheetState extends State<WorkoutRecordDetailSheet> {
  bool _isDeleting = false;

  Future<void> _confirmDelete() async {
    if (_isDeleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: const Text('운동 기록을 삭제할까요?'),
          content: const Text('삭제한 기록은 복구할 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: colors.error),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await widget.onDelete();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final workout = widget.workout;
    final strength = workout.strength;
    final running = workout.running;
    final isStrength = workout.type == 'strength';
    final photoUrl = workout.validPhotoUrl;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, controller) => Material(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        clipBehavior: Clip.antiAlias,
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 36),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    isStrength ? '헬스 기록' : '러닝 기록',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _isDeleting ? null : _confirmDelete,
                  style: TextButton.styleFrom(foregroundColor: colors.error),
                  icon: _isDeleting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.error,
                          ),
                        )
                      : const Icon(Icons.delete_outline_rounded, size: 20),
                  label: Text(_isDeleting ? '삭제 중' : '삭제'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ShareFitCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _DetailRow(
                    label: '완료 일시',
                    value: _formatDateTime(workout.endedAt),
                  ),
                  _DetailRow(
                    label: '운동 시간',
                    value: _formatDuration(workout.durationSeconds),
                  ),
                  if (isStrength) ...[
                    _DetailRow(
                      label: '운동 부위',
                      value: strength?.bodyParts.isNotEmpty == true
                          ? strength!.bodyParts.join(', ')
                          : '-',
                    ),
                    _DetailRow(
                      label: '운동 종목',
                      value: '${strength?.exercises.length ?? 0}개',
                    ),
                    _DetailRow(
                      label: '완료 세트',
                      value: '${strength?.completedSetCount ?? 0}세트',
                    ),
                    _DetailRow(
                      label: '총 볼륨',
                      value: '${_formatNumber(strength?.totalVolumeKg ?? 0)}kg',
                      last: true,
                    ),
                  ] else ...[
                    _DetailRow(
                      label: '거리',
                      value:
                          '${((running?.distanceMeters ?? 0) / 1000).toStringAsFixed(2)}km',
                    ),
                    _DetailRow(
                      label: '평균 페이스',
                      value:
                          '${_formatPace(running?.averagePaceSecondsPerKm)}/km',
                      last: true,
                    ),
                  ],
                ],
              ),
            ),
            if (isStrength && strength?.exercises.isNotEmpty == true) ...[
              const SizedBox(height: 22),
              Text(
                '운동 상세',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              for (final exercise in strength!.exercises)
                _ExerciseDetailCard(exercise: exercise),
            ],
            if (photoUrl != null) ...[
              const SizedBox(height: 22),
              Text(
                '인증사진',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.network(
                  photoUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ],
            if (widget.onSavePhotoPressed != null ||
                widget.onPhotoPressed != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (widget.onSavePhotoPressed != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isDeleting
                            ? null
                            : widget.onSavePhotoPressed,
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('사진 저장'),
                      ),
                    ),
                  if (widget.onSavePhotoPressed != null &&
                      widget.onPhotoPressed != null)
                    const SizedBox(width: 10),
                  if (widget.onPhotoPressed != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isDeleting ? null : widget.onPhotoPressed,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: Text(photoUrl == null ? '인증사진 촬영' : '다시 촬영'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExerciseDetailCard extends StatelessWidget {
  const _ExerciseDetailCard({required this.exercise});

  final StrengthExerciseData exercise;

  @override
  Widget build(BuildContext context) {
    return ShareFitCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exercise.name.isEmpty ? '이름 없는 종목' : exercise.name,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < exercise.sets.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text('${index + 1}세트'),
                  const Spacer(),
                  Text(
                    '${_formatNumber(exercise.sets[index].weightKg)}kg × '
                    '${exercise.sets[index].reps}회',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.last = false,
  });

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
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

DateTime _seoul(DateTime value) => value.toUtc().add(const Duration(hours: 9));

String _formatTime(DateTime value) {
  final date = _seoul(value);
  final hour = date.hour > 12
      ? date.hour - 12
      : (date.hour == 0 ? 12 : date.hour);
  final period = date.hour < 12 ? '오전' : '오후';
  return '$period $hour:${date.minute.toString().padLeft(2, '0')}';
}

String _formatDateTime(DateTime value) {
  final date = _seoul(value);
  return '${date.year}.${date.month.toString().padLeft(2, '0')}.'
      '${date.day.toString().padLeft(2, '0')} ${_formatTime(value)}';
}
