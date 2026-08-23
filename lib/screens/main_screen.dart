import 'dart:ui';

import 'package:flutter/material.dart';

import '../controllers/workout_session_controller.dart';
import '../navigation/app_navigation_controller.dart';
import '../services/friend_service.dart';
import 'friends_screen.dart';
import 'home_screen.dart';
import 'my_page_screen.dart';
import 'ranking_screen.dart';
import 'workout_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const double _scrollThreshold = 24;

  int selectedIndex = 0;
  final FriendService _friendService = FriendService();
  late final Stream<bool> _hasReceivedPendingRequestsStream;
  bool _isNavigationCompact = false;
  double _scrollDelta = 0;

  @override
  void initState() {
    super.initState();
    _hasReceivedPendingRequestsStream = _friendService
        .watchHasReceivedPendingRequests();
    AppNavigationController.instance.addListener(_handleNavigationRequest);
    selectedIndex =
        AppNavigationController.instance.takeRequestedMainTab() ?? 0;
  }

  void _handleNavigationRequest() {
    final requested = AppNavigationController.instance.takeRequestedMainTab();
    if (requested != null && mounted && requested != selectedIndex) {
      WorkoutSessionController.instance.setWorkoutViewVisible(requested == 1);
      setState(() {
        selectedIndex = requested;
        _isNavigationCompact = false;
        _scrollDelta = 0;
      });
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical || notification.depth != 0) {
      return false;
    }

    final metrics = notification.metrics;
    if (metrics.pixels <= metrics.minScrollExtent + 2) {
      _setNavigationCompact(false);
      _scrollDelta = 0;
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      if (delta.abs() < 0.5) return false;

      if ((_scrollDelta > 0 && delta < 0) || (_scrollDelta < 0 && delta > 0)) {
        _scrollDelta = 0;
      }
      _scrollDelta += delta;

      if (_scrollDelta >= _scrollThreshold) {
        _setNavigationCompact(true);
        _scrollDelta = 0;
      } else if (_scrollDelta <= -_scrollThreshold) {
        _setNavigationCompact(false);
        _scrollDelta = 0;
      }
    } else if (notification is ScrollEndNotification) {
      _scrollDelta = 0;
    }

    return false;
  }

  void _setNavigationCompact(bool compact) {
    if (_isNavigationCompact == compact || !mounted) return;
    setState(() => _isNavigationCompact = compact);
  }

  @override
  void dispose() {
    AppNavigationController.instance.removeListener(_handleNavigationRequest);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final navigationColor = colors.primary;
    final screens = <Widget>[
      const HomeScreen(),
      WorkoutScreen(isActive: selectedIndex == 1),
      const FriendsScreen(),
      const RankingScreen(),
      const MyPageScreen(),
    ];
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              child: IndexedStack(index: selectedIndex, children: screens),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: _isNavigationCompact ? 1 : 0),
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  builder: (context, compactProgress, child) {
                    final height = lerpDouble(60, 50, compactProgress)!;
                    final iconSize = lerpDouble(28, 24, compactProgress)!;
                    final radius = lerpDouble(24, 21, compactProgress)!;
                    final indicatorWidth = lerpDouble(44, 40, compactProgress)!;
                    final indicatorHeight = lerpDouble(
                      36,
                      32,
                      compactProgress,
                    )!;
                    final availableWidth =
                        MediaQuery.sizeOf(context).width - 32;
                    final expandedWidth =
                        (MediaQuery.sizeOf(context).width * 0.80)
                            .clamp(252, 360)
                            .toDouble();
                    final compactWidth =
                        (MediaQuery.sizeOf(context).width * 0.70)
                            .clamp(240, 320)
                            .toDouble();
                    final preferredWidth = lerpDouble(
                      expandedWidth,
                      compactWidth,
                      compactProgress,
                    )!;
                    final barWidth = preferredWidth > availableWidth
                        ? availableWidth
                        : preferredWidth;

                    return Align(
                      alignment: Alignment.bottomCenter,
                      heightFactor: 1,
                      child: SizedBox(
                        width: barWidth,
                        height: height,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(radius),
                            boxShadow: [
                              BoxShadow(
                                color: navigationColor.withValues(alpha: 0.16),
                                blurRadius: 16,
                                offset: const Offset(0, 7),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(radius),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: navigationColor.withValues(
                                    alpha: 0.86,
                                  ),
                                  borderRadius: BorderRadius.circular(radius),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.22),
                                    width: 0.8,
                                  ),
                                ),
                                child: StreamBuilder<bool>(
                                  stream: _hasReceivedPendingRequestsStream,
                                  initialData: false,
                                  builder: (context, snapshot) {
                                    final hasPendingRequest =
                                        snapshot.data ?? false;
                                    return Material(
                                      color: Colors.transparent,
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final itemWidth =
                                              constraints.maxWidth / 5;
                                          return Stack(
                                            children: [
                                              TweenAnimationBuilder<double>(
                                                tween: Tween(
                                                  end: selectedIndex.toDouble(),
                                                ),
                                                duration: const Duration(
                                                  milliseconds: 220,
                                                ),
                                                curve: Curves.easeOutCubic,
                                                builder: (context, animatedIndex, child) {
                                                  return Positioned(
                                                    left:
                                                        itemWidth *
                                                            animatedIndex +
                                                        (itemWidth -
                                                                indicatorWidth) /
                                                            2,
                                                    top:
                                                        (height -
                                                            indicatorHeight) /
                                                        2,
                                                    width: indicatorWidth,
                                                    height: indicatorHeight,
                                                    child: IgnorePointer(
                                                      child: DecoratedBox(
                                                        decoration: BoxDecoration(
                                                          color: Colors.white
                                                              .withValues(
                                                                alpha: 0.22,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                16,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                              Row(
                                                children: [
                                                  _CompactNavigationItem(
                                                    label: '홈',
                                                    selected:
                                                        selectedIndex == 0,
                                                    icon: const Icon(
                                                      Icons.home_outlined,
                                                    ),
                                                    selectedIcon: const Icon(
                                                      Icons.home,
                                                    ),
                                                    iconSize: iconSize,
                                                    onTap: () => _selectTab(0),
                                                  ),
                                                  _CompactNavigationItem(
                                                    label: '운동',
                                                    selected:
                                                        selectedIndex == 1,
                                                    icon: const Icon(
                                                      Icons
                                                          .fitness_center_outlined,
                                                    ),
                                                    selectedIcon: const Icon(
                                                      Icons.fitness_center,
                                                    ),
                                                    iconSize: iconSize,
                                                    onTap: () => _selectTab(1),
                                                  ),
                                                  _CompactNavigationItem(
                                                    label: '친구',
                                                    selected:
                                                        selectedIndex == 2,
                                                    icon: _friendNavigationIcon(
                                                      icon:
                                                          Icons.people_outline,
                                                      showBadge:
                                                          hasPendingRequest,
                                                    ),
                                                    selectedIcon:
                                                        _friendNavigationIcon(
                                                          icon: Icons.people,
                                                          showBadge:
                                                              hasPendingRequest,
                                                        ),
                                                    iconSize: iconSize,
                                                    onTap: () => _selectTab(2),
                                                  ),
                                                  _CompactNavigationItem(
                                                    label: '랭킹',
                                                    selected:
                                                        selectedIndex == 3,
                                                    icon: const Icon(
                                                      Icons
                                                          .emoji_events_outlined,
                                                    ),
                                                    selectedIcon: const Icon(
                                                      Icons.emoji_events,
                                                    ),
                                                    iconSize: iconSize,
                                                    onTap: () => _selectTab(3),
                                                  ),
                                                  _CompactNavigationItem(
                                                    label: '마이',
                                                    selected:
                                                        selectedIndex == 4,
                                                    icon: const Icon(
                                                      Icons.person_outline,
                                                    ),
                                                    selectedIcon: const Icon(
                                                      Icons.person,
                                                    ),
                                                    iconSize: iconSize,
                                                    onTap: () => _selectTab(4),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _selectTab(int index) {
    WorkoutSessionController.instance.setWorkoutViewVisible(index == 1);
    setState(() {
      selectedIndex = index;
      _isNavigationCompact = false;
      _scrollDelta = 0;
    });
  }

  Widget _friendNavigationIcon({
    required IconData icon,
    required bool showBadge,
  }) {
    return SizedBox(
      width: 32,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(icon),
          if (showBadge)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 14,
                height: 14,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF3B4F),
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  '!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CompactNavigationItem extends StatelessWidget {
  const _CompactNavigationItem({
    required this.label,
    required this.selected,
    required this.icon,
    required this.selectedIcon,
    required this.iconSize,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Widget icon;
  final Widget selectedIcon;
  final double iconSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeOut,
              child: IconTheme(
                key: ValueKey(selected),
                data: IconThemeData(color: Colors.white, size: iconSize),
                child: selected ? selectedIcon : icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
