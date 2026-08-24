import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as image;

const _sourcePath = 'assets/icons/notification_icon_white_source.png';
const _cleanSourcePath = 'assets/icons/notification_icon_white.png';
const _androidResourceRoot = 'android/app/src/main/res';

const _targetSizes = <String, int>{
  'drawable-mdpi': 24,
  'drawable-hdpi': 36,
  'drawable-xhdpi': 48,
  'drawable-xxhdpi': 72,
  'drawable-xxxhdpi': 96,
};

void main() {
  final source = image.decodePng(File(_sourcePath).readAsBytesSync());
  if (source == null) {
    throw StateError('Unable to decode $_sourcePath');
  }

  final labels = Int32List(source.width * source.height)
    ..fillRange(0, source.width * source.height, -1);
  final queue = Int32List(source.width * source.height);
  final componentSizes = <int>[];
  var nextLabel = 0;

  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final index = y * source.width + x;
      if (labels[index] != -1 || source.getPixel(x, y).a < 200) {
        continue;
      }

      var head = 0;
      var tail = 0;
      labels[index] = nextLabel;
      queue[tail++] = index;
      var size = 0;

      while (head < tail) {
        final current = queue[head++];
        size++;
        final currentX = current % source.width;
        final currentY = current ~/ source.width;

        tail = _visit(
          currentX - 1,
          currentY,
          source,
          labels,
          nextLabel,
          queue,
          tail,
        );
        tail = _visit(
          currentX + 1,
          currentY,
          source,
          labels,
          nextLabel,
          queue,
          tail,
        );
        tail = _visit(
          currentX,
          currentY - 1,
          source,
          labels,
          nextLabel,
          queue,
          tail,
        );
        tail = _visit(
          currentX,
          currentY + 1,
          source,
          labels,
          nextLabel,
          queue,
          tail,
        );
      }

      componentSizes.add(size);
      nextLabel++;
    }
  }

  final labelsBySize =
      List<int>.generate(componentSizes.length, (index) => index)..sort(
        (left, right) => componentSizes[right].compareTo(componentSizes[left]),
      );
  final keptLabels = labelsBySize.take(3).toSet();
  if (keptLabels.length != 3) {
    throw StateError('Expected the logo body and two dots in $_sourcePath');
  }

  final clean = image.Image(
    width: source.width,
    height: source.height,
    numChannels: 4,
  );
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final alpha = source.getPixel(x, y).a.toInt();
      if (alpha == 0 ||
          !_isNearKeptCore(
            x,
            y,
            source.width,
            source.height,
            labels,
            keptLabels,
          )) {
        clean.setPixelRgba(x, y, 0, 0, 0, 0);
        continue;
      }
      clean.setPixelRgba(x, y, 255, 255, 255, alpha);
    }
  }

  File(_cleanSourcePath)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(image.encodePng(clean));

  for (final target in _targetSizes.entries) {
    final resized = image.copyResize(
      clean,
      width: target.value,
      height: target.value,
      interpolation: image.Interpolation.cubic,
    );
    final output = File(
      '$_androidResourceRoot/${target.key}/ic_stat_sharefit.png',
    );
    output.parent.createSync(recursive: true);
    output.writeAsBytesSync(image.encodePng(resized));
  }

  final sizes = labelsBySize
      .take(3)
      .map((label) => componentSizes[label])
      .join(', ');
  stdout.writeln('Kept notification icon component sizes: $sizes');
  stdout.writeln('Clean source: $_cleanSourcePath');
  stdout.writeln('Android resources: $_androidResourceRoot');
}

int _visit(
  int x,
  int y,
  image.Image source,
  Int32List labels,
  int label,
  Int32List queue,
  int tail,
) {
  if (x < 0 || y < 0 || x >= source.width || y >= source.height) {
    return tail;
  }
  final index = y * source.width + x;
  if (labels[index] != -1 || source.getPixel(x, y).a < 200) {
    return tail;
  }
  labels[index] = label;
  queue[tail] = index;
  return tail + 1;
}

bool _isNearKeptCore(
  int x,
  int y,
  int width,
  int height,
  Int32List labels,
  Set<int> keptLabels,
) {
  const radius = 2;
  for (var offsetY = -radius; offsetY <= radius; offsetY++) {
    final candidateY = y + offsetY;
    if (candidateY < 0 || candidateY >= height) {
      continue;
    }
    for (var offsetX = -radius; offsetX <= radius; offsetX++) {
      final candidateX = x + offsetX;
      if (candidateX < 0 || candidateX >= width) {
        continue;
      }
      if (keptLabels.contains(labels[candidateY * width + candidateX])) {
        return true;
      }
    }
  }
  return false;
}
