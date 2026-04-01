import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/ambyoai_design_system.dart';
import '../../../core/widgets/ambyoai_widgets.dart';
import '../../../core/theme/ambyo_theme.dart';
import '../../../core/widgets/mic_listening_indicator.dart';
import '../../../core/widgets/test_progress_bar.dart';
import '../../../core/widgets/test_result_reveal.dart';
import '../../../core/widgets/test_screen_header.dart';
import '../test_quality.dart';

class TestPatternScaffold extends StatefulWidget {
  const TestPatternScaffold({
    super.key,
    required this.testKey,
    required this.testName,
    required this.content,
    required this.statusText,
    required this.isListening,
    required this.isCameraActive,
    this.isBackEnabled = false,
    this.onBack,
    this.instruction,
    this.showInstruction = false,
    this.onInstructionDismiss,
    this.result,
    this.nextTestLabel,
    this.onResultAdvance,
    this.showTransition = false,
    this.transitionLabel,
    this.totalTests = TestUiMeta.totalTests,
  });

  final String testKey;
  final String testName;
  final Widget content;
  final String statusText;
  final bool isListening;
  final bool isCameraActive;
  final bool isBackEnabled;
  final VoidCallback? onBack;
  final TestInstructionData? instruction;
  final bool showInstruction;
  final VoidCallback? onInstructionDismiss;
  final TestResultData? result;
  final String? nextTestLabel;
  final VoidCallback? onResultAdvance;
  final bool showTransition;
  final String? transitionLabel;
  final int totalTests;

  @override
  State<TestPatternScaffold> createState() => _TestPatternScaffoldState();
}

class _TestPatternScaffoldState extends State<TestPatternScaffold> {
  Timer? _instructionTimer;

  @override
  void didUpdateWidget(covariant TestPatternScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showInstruction && !oldWidget.showInstruction) {
      _startInstructionTimer();
    }
    if (!widget.showInstruction && oldWidget.showInstruction) {
      _instructionTimer?.cancel();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.showInstruction) {
      _startInstructionTimer();
    }
  }

  @override
  void dispose() {
    _instructionTimer?.cancel();
    super.dispose();
  }

  void _startInstructionTimer() {
    _instructionTimer?.cancel();
    final instruction = widget.instruction;
    if (instruction == null || !instruction.autoDismiss) {
      return;
    }
    _instructionTimer = Timer(instruction.autoDismissDuration, () {
      widget.onInstructionDismiss?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final stepIndex = TestUiMeta.stepIndex(widget.testKey);
    final inProgress = !widget.isBackEnabled;
    final accent = widget.isCameraActive
        ? const Color(0xFF00B4D8)
        : const Color(0xFF1565C0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                color: widget.isCameraActive ? Colors.black : Colors.white,
                child: TestScreenHeader(
                  testName: widget.testName,
                  testIndex: stepIndex,
                  totalTests: widget.totalTests,
                  inProgress: inProgress,
                  isDark: widget.isCameraActive,
                ),
              ),
              Container(
                color: widget.isCameraActive
                    ? const Color(0xFF07121A)
                    : Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: TestProgressBar(
                  currentStep: stepIndex,
                  totalSteps: widget.totalTests,
                  color: widget.isCameraActive
                      ? const Color(0xFF00B4D8)
                      : const Color(0xFF1565C0),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        decoration: BoxDecoration(
                          color: widget.isCameraActive
                              ? const Color(0xFF07121A)
                              : const Color(0xFFF6FAFF),
                          gradient: widget.isCameraActive
                              ? const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFF07121A),
                                    Color(0xFF03070E),
                                  ],
                                )
                              : const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFFF6FAFF),
                                    Color(0xFFEFF5FD),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    if (!widget.isCameraActive) ...[
                      Positioned(
                        top: -50,
                        right: -40,
                        child: _AmbientGlow(
                          size: 180,
                          color: AmbyoColors.cyanAccent.withValues(alpha: 0.12),
                        ),
                      ),
                      Positioned(
                        left: -60,
                        bottom: 30,
                        child: _AmbientGlow(
                          size: 220,
                          color:
                              AmbyoColors.electricBlue.withValues(alpha: 0.08),
                        ),
                      ),
                    ],
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        18,
                        20,
                        media.padding.bottom + 112,
                      ),
                      child: Column(
                        children: [
                          _EnterpriseTestMeta(
                            accent: accent,
                            statusText: widget.statusText,
                            isListening: widget.isListening,
                            isCameraActive: widget.isCameraActive,
                            testName: widget.testName,
                          ),
                          const SizedBox(height: 14),
                          Expanded(child: widget.content),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _StatusBar(
            statusText: widget.statusText,
            isListening: widget.isListening,
          ),
          if (widget.instruction != null)
            _InstructionCard(
              data: widget.instruction!,
              show: widget.showInstruction,
              onDismiss: widget.onInstructionDismiss,
            ),
          if (widget.result != null)
            _ResultRevealOverlay(
              testName: widget.testName,
              data: widget.result!,
              onAdvance: widget.onResultAdvance,
            ),
          _TransitionOverlay(
            show: widget.showTransition,
            label: widget.transitionLabel,
          ),
        ],
      ),
    );
  }
}

