import 'package:cloud_functions/cloud_functions.dart';

class WakeUpException implements Exception {
  const WakeUpException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WakeUpService {
  WakeUpService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  final FirebaseFunctions _functions;

  Future<void> send(String targetUid) async {
    try {
      await _functions.httpsCallable('sendWakeUp').call<void>({
        'targetUid': targetUid,
      });
    } on FirebaseFunctionsException catch (error) {
      throw WakeUpException(_messageFor(error.code));
    } catch (_) {
      throw const WakeUpException('깨우기를 보내지 못했습니다. 다시 시도해주세요.');
    }
  }

  String _messageFor(String code) => switch (code) {
    'resource-exhausted' => '조금 전에 깨우기를 보냈어요. 잠시 후 다시 시도해주세요.',
    'unauthenticated' => '로그인 후 다시 시도해주세요.',
    'permission-denied' => '현재 친구에게 깨우기를 보낼 수 없습니다.',
    'not-found' => '친구의 알림 기기를 찾을 수 없습니다.',
    _ => '깨우기를 보내지 못했습니다. 다시 시도해주세요.',
  };
}
