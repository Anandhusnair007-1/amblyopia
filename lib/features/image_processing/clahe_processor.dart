class ClaheProcessor {
  List<int> apply(
    List<int> grayscalePixels, {
    int clipLimit = 24,
  }) {
    if (grayscalePixels.isEmpty) {
      return grayscalePixels;
    }

    final histogram = List<int>.filled(256, 0);
    for (final value in grayscalePixels) {
      histogram[value.clamp(0, 255)]++;
    }

    var clipped = 0;
    for (var i = 0; i < histogram.length; i++) {
      if (histogram[i] > clipLimit) {
        clipped += histogram[i] - clipLimit;
        histogram[i] = clipLimit;
      }
    }

    final redistribute = clipped ~/ histogram.length;
    final remainder = clipped % histogram.length;
    for (var i = 0; i < histogram.length; i++) {
      histogram[i] += redistribute + (i < remainder ? 1 : 0);
    }

    final cdf = List<int>.filled(256, 0);
    cdf[0] = histogram[0];
    for (var i = 1; i < histogram.length; i++) {
      cdf[i] = cdf[i - 1] + histogram[i];
    }

    final minNonZero = cdf.firstWhere((value) => value > 0, orElse: () => 0);
    final denom =
        (grayscalePixels.length - minNonZero).clamp(1, grayscalePixels.length);

    return grayscalePixels.map((value) {
      final normalized =
          ((cdf[value.clamp(0, 255)] - minNonZero) * 255 / denom).round();
      return normalized.clamp(0, 255);
    }).toList(growable: false);
  }
}
