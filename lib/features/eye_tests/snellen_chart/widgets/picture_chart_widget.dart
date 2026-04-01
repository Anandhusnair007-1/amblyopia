import 'package:flutter/material.dart';

import '../models/snellen_result.dart';

/// Picture chart for Profile A (age 3-4): House, Bird, Apple, Hand.
/// Worker taps which symbol the child pointed to. One symbol shown per line (size decreases).
enum PictureSymbol {
  house,
  bird,
  apple,
  hand,
}

extension on PictureSymbol {
  String get emoji {
    switch (this) {
      case PictureSymbol.house:
        return '🏠';
      case PictureSymbol.bird:
        return '🐦';
      case PictureSymbol.apple:
        return '🍎';
      case PictureSymbol.hand:
        return '✋';
    }
  }

  String get label {
    switch (this) {
      case PictureSymbol.house:
        return 'House';
      case PictureSymbol.bird:
        return 'Bird';
      case PictureSymbol.apple:
        return 'Apple';
      case PictureSymbol.hand:
        return 'Hand';
    }
  }
}

class _PictureLine {
  const _PictureLine({required this.fraction, required this.symbols});

  final String fraction;
  final List<PictureSymbol> symbols;
}

const List<_PictureLine> _pictureLines = <_PictureLine>[
  _PictureLine(fraction: '6/24', symbols: <PictureSymbol>[PictureSymbol.house]),
  _PictureLine(fraction: '6/18', symbols: <PictureSymbol>[PictureSymbol.bird]),
  _PictureLine(fraction: '6/12', symbols: <PictureSymbol>[PictureSymbol.apple]),
  _PictureLine(fraction: '6/9', symbols: <PictureSymbol>[PictureSymbol.hand]),
  _PictureLine(fraction: '6/6', symbols: <PictureSymbol>[PictureSymbol.house, PictureSymbol.bird]),
];

class PictureChartWidget extends StatefulWidget {
  const PictureChartWidget({
    super.key,
    required this.onComplete,
  });

  final void Function(SnellenResult result) onComplete;

  @override
  State<PictureChartWidget> createState() => _PictureChartWidgetState();
}

class _PictureChartWidgetState extends State<PictureChartWidget> {
  int _currentLine = 0;
  final List<bool> _linePassed = [];
  static const _allSymbols = [
    PictureSymbol.house,
    PictureSymbol.bird,
    PictureSymbol.apple,
    PictureSymbol.hand,
  ];

  void _onTap(PictureSymbol chosen) {
    if (_currentLine >= _pictureLines.length) return;
    final target = _pictureLines[_currentLine].symbols.first;
    final passed = chosen == target;
    setState(() {
      _linePassed.add(passed);
      if (_currentLine + 1 >= _pictureLines.length) {
        _complete();
      } else {
        _currentLine++;
      }
    });
  }

  void _complete() {
    var best = '6/60';
    for (var i = 0; i < _linePassed.length; i++) {
      if (_linePassed[i] && i < _pictureLines.length) {
        best = _pictureLines[i].fraction;
      }
    }
    final score = SnellenResult.acuityToScore(best);
    final note = score >= 0.7
        ? 'Picture chart: approximate acuity $best. Normal for age 3-4.'
        : 'Picture chart: approximate acuity $best. Follow-up recommended.';
    final result = SnellenResult(
      lines: _linePassed.asMap().entries.map((e) {
        final i = e.key;
        final frac = i < _pictureLines.length ? _pictureLines[i].fraction : '6/60';
        return SnellenLineResult(
          snellenFraction: frac,
          displayedLetters: _pictureLines[i].symbols.map((s) => s.name).toList(growable: false),
          spokenLetters: [e.value ? 'correct' : 'wrong'],
          correctCount: e.value ? 1 : 0,
          totalCount: _pictureLines[i].symbols.length,
          linePassed: e.value,
        );
      }).toList(),
      visualAcuity: best,
      bothEyesAcuity: best,
      acuityScore: score,
      isNormal: score >= 0.7,
      requiresReferral: score < 0.5,
      clinicalNote: note,
      normalityScore: score,
    );
    widget.onComplete(result);
  }

  @override
  Widget build(BuildContext context) {
    if (_currentLine >= _pictureLines.length && _linePassed.length >= _pictureLines.length) {
      return const Center(child: Text('Complete', style: TextStyle(color: Colors.white)));
    }

    final target = _pictureLines[_currentLine].symbols.first;
    final size = 92.0 - (_currentLine * 12.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Which one does the child point to?',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 24),
        Text(
          target.emoji,
          style: TextStyle(fontSize: size),
        ),
        const SizedBox(height: 32),
        Text(
          'Line ${_currentLine + 1} of ${_pictureLines.length}  ·  ${_pictureLines[_currentLine].fraction}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: _allSymbols.map((s) {
            return FilledButton.icon(
              onPressed: () => _onTap(s),
              icon: Text(s.emoji, style: const TextStyle(fontSize: 24)),
              label: Text(s.label),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