class TestInstructionData {
  const TestInstructionData({
    required this.title,
    required this.body,
    this.whatThisChecks,
    this.autoDismiss = true,
    this.autoDismissDuration = const Duration(seconds: 5),
    this.actionLabel = 'Got it →',
  });

  final String title;
  final String body;
  final String? whatThisChecks;
  final bool autoDismiss;
  final Duration autoDismissDuration;
  final String actionLabel;
}

class TestResultData {
  const TestResultData({
    required this.title,
    required this.message,
    required this.borderColor,
    this.detail,
    this.countdownSeconds = 3,
    this.riskLevel,
    this.quality,
  });

  final String title;
  final String message;
  final Color borderColor;
  final String? detail;
  final int countdownSeconds;

  /// NORMAL, MILD, HIGH, URGENT — used for TestResultReveal badge.
  final String? riskLevel;

  /// Optional quality score for this test.
  final TestQuality? quality;
}

class TestUiMeta {
  static const int totalTests = 11;
  static const Map<String, int> _stepIndex = <String, int>{
    'worth_four_dot': 1,
    'titmus_stereo': 2,
    'lang_stereo': 3,
    'ishihara_color': 4,
    'suppression_test': 5,
    'depth_perception': 6,
    'gaze_detection': 7,
    'prism_diopter': 8,
    'hirschberg': 9,
    'red_reflex': 10,
    'snellen_chart': 11,
    'final_prediction': 11,
  };

  static const Map<String, String> _displayNames = <String, String>{
    'worth_four_dot': 'Worth 4 Dot',
    'gaze_detection': 'Gaze Detection',
    'hirschberg': 'Hirschberg Test',
    'prism_diopter': 'Prism Diopter',
    'red_reflex': 'Red Reflex',
    'suppression_test': 'Suppression Test',
    'depth_perception': 'Depth Perception',
    'titmus_stereo': 'Titmus Stereo',
    'lang_stereo': 'Lang Stereo',
    'ishihara_color': 'Ishihara Color',
    'snellen_chart': 'Snellen Chart',
    'final_prediction': 'Final Report',
  };

  static int stepIndex(String testKey) => _stepIndex[testKey] ?? 1;
  static String displayName(String testKey) =>
      _displayNames[testKey] ?? testKey;
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, Colors.transparent],
          ),
        ),
      ),
    );
  }
}

class _EnterpriseTestMeta extends StatelessWidget {
  const _EnterpriseTestMeta({
    required this.accent,
    required this.statusText,
    required this.isListening,
    required this.isCameraActive,
    required this.testName,
  });

  final Color accent;
  final String statusText;
  final bool isListening;
  final bool isCameraActive;
  final String testName;

