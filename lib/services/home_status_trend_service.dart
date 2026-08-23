enum HomeFriendStatus { workingOut, completed, resting }

class HomeStatusTrend {
  const HomeStatusTrend({required this.labels, required this.values});

  final List<String> labels;
  final List<double?> values;
}

/// 과거 친구 상태 집계가 저장되기 전까지 월 라벨만 제공합니다.
///
/// 향후 서버에 일별 상태 집계가 추가되면 이 구현만 실제 조회 서비스로
/// 교체하고 홈 카드 UI는 그대로 재사용할 수 있습니다.
class HomeStatusTrendService {
  const HomeStatusTrendService();

  HomeStatusTrend recentSixMonths(HomeFriendStatus status, DateTime now) {
    final labels = List.generate(6, (index) {
      final month = DateTime(now.year, now.month - (5 - index));
      return '${month.month}월';
    });
    return HomeStatusTrend(
      labels: labels,
      values: const [null, null, null, null, null, null],
    );
  }
}
