import 'package:flutter/material.dart';

import '../models/ranking_entry.dart';
import '../services/ranking_service.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  final Color pointColor = const Color(0xFF5B5FFF);
  final RankingService rankingService = RankingService();
  RankingPeriod selectedPeriod = RankingPeriod.week;

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
            StreamBuilder<List<RankingEntry>>(
              key: ValueKey(selectedPeriod),
              stream: rankingService.watchRankings(selectedPeriod),
              builder: (context, snapshot) {
                final entries = snapshot.data ?? const <RankingEntry>[];
                if (snapshot.connectionState == ConnectionState.waiting &&
                    entries.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final daysRanking = [...entries]..sort(_compareWorkoutDays);
                final timeRanking = [...entries]..sort(_compareWorkoutTime);
                return Column(
                  children: [
                    _RankingSection(
                      title: '운동 일수',
                      rankings: daysRanking,
                      valueBuilder: (entry) => '${entry.workoutDays}일',
                      pointColor: pointColor,
                    ),
                    const SizedBox(height: 18),
                    _RankingSection(
                      title: '운동 시간',
                      rankings: timeRanking,
                      valueBuilder: (entry) =>
                          _formatDuration(entry.durationSeconds),
                      pointColor: pointColor,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  int _compareWorkoutDays(RankingEntry first, RankingEntry second) {
    final primary = second.workoutDays.compareTo(first.workoutDays);
    if (primary != 0) return primary;
    final secondary = second.durationSeconds.compareTo(first.durationSeconds);
    if (secondary != 0) return secondary;
    final name = first.name.compareTo(second.name);
    return name != 0 ? name : first.uid.compareTo(second.uid);
  }

  int _compareWorkoutTime(RankingEntry first, RankingEntry second) {
    final primary = second.durationSeconds.compareTo(first.durationSeconds);
    if (primary != 0) return primary;
    final secondary = second.workoutDays.compareTo(first.workoutDays);
    if (secondary != 0) return secondary;
    final name = first.name.compareTo(second.name);
    return name != 0 ? name : first.uid.compareTo(second.uid);
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours == 0) return '$minutes분';
    return '$hours시간 $minutes분';
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
            selected: selectedPeriod == RankingPeriod.week,
            pointColor: pointColor,
            onTap: () => setState(() => selectedPeriod = RankingPeriod.week),
          ),
          _PeriodButton(
            title: '이번 달',
            selected: selectedPeriod == RankingPeriod.month,
            pointColor: pointColor,
            onTap: () => setState(() => selectedPeriod = RankingPeriod.month),
          ),
        ],
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({
    required this.title,
    required this.selected,
    required this.pointColor,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final Color pointColor;
  final VoidCallback onTap;

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
  const _RankingSection({
    required this.title,
    required this.rankings,
    required this.valueBuilder,
    required this.pointColor,
  });

  final String title;
  final List<RankingEntry> rankings;
  final String Function(RankingEntry) valueBuilder;
  final Color pointColor;

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
          for (var index = 0; index < rankings.length; index++)
            _RankingRow(
              rank: index + 1,
              data: rankings[index],
              value: valueBuilder(rankings[index]),
              pointColor: pointColor,
            ),
        ],
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.rank,
    required this.data,
    required this.value,
    required this.pointColor,
  });

  final int rank;
  final RankingEntry data;
  final String value;
  final Color pointColor;

  @override
  Widget build(BuildContext context) {
    final isFirst = rank == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    data.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111111),
                    ),
                  ),
                ),
                if (data.isCurrentUser) ...[
                  const SizedBox(width: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: pointColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '나',
                      style: TextStyle(
                        color: pointColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
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
