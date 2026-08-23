import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../services/auth_service.dart';
import '../services/notification_preferences_service.dart';
import '../theme/app_theme_color.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/sharefit_ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const dangerColor = Color(0xFFFF5A76);

  Color get pointColor => Theme.of(context).colorScheme.primary;

  final AuthService _authService = AuthService();
  final NotificationPreferencesService _notificationPreferencesService =
      NotificationPreferencesService();

  bool wakeUpNoti = true;
  bool friendRequestNoti = true;
  bool friendAcceptNoti = true;
  bool _isLoadingNotificationSettings = true;
  bool _isSavingNotificationSettings = false;
  bool _isProcessingAccountAction = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreferences();
  }

  Future<void> _loadNotificationPreferences() async {
    try {
      final preferences = await _notificationPreferencesService.load();
      if (!mounted) return;
      setState(() {
        wakeUpNoti = preferences.wakeUp;
        friendRequestNoti = preferences.friendRequest;
        friendAcceptNoti = preferences.friendAccepted;
        _isLoadingNotificationSettings = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingNotificationSettings = false;
      });
      _showError('알림 설정을 불러오지 못했습니다. 다시 시도해주세요.');
    }
  }

  Future<void> _updateNotificationPreferences({
    bool? wakeUp,
    bool? friendRequest,
    bool? friendAccepted,
  }) async {
    final previous = NotificationPreferences(
      wakeUp: wakeUpNoti,
      friendRequest: friendRequestNoti,
      friendAccepted: friendAcceptNoti,
    );
    final updated = previous.copyWith(
      wakeUp: wakeUp,
      friendRequest: friendRequest,
      friendAccepted: friendAccepted,
    );
    setState(() {
      wakeUpNoti = updated.wakeUp;
      friendRequestNoti = updated.friendRequest;
      friendAcceptNoti = updated.friendAccepted;
      _isSavingNotificationSettings = true;
    });
    try {
      await _notificationPreferencesService.save(updated);
      if (!mounted) return;
      setState(() {
        _isSavingNotificationSettings = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        wakeUpNoti = previous.wakeUp;
        friendRequestNoti = previous.friendRequest;
        friendAcceptNoti = previous.friendAccepted;
        _isSavingNotificationSettings = false;
      });
      _showError('알림 설정을 저장하지 못했습니다. 다시 시도해주세요.');
    }
  }

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
          padding: const EdgeInsets.fromLTRB(20, 45, 20, 120),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '설정',
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 41,
                              height: 1.08,
                              letterSpacing: -1.4,
                            ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        '앱 환경과 계정을 관리합니다.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.close_rounded, size: 28),
                ),
              ],
            ),

            const SizedBox(height: 32),

            const _ThemeCard(),

            const SizedBox(height: 18),

            _SectionCard(
              title: '알림 설정',
              children: [
                _SwitchRow(
                  title: '깨우기 알림',
                  value: wakeUpNoti,
                  onChanged:
                      _isLoadingNotificationSettings ||
                          _isSavingNotificationSettings
                      ? null
                      : (value) =>
                            _updateNotificationPreferences(wakeUp: value),
                ),
                _SwitchRow(
                  title: '친구 신청 알림',
                  value: friendRequestNoti,
                  onChanged:
                      _isLoadingNotificationSettings ||
                          _isSavingNotificationSettings
                      ? null
                      : (value) => _updateNotificationPreferences(
                          friendRequest: value,
                        ),
                ),
                _SwitchRow(
                  title: '친구 수락 알림',
                  value: friendAcceptNoti,
                  onChanged:
                      _isLoadingNotificationSettings ||
                          _isSavingNotificationSettings
                      ? null
                      : (value) => _updateNotificationPreferences(
                          friendAccepted: value,
                        ),
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
    return ShareFitCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
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
  final ValueChanged<bool>? onChanged;

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
    return ShareFitCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '테마',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          _ThemeModeToggle(
            dark: ThemeController.instance.mode == ThemeMode.dark,
            onChanged: (dark) => ThemeController.instance.setMode(
              dark ? ThemeMode.dark : ThemeMode.light,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final accent in AppAccentColor.values)
                _AccentSwatch(
                  accent: accent,
                  selected: ThemeController.instance.accent == accent,
                  onTap: () => ThemeController.instance.setAccent(accent),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeModeToggle extends StatelessWidget {
  const _ThemeModeToggle({required this.dark, required this.onChanged});

  final bool dark;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: '화면 모드',
      value: dark ? '다크' : '라이트',
      child: Container(
        height: 64,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final segmentWidth = constraints.maxWidth / 2;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: dark ? segmentWidth : 0,
                  top: 0,
                  bottom: 0,
                  width: segmentWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(19),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _ThemeModeIconButton(
                        label: '라이트',
                        icon: Icons.light_mode_rounded,
                        selected: !dark,
                        onTap: () => onChanged(false),
                      ),
                    ),
                    Expanded(
                      child: _ThemeModeIconButton(
                        label: '다크',
                        icon: Icons.dark_mode_rounded,
                        selected: dark,
                        onTap: () => onChanged(true),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ThemeModeIconButton extends StatelessWidget {
  const _ThemeModeIconButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label 모드',
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(19),
          child: Center(
            child: AnimatedOpacity(
              opacity: selected ? 1 : 0.62,
              duration: const Duration(milliseconds: 180),
              child: Icon(
                icon,
                size: 29,
                color: selected ? Colors.white : colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final AppAccentColor accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${accent.label} 포인트 컬러',
      child: Tooltip(
        message: accent.label,
        child: InkResponse(
          onTap: onTap,
          radius: 28,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
