import 'package:flutter/material.dart';

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
  int selectedIndex = 0;
  final FriendService _friendService = FriendService();

  @override
  void initState() {
    super.initState();
    AppNavigationController.instance.addListener(_handleNavigationRequest);
    selectedIndex =
        AppNavigationController.instance.takeRequestedMainTab() ?? 0;
  }

  void _handleNavigationRequest() {
    final requested = AppNavigationController.instance.takeRequestedMainTab();
    if (requested != null && mounted && requested != selectedIndex) {
      setState(() => selectedIndex = requested);
    }
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
      body: IndexedStack(index: selectedIndex, children: screens),

      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        decoration: BoxDecoration(
          color: navigationColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: navigationColor.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.transparent,

            indicatorColor: Colors.white.withValues(alpha: 0.18),

            iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
              return IconThemeData(color: Colors.white, size: 24);
            }),

            labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((
              states,
            ) {
              return TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              );
            }),
          ),

          child: StreamBuilder<bool>(
            stream: _friendService.watchHasReceivedPendingRequests(),
            initialData: false,
            builder: (context, snapshot) {
              final hasPendingRequest = snapshot.data ?? false;
              return NavigationBar(
                height: 72,
                selectedIndex: selectedIndex,

                onDestinationSelected: (index) {
                  setState(() {
                    selectedIndex = index;
                  });
                },

                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: '홈',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.fitness_center_outlined),
                    selectedIcon: Icon(Icons.fitness_center),
                    label: '운동',
                  ),
                  NavigationDestination(
                    icon: _friendNavigationIcon(
                      icon: Icons.people_outline,
                      showBadge: hasPendingRequest,
                    ),
                    selectedIcon: _friendNavigationIcon(
                      icon: Icons.people,
                      showBadge: hasPendingRequest,
                    ),
                    label: '친구',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.emoji_events_outlined),
                    selectedIcon: Icon(Icons.emoji_events),
                    label: '랭킹',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: '마이',
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
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
