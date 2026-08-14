import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class FriendStatusCard extends StatelessWidget {
  final String name;
  final String status;
  final bool isWorkingOut;

  const FriendStatusCard({
    super.key,
    required this.name,
    required this.status,
    required this.isWorkingOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,

        borderRadius: BorderRadius.circular(24),
      ),

      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: isWorkingOut
                ? Theme.of(context).colorScheme.primary
                : const Color(0xFFE4E7EC),

            child: Icon(
              isWorkingOut ? Icons.local_fire_department : Icons.check,

              color: Colors.white,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,

                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: context.foregroundFor(
                      Theme.of(context).colorScheme.surfaceContainer,
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  status,

                  style: TextStyle(
                    fontSize: 14,
                    color: context.secondaryForegroundFor(
                      Theme.of(context).colorScheme.surfaceContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (isWorkingOut)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),

              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(100),
              ),

              child: const Text(
                '운동 중',

                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
