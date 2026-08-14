import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../services/auth_service.dart';
import '../theme/app_theme_color.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const dangerColor = Color(0xFFFF5A76);

  Color get pointColor => Theme.of(context).colorScheme.primary;

  final AuthService _authService = AuthService();

  bool friendStartNoti = true;
  bool shareMyWorkoutNoti = true;
  bool friendRequestNoti = true;
  bool friendAcceptNoti = true;
  bool rankingChangeNoti = false;
  bool _isProcessingAccountAction = false;

  Future<void> _confirmAccountAction({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
    required Future<void> Function() action,
  }) async {
    if (_isProcessingAccountAction) {
      return;
    }

    Object? actionError;
    var succeeded = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var isLoading = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              onPressed: isLoading
                                  ? null
                                  : () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.onSurface,
                                side: const BorderSide(
                                  color: Color(0xFFE0E0E0),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: const Text(
                                '취소',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: isLoading
                                  ? null
                                  : () async {
                                      setDialogState(() {
                                        isLoading = true;
                                      });
                                      setState(() {
                                        _isProcessingAccountAction = true;
                                      });

                                      try {
                                        await action();
                                        succeeded = true;
                                      } catch (error) {
                                        actionError = error;
                                      }

                                      if (dialogContext.mounted) {
                                        Navigator.pop(dialogContext);
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: confirmColor,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: confirmColor,
                                disabledForegroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      confirmText,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
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
      },
    );

    if (mounted) {
      setState(() {
        _isProcessingAccountAction = false;
      });
    }

    if (succeeded) {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      return;
    }

    if (actionError != null && mounted) {
      _showError(_accountErrorMessage(actionError!));
    }
  }

  Future<void> _confirmSignOut() {
    return _confirmAccountAction(
      title: '로그아웃할까요?',
      message: '현재 계정에서 로그아웃합니다.',
      confirmText: '로그아웃',
      confirmColor: pointColor,
      action: _authService.signOut,
    );
  }

  Future<void> _confirmDeleteAccount() {
    return _confirmAccountAction(
      title: '정말 탈퇴할까요?',
      message: '계정 정보가 삭제되며 되돌릴 수 없습니다.',
      confirmText: '탈퇴하기',
      confirmColor: dangerColor,
      action: _authService.deleteAccount,
    );
  }

  String _accountErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'requires-recent-login':
        case 'user-requires-recent-login':
          return '보안을 위해 다시 로그인한 후 탈퇴해주세요.';
        case 'network-request-failed':
          return '네트워크 연결을 확인해주세요.';
      }
    }

    if (error is FirebaseException && error.code == 'unavailable') {
      return '네트워크 연결을 확인해주세요.';
    }

    return '요청 처리 중 오류가 발생했습니다. 다시 시도해주세요.';
  }

  void _showError(String message) {
    showTopSnackBar(
      Overlay.of(context),
      Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: pointColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      displayDuration: const Duration(seconds: 2),
    );
  }

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
                Text(
                  '설정',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            const _ThemeCard(),

            const SizedBox(height: 18),

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
              children: const [_MenuRow(title: '앱 버전', trailingText: '1.0.0')],
            ),

            const SizedBox(height: 18),

            _SectionCard(
              title: '계정',
              children: [
                _MenuRow(
                  title: '로그아웃',
                  isDanger: true,
                  onTap: _isProcessingAccountAction ? null : _confirmSignOut,
                ),
                _MenuRow(
                  title: '탈퇴하기',
                  isDanger: true,
                  onTap: _isProcessingAccountAction
                      ? null
                      : _confirmDeleteAccount,
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

  const _SectionCard({required this.title, required this.children});

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
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final String title;
  final String? trailingText;
  final bool isDanger;
  final VoidCallback? onTap;

  const _MenuRow({
    required this.title,
    this.trailingText,
    this.isDanger = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDanger
        ? const Color(0xFFFF5A76)
        : Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: Container(
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
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: isDanger
                    ? color
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '테마',
            style: TextStyle(
              color: context.foregroundFor(colors.surfaceContainer),
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ThemePill(
                  label: '라이트',
                  selected: ThemeController.instance.mode == ThemeMode.light,
                  onTap: () =>
                      ThemeController.instance.setMode(ThemeMode.light),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ThemePill(
                  label: '다크',
                  selected: ThemeController.instance.mode == ThemeMode.dark,
                  onTap: () => ThemeController.instance.setMode(ThemeMode.dark),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ThemePill(
                  label: '시스템',
                  selected: ThemeController.instance.mode == ThemeMode.system,
                  onTap: () =>
                      ThemeController.instance.setMode(ThemeMode.system),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              for (
                var index = 0;
                index < AppAccentColor.values.length;
                index++
              ) ...[
                if (index > 0) const SizedBox(width: 8),
                Expanded(
                  child: _ThemePill(
                    label: AppAccentColor.values[index].label,
                    selected:
                        ThemeController.instance.accent ==
                        AppAccentColor.values[index],
                    selectedColor: AppAccentColor.values[index].color,
                    onTap: () => ThemeController.instance.setAccent(
                      AppAccentColor.values[index],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemePill extends StatelessWidget {
  const _ThemePill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final background = selected
        ? (selectedColor ?? colors.primary)
        : colors.surfaceContainerHigh;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 36,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? background : colors.outline),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            color: selected ? Colors.white : context.foregroundFor(background),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
