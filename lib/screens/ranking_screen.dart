import 'package:flutter/material.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  final Color pointColor = const Color(0xFF5B5FFF);

  String selectedPeriod = '이번 주';

  final List<RankingData> workoutDaysRanking = [
    RankingData(name: '민수', value: '6일'),
    RankingData(name: '현우', value: '5일'),
    RankingData(name: '준호', value: '4일'),
  ];

  final List<RankingData> workoutTimeRanking = [
    RankingData(name: '현우', value: '11시간 24분'),
    RankingData(name: '민수', value: '9시간 42분'),
    RankingData(name: '준호', value: '8시간 10분'),
  ];

  final List<RankingData> healthVolumeRanking = [
    RankingData(name: '민수', value: '124,000kg'),
    RankingData(name: '준호', value: '101,500kg'),
    RankingData(name: '현우', value: '92,300kg'),
  ];

  final List<RankingData> runningDistanceRanking = [
    RankingData(name: '현우', value: '42.2km'),
    RankingData(name: '민수', value: '31.8km'),
    RankingData(name: '준호', value: '24.5km'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            const Text(
              '랭킹',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111111),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '친구들과 운동 기록을 비교해보세요.',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF666666),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 26),

            _buildPeriodSelector(),

            const SizedBox(height: 28),

            _RankingSection(
              title: '운동 일수',
              rankings: workoutDaysRanking,
              pointColor: pointColor,
            ),

            const SizedBox(height: 18),

            _RankingSection(
              title: '운동 시간',
              rankings: workoutTimeRanking,
              pointColor: pointColor,
            ),

            const SizedBox(height: 30),

            const Text(
              '헬스',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111111),
              ),
            ),

            const SizedBox(height: 14),

            _RankingSection(
              title: '총 볼륨',
              rankings: healthVolumeRanking,
              pointColor: pointColor,
            ),

            const SizedBox(height: 30),

            const Text(
              '러닝',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111111),
              ),
            ),

            const SizedBox(height: 14),

            _RankingSection(
              title: '총 거리',
              rankings: runningDistanceRanking,
              pointColor: pointColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _PeriodButton(
            title: '이번 주',
            selected: selectedPeriod == '이번 주',
            pointColor: pointColor,
            onTap: () {
              setState(() {
                selectedPeriod = '이번 주';
              });
            },
          ),
          _PeriodButton(
            title: '이번 달',
            selected: selectedPeriod == '이번 달',
            pointColor: pointColor,
            onTap: () {
              setState(() {
                selectedPeriod = '이번 달';
              });
            },
          ),
        ],
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  final String title;
  final bool selected;
  final Color pointColor;
  final VoidCallback onTap;

  const _PeriodButton({
    required this.title,
    required this.selected,
    required this.pointColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? pointColor : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF666666),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _RankingSection extends StatelessWidget {
  final String title;
  final List<RankingData> rankings;
  final Color pointColor;

  const _RankingSection({
    required this.title,
    required this.rankings,
    required this.pointColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(
            rankings.length,
                (index) => _RankingRow(
              rank: index + 1,
              data: rankings[index],
              pointColor: pointColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  final int rank;
  final RankingData data;
  final Color pointColor;

  const _RankingRow({
    required this.rank,
    required this.data,
    required this.pointColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isFirst = rank == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: isFirst ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              _rankLabel(rank),
              style: TextStyle(
                fontSize: isFirst ? 22 : 17,
                fontWeight: FontWeight.w900,
                color: isFirst ? pointColor : const Color(0xFF111111),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              data.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111111),
              ),
            ),
          ),
          Text(
            data.value,
            style: TextStyle(
              fontSize: isFirst ? 17 : 15,
              fontWeight: FontWeight.w900,
              color: isFirst ? pointColor : const Color(0xFF111111),
            ),
          ),
        ],
      ),
    );
  }

  String _rankLabel(int rank) {
    if (rank == 1) return '🥇';
    if (rank == 2) return '🥈';
    if (rank == 3) return '🥉';
    return '$rank';
  }
}

class RankingData {
  final String name;
  final String value;

  RankingData({
    required this.name,
    required this.value,
  });
}