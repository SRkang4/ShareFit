import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool friendStartNoti = true;
  bool shareMyWorkoutNoti = true;
  bool friendRequestNoti = true;
  bool friendAcceptNoti = true;
  bool rankingChangeNoti = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                ),
                const SizedBox(width: 6),
                const Text(
                  '설정',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111111),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            _SectionCard(
              title: '알림 설정',
              children: [
                _SwitchRow(
                  title: '친구 운동 시작 알림',
                  value: friendStartNoti,
                  onChanged: (value) {
                    setState(() {
                      friendStartNoti = value;
                    });
                  },
                ),
                _SwitchRow(
                  title: '내 운동 상태 친구에게 알림',
                  value: shareMyWorkoutNoti,
                  onChanged: (value) {
                    setState(() {
                      shareMyWorkoutNoti = value;
                    });
                  },
                ),
                _SwitchRow(
                  title: '친구 신청 알림',
                  value: friendRequestNoti,
                  onChanged: (value) {
                    setState(() {
                      friendRequestNoti = value;
                    });
                  },
                ),
                _SwitchRow(
                  title: '친구 수락 알림',
                  value: friendAcceptNoti,
                  onChanged: (value) {
                    setState(() {
                      friendAcceptNoti = value;
                    });
                  },
                ),
                _SwitchRow(
                  title: '랭킹 순위 변경 알림',
                  value: rankingChangeNoti,
                  onChanged: (value) {
                    setState(() {
                      rankingChangeNoti = value;
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 18),

            _SectionCard(
              title: '약관',
              children: const [
                _MenuRow(title: '서비스 이용약관'),
                _MenuRow(title: '개인정보 처리방침'),
              ],
            ),

            const SizedBox(height: 18),

            _SectionCard(
              title: '앱 정보',
              children: const [
                _MenuRow(
                  title: '앱 버전',
                  trailingText: '1.0.0',
                ),
              ],
            ),

            const SizedBox(height: 18),

            _SectionCard(
              title: '계정',
              children: const [
                _MenuRow(
                  title: '로그아웃',
                  isDanger: true,
                ),
                _MenuRow(
                  title: '탈퇴하기',
                  isDanger: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.children,
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
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      alignment: Alignment.center,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111111),
              ),
            ),
          ),
          Switch(
            value: value,
            activeColor: const Color(0xFF5B5FFF),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final String title;
  final String? trailingText;
  final bool isDanger;

  const _MenuRow({
    required this.title,
    this.trailingText,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? const Color(0xFFFF5A76) : const Color(0xFF111111);

    return Container(
      height: 54,
      alignment: Alignment.center,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          if (trailingText != null)
            Text(
              trailingText!,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF777777),
              ),
            )
          else
            Icon(
              Icons.chevron_right_rounded,
              color: isDanger ? color : const Color(0xFF999999),
            ),
        ],
      ),
    );
  }
}