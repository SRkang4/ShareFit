import 'package:flutter/material.dart';

import '../models/ranking_entry.dart';
import '../services/auth_service.dart';
import '../services/ranking_service.dart';
import '../theme/app_theme.dart';
import '../utils/competition_ranking.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  Color get pointColor => Theme.of(context).colorScheme.primary;
  final RankingService rankingService = RankingService();
  final AuthService authService = AuthService();
  RankingPeriod selectedPeriod = RankingPeriod.week;
  late final Future<bool> isProFuture;

  @override
  void initState() {
    super.initState();
    isProFuture = authService.getCurrentUserData().then(
      (userData) => userData?['isPro'] == true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            Text(
              '랭킹',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '친구들과 운동 기록을 비교해보세요.',
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 26),
            _buildPeriodSelector(),
            const SizedBox(height: 28),
            FutureBuilder<bool>(
              future: isProFuture,
              builder: (context, proSnapshot) {
                if (proSnapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final isPro = proSnapshot.data == true;
                return StreamBuilder<List<RankingEntry>>(
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

                    final sortedByDays = [...entries]
                      ..sort(_compareWorkoutDays);
                    final sortedByTime = [...entries]
                      ..sort(_compareWorkoutTime);
                    final daysRanking = assignCompetitionRanks(
                      sortedByDays,
                      (entry) => entry.workoutDays,
                    );
                    final timeRanking = assignCompetitionRanks(
                      sortedByTime,
                      (entry) => entry.durationSeconds,
                    );
                    final sortedByStrengthVolume = isPro
                        ? ([...entries]..sort(_compareStrengthVolume))
                        : const <RankingEntry>[];
                    final sortedByRunningDistance = isPro
                        ? ([...entries]..sort(_compareRunningDistance))
                        : const <RankingEntry>[];
                    final strengthVolumeRanking = assignCompetitionRanks(
                      sortedByStrengthVolume,
                      (entry) => entry.strengthVolumeKg,
                    );
                    final runningDistanceRanking = assignCompetitionRanks(
                      sortedByRunningDistance,
                      (entry) => entry.runningDistanceMeters,
                    );
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
                        if (isPro) ...[
                          const SizedBox(height: 18),
                          _RankingSection(
                            title: '헬스 총 볼륨',
                            rankings: strengthVolumeRanking,
                            valueBuilder: (entry) =>
                                '${_formatNumber(entry.strengthVolumeKg)}kg',
                            pointColor: pointColor,
                          ),
                          const SizedBox(height: 18),
                          _RankingSection(
                            title: '러닝 총 거리',
                            rankings: runningDistanceRanking,
                            valueBuilder: (entry) =>
                                '${_formatDistance(entry.runningDistanceMeters)}km',
                            pointColor: pointColor,
                          ),
                        ],
                      ],
                    );
                  },
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

  int _compareStrengthVolume(RankingEntry first, RankingEntry second) {
    final primary = second.strengthVolumeKg.compareTo(first.strengthVolumeKg);
    if (primary != 0) return primary;
    final name = first.name.compareTo(second.name);
    return name != 0 ? name : first.uid.compareTo(second.uid);
  }

  int _compareRunningDistance(RankingEntry first, RankingEntry second) {
    final primary = second.runningDistanceMeters.compareTo(
      first.runningDistanceMeters,
    );
    if (primary != 0) return primary;
    final name = first.name.compareTo(second.name);
    return name != 0 ? name : first.uid.compareTo(second.uid);
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours == 0) return '$minutes분';
    return '$hours시간 $minutes분';
  }

  String _formatNumber(double value) {
    final text = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    final parts = text.split('.');
    final whole = parts.first;
    final buffer = StringBuffer();
    for (var index = 0; index < whole.length; index++) {
      if (index > 0 && (whole.length - index) % 3 == 0) buffer.write(',');
      buffer.write(whole[index]);
    }
    if (parts.length > 1) buffer.write('.${parts[1]}');
    return buffer.toString();
  }

  String _formatDistance(double meters) {
    final kilometers = meters / 1000;
    final text = kilometers.toStringAsFixed(kilometers < 1 ? 2 : 1);
    final parts = text.split('.');
    final whole = _formatNumber(double.parse(parts.first));
    return '$whole.${parts[1]}';
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
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
              color: selected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurfaceVariant,
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
  final List<CompetitionRank<RankingEntry>> rankings;
  final String Function(RankingEntry) valueBuilder;
  final Color pointColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < rankings.length; index++)
            _RankingRow(
              rank: rankings[index].rank,
              data: rankings[index].entry,
              value: valueBuilder(rankings[index].entry),
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
    final sectionBackground = context.colors.surfaceContainer;
    final rowBackground = isFirst
        ? context.colors.surfaceContainerHigh
        : sectionBackground;
    final rowForeground = context.foregroundFor(rowBackground);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isFirst ? rowBackground : Colors.transparent,
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
                color: isFirst ? pointColor : rowForeground,
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: rowForeground,
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
              color: isFirst ? pointColor : rowForeground,
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
