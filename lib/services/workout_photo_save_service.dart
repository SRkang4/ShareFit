import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';

enum WorkoutPhotoSaveFailure {
  permissionDenied,
  network,
  notEnoughSpace,
  unsupportedFormat,
  unexpected,
}

class WorkoutPhotoSaveException implements Exception {
  const WorkoutPhotoSaveException(this.failure, [this.cause]);

  final WorkoutPhotoSaveFailure failure;
  final Object? cause;

  String get userMessage => switch (failure) {
    WorkoutPhotoSaveFailure.permissionDenied => '사진을 저장하려면 사진 앱 접근 권한이 필요합니다.',
    WorkoutPhotoSaveFailure.network => '사진을 다운로드하지 못했습니다. 네트워크 연결을 확인해주세요.',
    WorkoutPhotoSaveFailure.notEnoughSpace => '기기 저장 공간이 부족합니다.',
    WorkoutPhotoSaveFailure.unsupportedFormat => '지원하지 않는 사진 형식입니다.',
    WorkoutPhotoSaveFailure.unexpected => '사진을 저장하지 못했습니다. 다시 시도해주세요.',
  };
}

class WorkoutPhotoSaveService {
  Future<void> save({
    required String workoutId,
    required String photoUrl,
  }) async {
    final normalizedUrl = photoUrl.trim();
    if (normalizedUrl.isEmpty) {
      throw const WorkoutPhotoSaveException(WorkoutPhotoSaveFailure.unexpected);
    }

    await _ensureGalleryAccess();

    final client = HttpClient();
    File? temporaryFile;
    try {
      final request = await client.getUrl(Uri.parse(normalizedUrl));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>();
        throw HttpException(
          '사진 다운로드 실패: HTTP ${response.statusCode}',
          uri: Uri.parse(normalizedUrl),
        );
      }

      final bytes = await consolidateHttpClientResponseBytes(response);
      final extension = response.headers.contentType?.mimeType == 'image/png'
          ? 'png'
          : 'jpg';
      final safeWorkoutId = workoutId.replaceAll(
        RegExp(r'[^a-zA-Z0-9_-]'),
        '_',
      );
      final fileName =
          'ShareFit_${safeWorkoutId}_${DateTime.now().microsecondsSinceEpoch}.$extension';
      temporaryFile = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}$fileName',
      );
      await temporaryFile.writeAsBytes(bytes, flush: true);
      await Gal.putImage(temporaryFile.path);
    } on WorkoutPhotoSaveException {
      rethrow;
    } on GalException catch (error) {
      throw WorkoutPhotoSaveException(_mapGalFailure(error.type), error);
    } on SocketException catch (error) {
      throw WorkoutPhotoSaveException(WorkoutPhotoSaveFailure.network, error);
    } on HttpException catch (error) {
      throw WorkoutPhotoSaveException(WorkoutPhotoSaveFailure.network, error);
    } on FormatException catch (error) {
      throw WorkoutPhotoSaveException(WorkoutPhotoSaveFailure.network, error);
    } catch (error) {
      throw WorkoutPhotoSaveException(
        WorkoutPhotoSaveFailure.unexpected,
        error,
      );
    } finally {
      client.close(force: true);
      if (temporaryFile != null && await temporaryFile.exists()) {
        try {
          await temporaryFile.delete();
        } catch (_) {
          // The gallery copy is already independent of the temporary file.
        }
      }
    }
  }

  Future<void> _ensureGalleryAccess() async {
    try {
      if (await Gal.hasAccess()) return;
      await Gal.requestAccess();
      if (!await Gal.hasAccess()) {
        throw const WorkoutPhotoSaveException(
          WorkoutPhotoSaveFailure.permissionDenied,
        );
      }
    } on WorkoutPhotoSaveException {
      rethrow;
    } on GalException catch (error) {
      throw WorkoutPhotoSaveException(_mapGalFailure(error.type), error);
    }
  }

  WorkoutPhotoSaveFailure _mapGalFailure(GalExceptionType type) {
    return switch (type) {
      GalExceptionType.accessDenied => WorkoutPhotoSaveFailure.permissionDenied,
      GalExceptionType.notEnoughSpace => WorkoutPhotoSaveFailure.notEnoughSpace,
      GalExceptionType.notSupportedFormat =>
        WorkoutPhotoSaveFailure.unsupportedFormat,
      GalExceptionType.unexpected => WorkoutPhotoSaveFailure.unexpected,
    };
  }
}