  @override
  Widget build(BuildContext context) {
    final toneColor = isListening
        ? accent
        : isCameraActive
            ? Colors.white70
            : const Color(0xFF334155);
    return Row(
      children: [
        Expanded(
          child: _MetaChip(
            label: 'MODULE',
            value: testName.toUpperCase(),
            accent: accent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetaChip(
            label: 'VOICE',
            value: isListening ? 'LISTENING' : 'READY',
            accent: toneColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetaChip(
            label: 'STATE',
            value: statusText.isEmpty ? 'ACTIVE' : 'GUIDED',
            accent: isCameraActive ? const Color(0xFF55E6FF) : accent,
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 18,
      blurSigma: 18,
      backgroundColor: const Color(0xB90B1524),
      borderColor: accent.withValues(alpha: 0.20),
      glowColor: accent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.52),
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.statusText,
    required this.isListening,
  });

  final String statusText;
  final bool isListening;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: GlassCard(
        radius: 22,
        blurSigma: 18,
        backgroundColor: const Color(0xCC081221),
        borderColor: isListening
            ? AmbyoColors.cyanAccent.withValues(alpha: 0.45)
            : Colors.white.withValues(alpha: 0.12),
        glowColor: isListening ? AmbyoColors.cyanAccent : AmbyoColors.royalBlue,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: MicListeningIndicator(
                isListening: isListening,
                statusText: statusText.isEmpty
                    ? 'Listening for instructions...'
                    : statusText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstructionCard extends StatelessWidget {
  const _InstructionCard({
    required this.data,
    required this.show,
    this.onDismiss,
  });

  final TestInstructionData data;
  final bool show;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 80,
      child: AnimatedSlide(
        offset: show ? Offset.zero : const Offset(0, 0.25),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: show ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: GlassCard(
            radius: 28,
            blurSigma: 18,
            backgroundColor: Colors.white.withValues(alpha: 0.82),
            borderColor: const Color(0xBFE0F0FF),
            glowColor: AmbyoColors.cyanAccent,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  data.body,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    height: 1.4,
                    color: Color(0xFF334155),
                  ),
                ),
                if (data.whatThisChecks != null) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'What this test checks...',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.whatThisChecks!,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Color(0xFF334155),
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onDismiss,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0EA5E9),
                      textStyle: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text(data.actionLabel),
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

/// Maps TestResultData to TestResultReveal; positioned at bottom like a sheet.
class _ResultRevealOverlay extends StatelessWidget {
  const _ResultRevealOverlay({
    required this.testName,
    required this.data,
    this.onAdvance,
  });

  final String testName;
  final TestResultData data;
  final VoidCallback? onAdvance;

  static String _riskLevelFromColor(Color c) {
    if (c.toARGB32() == AmbyoTheme.dangerColor.toARGB32()) return 'URGENT';
    if (c.toARGB32() == AmbyoTheme.warningColor.toARGB32()) return 'MILD';
    return 'NORMAL';
  }

  @override
  Widget build(BuildContext context) {
    final riskLevel = data.riskLevel ?? _riskLevelFromColor(data.borderColor);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 300),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          final scale = (0.95 + (0.05 * value)).clamp(0.95, 1.0);
          return Transform.scale(
            scale: scale,
            alignment: Alignment.bottomCenter,
            child: Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: TestResultReveal(
          testName: testName,
          resultValue: data.message,
          resultLabel: data.title,
          riskLevel: riskLevel,
          clinicalNote: data.detail,
          autoAdvanceSeconds: data.countdownSeconds,
          onAdvance: onAdvance ?? () {},
          quality: data.quality,
        ),
      ),
    );
  }
}

class _TransitionOverlay extends StatelessWidget {
  const _TransitionOverlay({
    required this.show,
    this.label,
  });

  final bool show;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !show,
      child: AnimatedOpacity(
        opacity: show ? 1 : 0,
        duration: const Duration(milliseconds: 240),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xF0071220),
                Color(0xFF03070E),
              ],
            ),
          ),
          child: Center(
            child: GlassCard(
              radius: 30,
              blurSigma: 22,
              backgroundColor: const Color(0xCC0A1627),
              borderColor: const Color(0x554DD0E1),
              glowColor: AmbyoColors.cyanAccent,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label ?? '',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Preparing the next clinical step...',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.68),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Color testResultColor(bool ok) =>
    ok ? const Color(0xFF16A34A) : AmbyoTheme.dangerColor;
