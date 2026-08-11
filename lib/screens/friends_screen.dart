import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../models/friend.dart';
import '../models/friend_request.dart';
import '../services/auth_service.dart';
import '../services/friend_service.dart';
import '../utils/experience_formatter.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final Color pointColor = const Color(0xFF5B5FFF);
  final TextEditingController friendCodeController = TextEditingController();
  final AuthService _authService = AuthService();
  final FriendService _friendService = FriendService();

  final int maxFreeFriends = 5;
  String selectedTab = '내 친구';
  late final Future<Map<String, dynamic>?> _currentUserData;
  late final Future<void> _migration;
  final Set<String> _processingIds = {};
  Object? _lastReportedStreamError;

  @override
  void initState() {
    super.initState();
    debugPrint('[FriendsScreen] initState: migrateCurrentUser 호출');
    _migration = _friendService.migrateCurrentUser();
    _currentUserData = _authService.getCurrentUserData();
  }

  @override
  void dispose() {
    friendCodeController.dispose();
    super.dispose();
  }

  Future<void> showAddFriendDialog() async {
    friendCodeController.clear();
    FriendSearchResult? searchResult;
    bool isSearching = false;
    bool isSending = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> search() async {
            if (isSearching || isSending) return;
            setDialogState(() {
              isSearching = true;
              searchResult = null;
            });
            try {
              final result = await _friendService.searchByFriendCode(
                friendCodeController.text,
              );
              if (!dialogContext.mounted) return;
              setDialogState(() => searchResult = result);
            } catch (error, stackTrace) {
              _logDiagnosticError('Snackbar:search', error, stackTrace);
              if (mounted) _showError(_errorMessage(error));
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() => isSearching = false);
              }
            }
          }

          Future<void> sendRequest() async {
            final result = searchResult;
            if (result == null || !result.canRequest || isSending) {
              await search();
              return;
            }
            setDialogState(() => isSending = true);
            try {
              await _friendService.sendFriendRequest(result.profile);
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
            } catch (error, stackTrace) {
              _logDiagnosticError('Snackbar:send', error, stackTrace);
              if (mounted) _showError(_errorMessage(error));
              if (dialogContext.mounted) {
                setDialogState(() => isSending = false);
              }
            }
          }

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
                  const Text(
                    '친구 추가',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '친구 코드를 입력해 요청을 보내세요.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: friendCodeController,
                    enabled: !isSearching && !isSending,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: '예: A1234567',
                      filled: true,
                      fillColor: const Color(0xFFF4F5F7),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (searchResult != null) ...[
                    const SizedBox(height: 16),
                    _SearchResultCard(result: searchResult!),
                  ],
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF666666),
                              side: const BorderSide(color: Color(0xFFE0E0E0)),
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
                            onPressed:
                                isSearching ||
                                    isSending ||
                                    (searchResult != null &&
                                        !searchResult!.canRequest)
                                ? null
                                : sendRequest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: pointColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: isSearching || isSending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.3,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    searchResult == null ? '검색' : '요청',
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
      ),
    );
  }

  Future<void> _runAction(String id, Future<void> Function() action) async {
    if (_processingIds.contains(id)) return;
    setState(() => _processingIds.add(id));
    try {
      await action();
    } catch (error, stackTrace) {
      _logDiagnosticError('Snackbar:action id=$id', error, stackTrace);
      if (mounted) _showError(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _processingIds.remove(id));
    }
  }

  Future<void> _confirmRemoveFriend(Friend friend) async {
    var isDeleting = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> remove() async {
              if (isDeleting) return;
              setDialogState(() => isDeleting = true);
              try {
                await _friendService.removeFriend(friend);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
              } catch (error, stackTrace) {
                _logDiagnosticError('Snackbar:removeFriend', error, stackTrace);
                if (mounted) {
                  _showError(_errorMessage(error));
                }
                if (dialogContext.mounted) {
                  setDialogState(() => isDeleting = false);
                }
              }
            }

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
                    const Text(
                      '친구 삭제',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${friend.profile.name}님을 친구 목록에서 삭제할까요?',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF666666),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              onPressed: isDeleting
                                  ? null
                                  : () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF666666),
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
                              onPressed: isDeleting ? null : remove,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF5A76),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(
                                  0xFFFF5A76,
                                ),
                                disabledForegroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: isDeleting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.3,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      '삭제',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
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
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _migration,
      builder: (context, migrationSnapshot) {
        return FutureBuilder<Map<String, dynamic>?>(
          future: _currentUserData,
          builder: (context, userSnapshot) {
            final isPro = userSnapshot.data?['isPro'] == true;
            final ready =
                migrationSnapshot.connectionState == ConnectionState.done &&
                !migrationSnapshot.hasError;
            return StreamBuilder<List<Friend>>(
              stream: ready
                  ? _friendService.watchFriends()
                  : const Stream.empty(),
              builder: (context, friendsSnapshot) {
                return StreamBuilder<List<FriendRequest>>(
                  stream: ready
                      ? _friendService.watchReceivedRequests()
                      : const Stream.empty(),
                  builder: (context, receivedSnapshot) {
                    return StreamBuilder<List<FriendRequest>>(
                      stream: ready
                          ? _friendService.watchSentRequests()
                          : const Stream.empty(),
                      builder: (context, sentSnapshot) {
                        final streamError =
                            migrationSnapshot.error ??
                            friendsSnapshot.error ??
                            receivedSnapshot.error ??
                            sentSnapshot.error;
                        if (streamError != null &&
                            streamError != _lastReportedStreamError) {
                          _lastReportedStreamError = streamError;
                          final errorSource = migrationSnapshot.hasError
                              ? 'migration'
                              : friendsSnapshot.hasError
                              ? 'friendsStream'
                              : receivedSnapshot.hasError
                              ? 'receivedRequestsStream'
                              : 'sentRequestsStream';
                          debugPrint(
                            '[FriendsScreen][Snackbar:$errorSource] '
                            'StreamBuilder error=$streamError',
                          );
                          if (streamError is FirebaseException) {
                            debugPrint(
                              '[FriendsScreen][Snackbar:$errorSource] '
                              'FirebaseException plugin=${streamError.plugin} '
                              'code=${streamError.code} '
                              'message=${streamError.message}',
                            );
                          }
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              _showError(_errorMessage(streamError));
                            }
                          });
                        }
                        return _buildScreen(
                          friends: friendsSnapshot.data ?? const [],
                          receivedRequests: receivedSnapshot.data ?? const [],
                          sentRequests: sentSnapshot.data ?? const [],
                          isPro: isPro,
                          hasError: streamError != null,
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildScreen({
    required List<Friend> friends,
    required List<FriendRequest> receivedRequests,
    required List<FriendRequest> sentRequests,
    required bool isPro,
    required bool hasError,
  }) {
    final isLimitReached = !isPro && friends.length >= maxFreeFriends;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '친구',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111111),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: isLimitReached ? null : showAddFriendDialog,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isLimitReached
                          ? const Color(0xFFE4E7EC)
                          : pointColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_add_alt_1_rounded,
                      color: isLimitReached
                          ? const Color(0xFF999999)
                          : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            _buildTabSelector(receivedRequests.isNotEmpty),

            const SizedBox(height: 24),

            if (selectedTab == '내 친구')
              _buildMyFriendsTab(friends, isLimitReached, isPro, hasError)
            else
              _buildFriendRequestsTab(receivedRequests, sentRequests, hasError),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector(bool hasReceivedRequests) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _FriendTabButton(
            title: '내 친구',
            selected: selectedTab == '내 친구',
            pointColor: pointColor,
            onTap: () {
              setState(() {
                selectedTab = '내 친구';
              });
            },
          ),
          _FriendTabButton(
            title: '친구 요청',
            selected: selectedTab == '친구 요청',
            pointColor: pointColor,
            showBadge: hasReceivedRequests,
            onTap: () {
              setState(() {
                selectedTab = '친구 요청';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMyFriendsTab(
    List<Friend> friends,
    bool isLimitReached,
    bool isPro,
    bool hasError,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isPro
              ? '${friends.length}명 친구 사용 중'
              : '${friends.length} / $maxFreeFriends 친구 사용 중',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF666666),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 18),

        if (isLimitReached)
          Container(
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F4),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Text(
              '무료 버전은 친구 5명까지 추가할 수 있어요.',
              style: TextStyle(
                color: Color(0xFFFF5A76),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

        if (friends.isEmpty)
          _EmptyFriendsCard(
            message: hasError ? '친구 목록을 불러오지 못했어요.' : '아직 친구가 없어요.',
          ),

        ...friends.map(
          (friend) => _FriendCard(
            friend: FriendData(
              displayName: friend.profile.name,
              career: formatWorkoutExperience(
                friend.profile.experienceStartDate,
              ),
            ),
            isProcessing: _processingIds.contains('friend:${friend.uid}'),
            onDelete: () => _confirmRemoveFriend(friend),
          ),
        ),
      ],
    );
  }

  Widget _buildFriendRequestsTab(
    List<FriendRequest> receivedRequests,
    List<FriendRequest> sentRequests,
    bool hasError,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFriendCodeCard(),

        const SizedBox(height: 26),

        _buildRequestSectionTitle('받은 요청', receivedRequests.length),

        const SizedBox(height: 14),

        if (receivedRequests.isEmpty)
          _EmptyFriendsCard(
            message: hasError ? '받은 요청을 불러오지 못했어요.' : '받은 친구 요청이 없어요.',
          ),
        ...receivedRequests.map(
          (request) => _ReceivedRequestCard(
            request: FriendRequestData(
              displayName: request.profile.name,
              career: request.profile.friendCode,
            ),
            isProcessing: _processingIds.contains('request:${request.id}'),
            onAccept: () => _runAction(
              'request:${request.id}',
              () => _friendService.acceptFriendRequest(request),
            ),
            onReject: () => _runAction(
              'request:${request.id}',
              () => _friendService.rejectFriendRequest(request),
            ),
          ),
        ),

        const SizedBox(height: 26),

        _buildRequestSectionTitle('보낸 요청', sentRequests.length),

        const SizedBox(height: 14),

        if (sentRequests.isEmpty)
          _EmptyFriendsCard(
            message: hasError ? '보낸 요청을 불러오지 못했어요.' : '보낸 친구 요청이 없어요.',
          ),
        ...sentRequests.map(
          (request) => _SentRequestCard(
            request: FriendRequestData(
              displayName: request.profile.name,
              career: request.profile.friendCode,
            ),
            isProcessing: _processingIds.contains('request:${request.id}'),
            onCancel: () => _runAction(
              'request:${request.id}',
              () => _friendService.cancelFriendRequest(request),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFriendCodeCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Text(
            '내 친구 코드',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF666666),
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          FutureBuilder<Map<String, dynamic>?>(
            future: _currentUserData,
            builder: (context, snapshot) {
              final friendCode = snapshot.data?['friendCode'] as String?;
              return Text(
                friendCode ?? (snapshot.hasError ? '불러오기 실패' : '불러오는 중'),
                style: const TextStyle(
                  fontSize: 18,
                  color: Color(0xFF111111),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Icon(Icons.copy_rounded, color: pointColor, size: 22),
        ],
      ),
    );
  }

  Widget _buildRequestSectionTitle(String title, int count) {
    return Text(
      '$title ($count)',
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: Color(0xFF111111),
      ),
    );
  }

  String _errorMessage(Object error) {
    if (error is FriendServiceException) return error.message;
    return '친구 기능을 처리하지 못했습니다. 다시 시도해주세요.';
  }

  void _logDiagnosticError(String source, Object error, StackTrace stackTrace) {
    if (error is FirebaseException) {
      debugPrint(
        '[FriendsScreen][$source] FirebaseException '
        'plugin=${error.plugin} code=${error.code} message=${error.message}',
      );
    } else {
      debugPrint('[FriendsScreen][$source] 일반 예외 exception=$error');
    }
    debugPrintStack(
      label: '[FriendsScreen][$source] stackTrace',
      stackTrace: stackTrace,
    );
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
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyFriendsCard extends StatelessWidget {
  final String message;

  const _EmptyFriendsCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF777777),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({required this.result});

  final FriendSearchResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.profile.name,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            result.profile.friendCode,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (result.reason != null) ...[
            const SizedBox(height: 8),
            Text(
              result.reason!,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFFF5A76),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FriendTabButton extends StatelessWidget {
  final String title;
  final bool selected;
  final Color pointColor;
  final VoidCallback onTap;
  final bool showBadge;

  const _FriendTabButton({
    required this.title,
    required this.selected,
    required this.pointColor,
    required this.onTap,
    this.showBadge = false,
  });

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
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF666666),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (showBadge)
                  Positioned(
                    top: -7,
                    right: -17,
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
          ),
        ),
      ),
    );
  }
}

class _FriendCard extends StatelessWidget {
  final FriendData friend;
  final VoidCallback onDelete;
  final bool isProcessing;

  const _FriendCard({
    required this.friend,
    required this.onDelete,
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context) {
    return _BaseUserCard(
      name: friend.displayName,
      career: friend.career,
      trailing: TextButton(
        onPressed: isProcessing ? null : onDelete,
        child: isProcessing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text(
                '삭제',
                style: TextStyle(
                  color: Color(0xFFFF5A76),
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}

class _ReceivedRequestCard extends StatelessWidget {
  final FriendRequestData request;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final bool isProcessing;

  const _ReceivedRequestCard({
    required this.request,
    required this.onAccept,
    required this.onReject,
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context) {
    return _BaseUserCard(
      name: request.displayName,
      career: request.career,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: isProcessing ? null : onReject,
            child: const Text(
              '거절',
              style: TextStyle(
                color: Color(0xFF999999),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(
            onPressed: isProcessing ? null : onAccept,
            child: isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    '수락',
                    style: TextStyle(
                      color: Color(0xFF5B5FFF),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SentRequestCard extends StatelessWidget {
  final FriendRequestData request;
  final VoidCallback onCancel;
  final bool isProcessing;

  const _SentRequestCard({
    required this.request,
    required this.onCancel,
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context) {
    return _BaseUserCard(
      name: request.displayName,
      career: '요청 대기중',
      trailing: TextButton(
        onPressed: isProcessing ? null : onCancel,
        child: isProcessing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text(
                '취소',
                style: TextStyle(
                  color: Color(0xFFFF5A76),
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}

class _BaseUserCard extends StatelessWidget {
  final String name;
  final String career;
  final Widget trailing;

  const _BaseUserCard({
    required this.name,
    required this.career,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFF5B5FFF),
            child: Text(
              name.substring(0, 1),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  career,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class FriendData {
  final String displayName;
  final String career;

  FriendData({required this.displayName, required this.career});
}

class FriendRequestData {
  final String displayName;
  final String career;

  FriendRequestData({required this.displayName, required this.career});
}
