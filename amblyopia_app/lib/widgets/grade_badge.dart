import 'package:flutter/material.dart';

class GradeBadge extends StatefulWidget {
  final int grade;
  final String label;

  const GradeBadge({super.key, required this.grade, required this.label});

  @override
  State<GradeBadge> createState() => _GradeBadgeState();
}

class _GradeBadgeState extends State<GradeBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  Color get _color {
    switch (widget.grade) {
      case 0: return Colors.green;
      case 1: return Colors.amber;
      case 2: return Colors.orange;
      case 3: return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulse = Tween(begin: 1.0, end: 1.08).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    if (widget.grade == 3) _ctrl.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pulse,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: _color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: _color, width: 1.5),
          boxShadow: [
            BoxShadow(color: _color.withOpacity(0.3), blurRadius: 12, spreadRadius: 2),
          ],
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            color: _color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}
