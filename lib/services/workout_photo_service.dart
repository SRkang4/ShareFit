import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class WorkoutPhotoUploadResult {
  const WorkoutPhotoUploadResult({
    required this.downloadUrl,
    required this.createdAt,
  });

  final String downloadUrl;
  final DateTime createdAt;
}

class WorkoutPhotoService {
  WorkoutPhotoService({FirebaseAuth? auth, FirebaseStorage? storage})
    : _auth = auth ?? FirebaseAuth.instance,
      _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  Future<WorkoutPhotoUploadResult> uploadCompletionPhoto({
    required String workoutId,
    required File image,
  }) async {
    debugPrint('[WorkoutPhotoService][$workoutId] Storage 업로드 함수 진입');
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: '현재 로그인한 사용자가 없습니다.',
      );
    }

    final extension = _imageExtension(image.path);
    final contentType = extension == 'png' ? 'image/png' : 'image/jpeg';
    final version = DateTime.now().microsecondsSinceEpoch;
    final reference = _storage.ref(
      'users/${user.uid}/workouts/$workoutId/completion_$version.$extension',
    );
    debugPrint(
      '[WorkoutPhotoService][$workoutId] Storage reference.fullPath='
      '${reference.fullPath}',
    );

    StreamSubscription<TaskSnapshot>? snapshotSubscription;
    try {
      debugPrint('[WorkoutPhotoService][$workoutId] putFile 시작');
      final uploadTask = reference.putFile(
        image,
        SettableMetadata(
          contentType: contentType,
          cacheControl: 'public,max-age=3600',
        ),
      );
      snapshotSubscription = uploadTask.snapshotEvents.listen(
        (snapshot) {
          debugPrint(
            '[WorkoutPhotoService][$workoutId] 업로드 상태 변화: '
            'state=${snapshot.state.name}, '
            'bytesTransferred=${snapshot.bytesTransferred}, '
            'totalBytes=${snapshot.totalBytes}',
          );
        },
        onError: (Object error, StackTrace stackTrace) {
          if (error is FirebaseException) {
            debugPrint(
              '[WorkoutPhotoService][$workoutId] snapshotEvents '
              'FirebaseException: plugin=${error.plugin}, '
              'code=${error.code}, message=${error.message}',
            );
          }
          debugPrint(
            '[WorkoutPhotoService][$workoutId] snapshotEvents 오류: $error',
          );
          debugPrintStack(stackTrace: stackTrace);
        },
      );

      final snapshot = await uploadTask;
      debugPrint(
        '[WorkoutPhotoService][$workoutId] putFile 완료: '
        'state=${snapshot.state.name}, '
        'bytesTransferred=${snapshot.bytesTransferred}, '
        'totalBytes=${snapshot.totalBytes}',
      );
      var createdAt = snapshot.metadata?.timeCreated;
      if (createdAt == null) {
        debugPrint('[WorkoutPhotoService][$workoutId] 객체 생성 시각 조회 시작');
        final metadata = await reference.getMetadata();
        createdAt = metadata.timeCreated;
        debugPrint(
          '[WorkoutPhotoService][$workoutId] 객체 생성 시각 조회 완료: '
          '$createdAt',
        );
      }
      if (createdAt == null) {
        throw StateError('업로드된 사진의 서버 생성 시각을 확인할 수 없습니다.');
      }
      debugPrint('[WorkoutPhotoService][$workoutId] getDownloadURL 시작');
      final downloadUrl = await reference.getDownloadURL();
      debugPrint(
        '[WorkoutPhotoService][$workoutId] getDownloadURL 완료: '
        '$downloadUrl',
      );
      return WorkoutPhotoUploadResult(
        downloadUrl: downloadUrl,
        createdAt: createdAt.toUtc(),
      );
    } catch (e, stackTrace) {
      if (e is FirebaseException) {
        debugPrint(
          '[WorkoutPhotoService][$workoutId] FirebaseException: '
          'plugin=${e.plugin}, code=${e.code}, message=${e.message}',
        );
      }
      debugPrint('[WorkoutPhotoService][$workoutId] Storage 업로드 실패: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    } finally {
      debugPrint('[WorkoutPhotoService][$workoutId] snapshotEvents 구독 해제 시작');
      await snapshotSubscription?.cancel();
      debugPrint('[WorkoutPhotoService][$workoutId] snapshotEvents 구독 해제 완료');
    }
  }

  Future<void> deleteByDownloadUrl(String downloadUrl) async {
    if (downloadUrl.isEmpty) return;
    await _storage.refFromURL(downloadUrl).delete();
  }

  String _imageExtension(String path) {
    final normalized = path.toLowerCase();
    return normalized.endsWith('.png') ? 'png' : 'jpg';
  }
}
