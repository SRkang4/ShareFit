import 'dart:io';

import 'package:image/image.dart' as image;

const _sourcePath = 'assets/icons/app_icon.png';
const _outputPath = 'assets/icons/app_icon_foreground.png';

void main() {
  final source = image.decodePng(File(_sourcePath).readAsBytesSync());
  if (source == null) {
    throw StateError('Unable to decode $_sourcePath');
  }

  final foreground = image.Image(
    width: source.width,
    height: source.height,
    numChannels: 4,
  );
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final pixel = source.getPixel(x, y);
      final red = pixel.r.toInt();
      final green = pixel.g.toInt();
      final blue = pixel.b.toInt();
      final blueScore = blue - red;
      if (blueScore <= 8) {
        foreground.setPixelRgba(x, y, 0, 0, 0, 0);
        continue;
      }

      final alpha = (blueScore * 3).clamp(0, 255);
      final alphaFraction = alpha / 255;
      final foregroundRed = _unblendFromWhite(red, alphaFraction);
      final foregroundGreen = _unblendFromWhite(green, alphaFraction);
      final foregroundBlue = _unblendFromWhite(blue, alphaFraction);
      foreground.setPixelRgba(
        x,
        y,
        foregroundRed,
        foregroundGreen,
        foregroundBlue,
        alpha,
      );
    }
  }

  File(_outputPath)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(image.encodePng(foreground));
  stdout.writeln('Adaptive launcher foreground: $_outputPath');
}

int _unblendFromWhite(int channel, double alpha) {
  return ((channel - 255 * (1 - alpha)) / alpha).round().clamp(0, 255);
}
