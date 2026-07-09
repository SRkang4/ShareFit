import 'package:flutter/material.dart';

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
        color: const Color(0xFFF5F7FA),

        borderRadius: BorderRadius.circular(24),
      ),

      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: isWorkingOut
                ? const Color(0xFF5B5FFF)
                : const Color(0xFFE4E7EC),

            child: Icon(
              isWorkingOut
                  ? Icons.local_fire_department
                  : Icons.check,

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

                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111111),
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  status,

                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),

          if (isWorkingOut)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),

              decoration: BoxDecoration(
                color: const Color(0xFF5B5FFF),
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