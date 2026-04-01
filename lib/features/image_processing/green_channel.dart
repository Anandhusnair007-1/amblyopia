class GreenChannelExtractor {
  List<int> isolate(List<int> rgbaPixels) {
    // Placeholder: return every fourth channel as green
    return [for (var i = 1; i < rgbaPixels.length; i += 4) rgbaPixels[i]];
  }
}
