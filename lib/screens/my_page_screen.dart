import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../models/advanced_stats.dart';
import '../models/profile_customization.dart';
import '../models/workout_record.dart';
import '../services/advanced_stats_service.dart';
import '../services/auth_service.dart';
import '../services/profile_customization_service.dart';
import '../services/workout_photo_save_service.dart';
import '../services/workout_service.dart';
import '../theme/app_theme.dart';
import '../theme/profile_card_theme.dart';
import '../utils/experience_formatter.dart';
import '../widgets/workout_history_card.dart';
import 'settings_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  Color get pointColor => Theme.of(context).colorScheme.primary;
  final AuthService _authService = AuthService();
  final AdvancedStatsService _advancedStatsService = AdvancedStatsService();
  final ProfileCustomizationService _profileCustomizationService =
      ProfileCustomizationService();
  final WorkoutService _workoutService = WorkoutService();
  final WorkoutPhotoSaveService _workoutPhotoSaveService =
      WorkoutPhotoSaveService();

  String selectedSummaryPeriod = '주';
  String displayName = '';
  DateTime? experienceStartDate;
  bool isLoadingProfile = true;
  bool isPro = false;
  ProfileCustomization profileCustomization = ProfileCustomization.defaults;
  File? profileImageFile;
  late final Stream<List<WorkoutRecord>> _workoutsStream;
  late Stream<AdvancedStats> _advancedStatsStream;
  late DateTime displayedWorkoutMonth;
  DateTime? selectedWorkoutDate;

  final TextEditingController nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    displayedWorkoutMonth = DateTime(now.year, now.month);
    selectedWorkoutDate = DateTime(now.year, now.month, now.day);
    _workoutsStream = _workoutService.watchCompletedWorkouts();
    _advancedStatsStream = _advancedStatsService.watchRecentSixMonths(
      displayedWorkoutMonth,
    );
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final userData = await _authService.getCurrentUserData();
      if (!mounted) {
        return;
      }

      final storedName = userData?['name'];
      final storedStartDate = userData?['experienceStartDate'];
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      DateTime? validStartDate;
      if (storedStartDate is Timestamp) {
        final parsedStartDate = storedStartDate.toDate();
        final normalizedStartDate = DateTime(
          parsedStartDate.year,
          parsedStartDate.month,
          parsedStartDate.day,
        );
        if (!normalizedStartDate.isAfter(today)) {
          validStartDate = normalizedStartDate;
        }
      }

      setState(() {
        displayName = storedName is String ? storedName : '';
        experienceStartDate = validStartDate;
        isPro = userData?['isPro'] == true;
        profileCustomization = ProfileCustomization.fromMap(
          userData?['profileCustomization'],
        );
        isLoadingProfile = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoadingProfile = false;
      });
      _showError('프로필 정보를 불러오지 못했습니다. 다시 시도해주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<WorkoutRecord>>(
          stream: _workoutsStream,
          builder: (context, snapshot) {
            final workouts = snapshot.data ?? const <WorkoutRecord>[];
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '마이',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),

                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.settings_rounded, size: 28),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                _buildProfileCard(),

                const SizedBox(height: 18),

                _buildWorkoutSummaryCard(workouts, isLoading),

                const SizedBox(height: 18),

                _buildWorkoutCalendarCard(workouts),

                if (!isLoadingProfile && isPro) ...[
                  const SizedBox(height: 18),
                  _buildAdvancedStatsCard(),
                ],

                if (!isLoadingProfile && !isPro) ...[
                  const SizedBox(height: 18),
                  _buildProCard(),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  void showEditProfileDialog() {
    nameController.text = displayName;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var selectedStartDate = experienceStartDate;
        var isSaving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '프로필 수정',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),

                      const SizedBox(height: 22),

                      GestureDetector(
                        onTap: pickProfileImage,
                        child: CircleAvatar(
                          radius: 42,
                          backgroundColor: const Color(0xFFE5E7EB),
                          backgroundImage: profileImageFile != null
                              ? FileImage(profileImageFile!)
                              : null,
                          child: profileImageFile == null
                              ? const Icon(
                                  Icons.person_rounded,
                                  size: 46,
                                  color: Color(0xFF9CA3AF),
                                )
                              : null,
                        ),
                      ),

                      const SizedBox(height: 10),

                      TextButton(
                        onPressed: pickProfileImage,
                        child: Text(
                          '프로필 사진 변경',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      TextField(
                        controller: nameController,
                        enabled: !isSaving,
                        decoration: InputDecoration(
                          hintText: '이름',
                          filled: true,
                          fillColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainer,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      GestureDetector(
                        onTap: isSaving
                            ? null
                            : () async {
                                final now = DateTime.now();
                                final today = DateTime(
                                  now.year,
                                  now.month,
                                  now.day,
                                );
                                final pickedDate = await showDatePicker(
                                  context: dialogContext,
                                  initialDate: selectedStartDate ?? today,
                                  firstDate: DateTime(1, 1, 1),
                                  lastDate: today,
                                );

                                if (!dialogContext.mounted ||
                                    pickedDate == null) {
                                  return;
                                }

                                setDialogState(() {
                                  selectedStartDate = pickedDate;
                                });
                              },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  selectedStartDate == null
                                      ? '운동 시작일'
                                      : _formatDate(selectedStartDate!),
                                  style: TextStyle(
                                    color: selectedStartDate == null
                                        ? const Color(0xFFB0B0B0)
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.calendar_month_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: OutlinedButton(
                                onPressed: isSaving
                                    ? null
                                    : () => Navigator.pop(dialogContext),
                                child: const Text('취소'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        final name = nameController.text.trim();
                                        if (name.isEmpty) {
                                          _showError('이름을 입력해주세요.');
                                          return;
                                        }
                                        if (selectedStartDate == null) {
                                          _showError('운동 시작일을 선택해주세요.');
                                          return;
                                        }

                                        setDialogState(() {
                                          isSaving = true;
                                        });

                                        try {
                                          await _authService
                                              .updateCurrentUserProfile(
                                                name: name,
                                                experienceStartDate:
                                                    selectedStartDate!,
                                              );
                                        } catch (_) {
                                          if (!mounted ||
                                              !dialogContext.mounted) {
                                            return;
                                          }
                                          setDialogState(() {
                                            isSaving = false;
                                          });
                                          _showError(
                                            '프로필 저장 중 오류가 발생했습니다. 다시 시도해주세요.',
                                          );
                                          return;
                                        }

                                        if (!mounted) {
                                          return;
                                        }
                                        setState(() {
                                          displayName = name;
                                          experienceStartDate =
                                              selectedStartDate;
                                        });

                                        if (dialogContext.mounted) {
                                          Navigator.pop(dialogContext);
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: pointColor,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: pointColor,
                                  disabledForegroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        '저장',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}.$month.$day';
  }

  String _experienceText() {
    return formatWorkoutExperience(experienceStartDate);
  }

  void _showError(String message) {
    showTopSnackBar(
      Overlay.of(context),
      Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: pointColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      displayDuration: const Duration(seconds: 2),
    );
  }

  Future<void> _saveWorkoutPhoto(WorkoutRecord workout) async {
    final workoutId = workout.id;
    final photoUrl = workout.validPhotoUrl;
    if (workoutId == null ||
        photoUrl == null ||
        workout.userId != _workoutService.currentUserId) {
      return;
    }

    try {
      await _workoutPhotoSaveService.save(
        workoutId: workoutId,
        photoUrl: photoUrl,
      );
      if (mounted) _showError('사진을 저장했습니다.');
    } on WorkoutPhotoSaveException catch (error) {
      if (mounted) _showError(error.userMessage);
    } catch (_) {
      if (mounted) _showError('사진을 저장하지 못했습니다. 다시 시도해주세요.');
    }
  }

  Widget _buildProfileCard() {
    final effectiveCustomization = isPro
        ? profileCustomization
        : ProfileCustomization.defaults;
    final palette = ProfileCardPalette.resolve(
      context,
      effectiveCustomization.themeId,
    );
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: palette.accent,
                backgroundImage: profileImageFile != null
                    ? FileImage(profileImageFile!)
                    : null,
                child: profileImageFile == null
                    ? const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 38,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLoadingProfile
                          ? '불러오는 중'
                          : (displayName.isEmpty ? '이름 미설정' : displayName),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: palette.foreground,
                      ),
                    ),
                    if (!isLoadingProfile &&
                        effectiveCustomization.titleLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        effectiveCustomization.titleLabel!,
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      isLoadingProfile ? '운동 경력 불러오는 중' : _experienceText(),
                      style: TextStyle(
                        fontSize: 14,
                        color: palette.secondaryForeground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: showEditProfileDialog,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: palette.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ),
            ],
          ),
          if (!isLoadingProfile && isPro) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showProfileCustomizationDialog,
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.foreground,
                  side: BorderSide(color: palette.accent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: Icon(Icons.auto_awesome_rounded, color: palette.accent),
                label: const Text(
                  '프로필 꾸미기',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showProfileCustomizationDialog() {
    if (!isPro) return;
    var selectedTitleId = profileCustomization.titleId;
    var selectedThemeId = profileCustomization.themeId;
    var isSaving = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final previewCustomization = ProfileCustomization(
            titleId: selectedTitleId,
            themeId: selectedThemeId,
          );
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '프로필 꾸미기',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 16),
                  _ProfileCustomizationPreview(
                    name: displayName.isEmpty ? '이름 미설정' : displayName,
                    experience: _experienceText(),
                    customization: previewCustomization,
                  ),
                  const SizedBox(height: 20),
                  const _AdvancedLabel('칭호'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in ProfileTitleIds.labels.entries)
                        _CustomizationChoice(
                          label: entry.value,
                          selected: selectedTitleId == entry.key,
                          onTap: isSaving
                              ? null
                              : () => setDialogState(
                                  () => selectedTitleId = entry.key,
                                ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const _AdvancedLabel('프로필 카드 테마'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in ProfileThemeIds.labels.entries)
                        _CustomizationChoice(
                          label: entry.value,
                          selected: selectedThemeId == entry.key,
                          previewColor: ProfileCardPalette.resolve(
                            context,
                            entry.key,
                          ).accent,
                          onTap: isSaving
                              ? null
                              : () => setDialogState(
                                  () => selectedThemeId = entry.key,
                                ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isSaving
                              ? null
                              : () => Navigator.pop(dialogContext),
                          child: const Text('취소'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  setDialogState(() => isSaving = true);
                                  try {
                                    await _profileCustomizationService.save(
                                      previewCustomization,
                                    );
                                  } on ProfileCustomizationException catch (
                                    error
                                  ) {
                                    if (mounted && dialogContext.mounted) {
                                      setDialogState(() => isSaving = false);
                                      _showError(error.message);
                                    }
                                    return;
                                  } catch (_) {
                                    if (mounted && dialogContext.mounted) {
                                      setDialogState(() => isSaving = false);
                                      _showError(
                                        '프로필 설정을 저장하지 못했습니다. 다시 시도해주세요.',
                                      );
                                    }
                                    return;
                                  }

                                  if (!mounted || !dialogContext.mounted) {
                                    return;
                                  }
                                  setState(() {
                                    profileCustomization = previewCustomization;
                                  });
                                  Navigator.pop(dialogContext);
                                  _showError('프로필 설정을 저장했습니다.');
                                },
                          child: isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.3,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('저장'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWorkoutSummaryCard(
    List<WorkoutRecord> workouts,
    bool isLoading,
  ) {
    final summary = _calculateWorkoutSummary(workouts);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '운동 요약',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
              ),

              _SummaryPeriodButton(
                title: '주',
                selected: selectedSummaryPeriod == '주',
                pointColor: pointColor,
                onTap: () {
                  setState(() {
                    selectedSummaryPeriod = '주';
                  });
                },
              ),

              const SizedBox(width: 6),

              _SummaryPeriodButton(
                title: '달',
                selected: selectedSummaryPeriod == '달',
                pointColor: pointColor,
                onTap: () {
                  setState(() {
                    selectedSummaryPeriod = '달';
                  });
                },
              ),

              const SizedBox(width: 6),

              _SummaryPeriodButton(
                title: '총',
                selected: selectedSummaryPeriod == '총',
                pointColor: pointColor,
                onTap: () {
                  setState(() {
                    selectedSummaryPeriod = '총';
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _SummaryBox(
                  title: '운동 일수',
                  value: isLoading ? '...' : '${summary.workoutDays}일',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryBox(
                  title: '운동 시간',
                  value: isLoading
                      ? '...'
                      : _formatSummaryDuration(summary.durationSeconds),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _SummaryBox(
                  title: '헬스 볼륨',
                  value: isLoading
                      ? '...'
                      : '${_formatNumber(summary.totalVolumeKg)}kg',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryBox(
                  title: '러닝 거리',
                  value: isLoading
                      ? '...'
                      : '${(summary.runningDistanceMeters / 1000).toStringAsFixed(1)}km',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  _WorkoutSummaryTotals _calculateWorkoutSummary(List<WorkoutRecord> workouts) {
    final now = DateTime.now();
    final weekStartDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - DateTime.monday));
    final monthStartDate = DateTime(now.year, now.month);

    final filtered = workouts.where((workout) {
      final endedAt = workout.endedAt.toLocal();
      if (endedAt.isAfter(now)) {
        return false;
      }
      if (selectedSummaryPeriod == '주') {
        return !endedAt.isBefore(weekStartDate);
      }
      if (selectedSummaryPeriod == '달') {
        return !endedAt.isBefore(monthStartDate);
      }
      return true;
    }).toList();

    final workoutDates = <String>{};
    var durationSeconds = 0;
    var totalVolumeKg = 0.0;
    var runningDistanceMeters = 0.0;

    for (final workout in filtered) {
      final endedAt = workout.endedAt.toLocal();
      workoutDates.add('${endedAt.year}-${endedAt.month}-${endedAt.day}');
      durationSeconds += workout.durationSeconds;
      totalVolumeKg += workout.strength?.totalVolumeKg ?? 0;
      runningDistanceMeters += workout.running?.distanceMeters ?? 0;
    }

    return _WorkoutSummaryTotals(
      workoutDays: workoutDates.length,
      durationSeconds: durationSeconds,
      totalVolumeKg: totalVolumeKg,
      runningDistanceMeters: runningDistanceMeters,
    );
  }

  String _formatSummaryDuration(int durationSeconds) {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  }

  String _formatNumber(double value) {
    final raw = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
    return raw.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
  }

  void _setDisplayedWorkoutMonth(DateTime month) {
    final normalized = DateTime(month.year, month.month);
    setState(() {
      displayedWorkoutMonth = normalized;
      selectedWorkoutDate = null;
      _advancedStatsStream = _advancedStatsService.watchRecentSixMonths(
        normalized,
      );
    });
  }

  Widget _buildAdvancedStatsCard() {
    return StreamBuilder<AdvancedStats>(
      stream: _advancedStatsStream,
      builder: (context, snapshot) {
        final background = Theme.of(context).colorScheme.surfaceContainer;
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '고급 통계',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                '${displayedWorkoutMonth.year}년 ${displayedWorkoutMonth.month}월과 최근 6개월 분석',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              else if (snapshot.hasError || !snapshot.hasData)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    '고급 통계를 불러오지 못했어요.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else ...[
                _buildStrengthAdvancedStats(snapshot.data!),
                const SizedBox(height: 14),
                _buildRunningAdvancedStats(snapshot.data!),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStrengthAdvancedStats(AdvancedStats stats) {
    final selected = stats.selectedMonthStats;
    final maxBodyPartVolume = stats.bodyPartVolumeKg.values.fold<double>(
      0,
      math.max,
    );
    return _AdvancedSection(
      icon: Icons.fitness_center_rounded,
      title: '헬스',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AdvancedMetric(
            title: '${stats.selectedMonth.month}월 총 볼륨',
            value: '${_formatNumber(selected.strengthVolumeKg)}kg',
          ),
          const SizedBox(height: 18),
          const _AdvancedLabel('부위별 볼륨'),
          const SizedBox(height: 10),
          for (final part in AdvancedStatsService.bodyParts)
            _BodyPartVolumeRow(
              label: part,
              value: stats.bodyPartVolumeKg[part] ?? 0,
              maxValue: maxBodyPartVolume,
            ),
          if (stats.unassignedStrengthVolumeKg > 0) ...[
            const SizedBox(height: 4),
            Text(
              '복합/미분류 ${_formatNumber(stats.unassignedStrengthVolumeKg)}kg',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 18),
          const _AdvancedLabel('최근 6개월 월별 볼륨'),
          const SizedBox(height: 10),
          _MonthlyTrendChart(
            months: stats.months,
            values: stats.months
                .map<double?>((month) => month.strengthVolumeKg)
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRunningAdvancedStats(AdvancedStats stats) {
    final selected = stats.selectedMonthStats;
    return _AdvancedSection(
      icon: Icons.directions_run_rounded,
      title: '러닝',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _AdvancedMetric(
                  title: '${stats.selectedMonth.month}월 총 거리',
                  value:
                      '${(selected.runningDistanceMeters / 1000).toStringAsFixed(1)}km',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AdvancedMetric(
                  title: '${stats.selectedMonth.month}월 평균 페이스',
                  value: _formatAdvancedPace(selected.averagePaceSecondsPerKm),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _AdvancedLabel('최근 6개월 월별 거리'),
          const SizedBox(height: 10),
          _MonthlyTrendChart(
            months: stats.months,
            values: stats.months
                .map<double?>((month) => month.runningDistanceMeters)
                .toList(),
          ),
          const SizedBox(height: 18),
          const _AdvancedLabel('최근 6개월 평균 페이스'),
          const SizedBox(height: 10),
          _MonthlyTrendChart(
            months: stats.months,
            values: stats.months
                .map<double?>((month) => month.averagePaceSecondsPerKm)
                .toList(),
          ),
          const SizedBox(height: 6),
          Text(
            '페이스는 낮을수록 빨라요.',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAdvancedPace(double? secondsPerKm) {
    if (secondsPerKm == null || !secondsPerKm.isFinite || secondsPerKm <= 0) {
      return '-';
    }
    final totalSeconds = secondsPerKm.round();
    final minutes = totalSeconds ~/ 60;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return "$minutes'$seconds\"/km";
  }

  Widget _buildWorkoutCalendarCard(List<WorkoutRecord> workouts) {
    final monthStart = displayedWorkoutMonth;
    final nextMonth = DateTime(monthStart.year, monthStart.month + 1);
    final daysInMonth = nextMonth.subtract(const Duration(days: 1)).day;
    final leadingDays = monthStart.weekday % 7;
    final itemCount = ((leadingDays + daysInMonth + 6) ~/ 7) * 7;
    final monthWorkouts = workouts.where((workout) {
      final endedAt = _toSeoulTime(workout.endedAt);
      return endedAt.year == monthStart.year &&
          endedAt.month == monthStart.month;
    }).toList();
    final workoutDays = monthWorkouts
        .map((workout) => _toSeoulTime(workout.endedAt).day)
        .toSet();
    final selectedDate = selectedWorkoutDate;
    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    final isCurrentMonth =
        now.year == monthStart.year && now.month == monthStart.month;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '운동 캘린더',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '운동한 날을 한눈에 확인해요.',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Text(
                '${monthStart.year}년 ${monthStart.month}월',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  _setDisplayedWorkoutMonth(
                    DateTime(monthStart.year, monthStart.month - 1),
                  );
                },
                child: Icon(
                  Icons.chevron_left_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  _setDisplayedWorkoutMonth(
                    DateTime(monthStart.year, monthStart.month + 1),
                  );
                },
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _WeekdayText('일'),
              _WeekdayText('월'),
              _WeekdayText('화'),
              _WeekdayText('수'),
              _WeekdayText('목'),
              _WeekdayText('금'),
              _WeekdayText('토'),
            ],
          ),

          const SizedBox(height: 12),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: itemCount,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final day = index - leadingDays + 1;

              if (day <= 0 || day > daysInMonth) {
                return const SizedBox();
              }

              final isWorkoutDay = workoutDays.contains(day);
              final isToday = isCurrentMonth && day == now.day;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedWorkoutDate = DateTime(
                      monthStart.year,
                      monthStart.month,
                      day,
                    );
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isToday
                        ? pointColor
                        : Theme.of(context).colorScheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isToday
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),

                      if (isWorkoutDay)
                        Positioned(
                          bottom: 7,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: isToday ? Colors.white : pointColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 18),

          _buildSelectedDateWorkouts(selectedDate),
        ],
      ),
    );
  }

  DateTime _toSeoulTime(DateTime dateTime) {
    return dateTime.toUtc().add(const Duration(hours: 9));
  }

  Widget _buildSelectedDateWorkouts(DateTime? selectedDate) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: selectedDate == null
          ? Text(
              '날짜를 선택해주세요.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: context.secondaryForegroundFor(
                  Theme.of(context).colorScheme.surfaceContainerHigh,
                ),
              ),
            )
          : StreamBuilder<List<WorkoutRecord>>(
              key: ValueKey(
                '${selectedDate.year}-${selectedDate.month}-${selectedDate.day}',
              ),
              stream: _workoutService.watchWorkoutsForDate(selectedDate),
              builder: (context, snapshot) {
                final records = snapshot.data ?? const <WorkoutRecord>[];
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  );
                }
                if (records.isEmpty) {
                  return Text(
                    '선택한 날짜의 운동 기록이 없어요.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: context.secondaryForegroundFor(
                        Theme.of(context).colorScheme.surfaceContainerHigh,
                      ),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${selectedDate.year}년 ${selectedDate.month}월 ${selectedDate.day}일',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final workout in records)
                      WorkoutHistoryCard(
                        key: ValueKey(workout.id),
                        workout: workout,
                        onSavePhotoPressed:
                            workout.id != null &&
                                workout.userId ==
                                    _workoutService.currentUserId &&
                                workout.hasValidPhoto
                            ? () => _saveWorkoutPhoto(workout)
                            : null,
                      ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildProCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: pointColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ShareFit Pro',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '친구 제한 해제\n인증 사진 무제한\n운동 기록 분석과 특별 기능 제공',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '업그레이드',
              style: TextStyle(
                color: pointColor,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> pickProfileImage() async {
    final picker = ImagePicker();

    final pickedImage = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedImage == null) return;

    setState(() {
      profileImageFile = File(pickedImage.path);
    });
  }
}

class _ProfileCustomizationPreview extends StatelessWidget {
  const _ProfileCustomizationPreview({
    required this.name,
    required this.experience,
    required this.customization,
  });

  final String name;
  final String experience;
  final ProfileCustomization customization;

  @override
  Widget build(BuildContext context) {
    final palette = ProfileCardPalette.resolve(context, customization.themeId);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: palette.accent,
            child: const Icon(Icons.person_rounded, color: Colors.white),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: palette.foreground,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (customization.titleLabel != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    customization.titleLabel!,
                    style: TextStyle(
                      color: palette.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  experience,
                  style: TextStyle(
                    color: palette.secondaryForeground,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomizationChoice extends StatelessWidget {
  const _CustomizationChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.previewColor,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? previewColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? colors.primary : colors.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (previewColor != null) ...[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : previewColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : colors.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdvancedSection extends StatelessWidget {
  const _AdvancedSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _AdvancedMetric extends StatelessWidget {
  const _AdvancedMetric({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _AdvancedLabel extends StatelessWidget {
  const _AdvancedLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
    );
  }
}

class _BodyPartVolumeRow extends StatelessWidget {
  const _BodyPartVolumeRow({
    required this.label,
    required this.value,
    required this.maxValue,
  });

  final String label;
  final double value;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ratio = maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: colors.surfaceContainer,
                color: colors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 62,
            child: Text(
              '${_formatCompactNumber(value)}kg',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatCompactNumber(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}

class _MonthlyTrendChart extends StatelessWidget {
  const _MonthlyTrendChart({required this.months, required this.values});

  final List<MonthlyAdvancedStats> months;
  final List<double?> values;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          height: 104,
          width: double.infinity,
          child: CustomPaint(
            painter: _TrendPainter(
              values: values,
              lineColor: colors.primary,
              gridColor: colors.outline.withValues(alpha: 0.45),
              emptyColor: colors.onSurfaceVariant.withValues(alpha: 0.45),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final month in months)
              Expanded(
                child: Text(
                  '${month.month}월',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.values,
    required this.lineColor,
    required this.gridColor,
    required this.emptyColor,
  });

  final List<double?> values;
  final Color lineColor;
  final Color gridColor;
  final Color emptyColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index < 3; index++) {
      final y = size.height * index / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final validValues = values.whereType<double>().where(
      (value) => value.isFinite,
    );
    if (validValues.isEmpty) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: '데이터 없음',
          style: TextStyle(
            color: emptyColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(
          (size.width - textPainter.width) / 2,
          (size.height - textPainter.height) / 2,
        ),
      );
      return;
    }

    final minimum = validValues.reduce(math.min);
    final maximum = validValues.reduce(math.max);
    final range = maximum - minimum;
    final horizontalStep = values.length == 1
        ? 0.0
        : size.width / (values.length - 1);
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = lineColor;

    Path? segment;
    var segmentHasPoint = false;
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      if (value == null || !value.isFinite) {
        if (segment != null) canvas.drawPath(segment, linePaint);
        segment = null;
        segmentHasPoint = false;
        continue;
      }
      final normalized = range == 0 ? 0.5 : (value - minimum) / range;
      final point = Offset(
        horizontalStep * index,
        size.height - (normalized * (size.height - 16)) - 8,
      );
      segment ??= Path();
      if (!segmentHasPoint) {
        segment.moveTo(point.dx, point.dy);
        segmentHasPoint = true;
      } else {
        segment.lineTo(point.dx, point.dy);
      }
      canvas.drawCircle(point, 3.5, dotPaint);
    }
    if (segment != null) canvas.drawPath(segment, linePaint);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.gridColor != gridColor;
}

class _SummaryBox extends StatelessWidget {
  final String title;
  final String value;

  const _SummaryBox({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final background = context.colors.surfaceContainerHigh;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: context.secondaryForegroundFor(background),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: context.foregroundFor(background),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekdayText extends StatelessWidget {
  final String text;

  const _WeekdayText(this.text);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SummaryPeriodButton extends StatelessWidget {
  final String title;
  final bool selected;
  final Color pointColor;
  final VoidCallback onTap;

  const _SummaryPeriodButton({
    required this.title,
    required this.selected,
    required this.pointColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final background = selected
        ? pointColor
        : Theme.of(context).colorScheme.surfaceContainerHigh;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: selected
                ? Colors.white
                : context.secondaryForegroundFor(background),
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _WorkoutSummaryTotals {
  const _WorkoutSummaryTotals({
    required this.workoutDays,
    required this.durationSeconds,
    required this.totalVolumeKg,
    required this.runningDistanceMeters,
  });

  final int workoutDays;
  final int durationSeconds;
  final double totalVolumeKg;
  final double runningDistanceMeters;
}
