import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../models/workout_record.dart';
import '../services/auth_service.dart';
import '../services/workout_service.dart';
import '../utils/experience_formatter.dart';
import '../widgets/workout_history_card.dart';
import 'settings_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  final Color pointColor = const Color(0xFF5B5FFF);
  final AuthService _authService = AuthService();
  final WorkoutService _workoutService = WorkoutService();

  String selectedSummaryPeriod = '주';
  String displayName = '';
  DateTime? experienceStartDate;
  bool isLoadingProfile = true;
  File? profileImageFile;
  late final Stream<List<WorkoutRecord>> _workoutsStream;
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
                    const Expanded(
                      child: Text(
                        '마이',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111111),
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
                      icon: const Icon(
                        Icons.settings_rounded,
                        size: 28,
                        color: Color(0xFF111111),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                _buildProfileCard(),

                const SizedBox(height: 18),

                _buildWorkoutSummaryCard(workouts, isLoading),

                const SizedBox(height: 18),

                _buildWorkoutCalendarCard(workouts),

                const SizedBox(height: 18),

                _buildProCard(),
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
                      const Text(
                        '프로필 수정',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111111),
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
                        child: const Text(
                          '프로필 사진 변경',
                          style: TextStyle(
                            color: Color(0xFF5B5FFF),
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
                          fillColor: const Color(0xFFF4F5F7),
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
                            color: const Color(0xFFF4F5F7),
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
                                        : const Color(0xFF111111),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.calendar_month_rounded,
                                color: Color(0xFF5B5FFF),
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
                  style: const TextStyle(
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

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: const Color(0xFFE5E7EB),
            backgroundImage: profileImageFile != null
                ? FileImage(profileImageFile!)
                : null,
            child: profileImageFile == null
                ? const Icon(
                    Icons.person_rounded,
                    color: Color(0xFF9CA3AF),
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
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isLoadingProfile ? '운동 경력 불러오는 중' : _experienceText(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
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
                color: pointColor,
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
        color: const Color(0xFFF4F5F7),
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
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111111),
                  ),
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
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '운동 캘린더',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '운동한 날을 한눈에 확인해요.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF666666),
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
                  color: Color(0xFF111111),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    displayedWorkoutMonth = DateTime(
                      monthStart.year,
                      monthStart.month - 1,
                    );
                    selectedWorkoutDate = null;
                  });
                },
                child: const Icon(
                  Icons.chevron_left_rounded,
                  color: Color(0xFF999999),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    displayedWorkoutMonth = DateTime(
                      monthStart.year,
                      monthStart.month + 1,
                    );
                    selectedWorkoutDate = null;
                  });
                },
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF999999),
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
                    color: isToday ? const Color(0xFF5B5FFF) : Colors.white,
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
                              : const Color(0xFF111111),
                        ),
                      ),

                      if (isWorkoutDay)
                        Positioned(
                          bottom: 7,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: isToday
                                  ? Colors.white
                                  : const Color(0xFF5B5FFF),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: selectedDate == null
          ? const Text(
              '날짜를 선택해주세요.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF777777),
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
                  return const Text(
                    '선택한 날짜의 운동 기록이 없어요.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF777777),
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
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final workout in records)
                      WorkoutHistoryCard(
                        key: ValueKey(workout.id),
                        workout: workout,
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
            '친구 제한 해제, 상세 통계, 같이 운동하기 기능 제공 예정',
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

class _SummaryBox extends StatelessWidget {
  final String title;
  final String value;

  const _SummaryBox({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF666666),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              color: Color(0xFF111111),
              fontWeight: FontWeight.w900,
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
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Color(0xFF777777),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? pointColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF666666),
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
