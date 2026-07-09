import 'package:flutter/material.dart';
import 'settings_screen.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  final Color pointColor = const Color(0xFF5B5FFF);

  String selectedSummaryPeriod = '주';
  String displayName = '강현';
  File? profileImageFile;

  final TextEditingController nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
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

            _buildWorkoutSummaryCard(),

            const SizedBox(height: 18),

            _buildWorkoutCalendarCard(),

            const SizedBox(height: 18),

            _buildProCard(),
          ],
        ),
      ),
    );
  }

  void showEditProfileDialog() {
    nameController.text = displayName;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
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

                const SizedBox(height: 22),

                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text('취소'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              displayName = nameController.text.trim().isEmpty
                                  ? displayName
                                  : nameController.text.trim();
                            });

                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: pointColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            '저장',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
                  displayName,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111111),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '운동 3년차',
                  style: TextStyle(
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

  Widget _buildWorkoutSummaryCard() {
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
                  value: selectedSummaryPeriod == '주'
                      ? '3일'
                      : selectedSummaryPeriod == '달'
                      ? '14일'
                      : '86일',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryBox(
                  title: '운동 시간',
                  value: selectedSummaryPeriod == '주'
                      ? '4h 20m'
                      : selectedSummaryPeriod == '달'
                      ? '22h 10m'
                      : '143h',
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
                  value: selectedSummaryPeriod == '주'
                      ? '42,000kg'
                      : selectedSummaryPeriod == '달'
                      ? '183,000kg'
                      : '1,240,000kg',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryBox(
                  title: '러닝 거리',
                  value: selectedSummaryPeriod == '주'
                      ? '8.4km'
                      : selectedSummaryPeriod == '달'
                      ? '41.8km'
                      : '302.5km',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutCalendarCard() {
    final workoutDays = [3, 7, 12, 18, 24, 28];
    final today = 28;

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
            children: const [
              Text(
                '2026년 5월',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111111),
                ),
              ),
              Spacer(),
              Icon(
                Icons.chevron_left_rounded,
                color: Color(0xFF999999),
              ),
              SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF999999),
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
            itemCount: 35,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final day = index - 4;

              if (day <= 0 || day > 31) {
                return const SizedBox();
              }

              final isWorkoutDay = workoutDays.contains(day);
              final isToday = day == today;

              return Container(
                decoration: BoxDecoration(
                  color: isToday
                      ? const Color(0xFF5B5FFF)
                      : Colors.white,
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
              );
            },
          ),

          const SizedBox(height: 18),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '5월 28일 · 헬스 1시간 12분',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111111),
              ),
            ),
          ),
        ],
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

  const _SummaryBox({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 16,
      ),
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