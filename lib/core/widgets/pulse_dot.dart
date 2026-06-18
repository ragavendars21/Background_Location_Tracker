import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Animated pulsing dot — pulses when [isActive] is true, static grey otherwise.
class PulseDot extends StatefulWidget {
  final bool isActive;
  final double size;
  final Color activeColor;
  final Color inactiveColor;

  const PulseDot({
    super.key,
    required this.isActive,
    this.size = 10,
    this.activeColor = AppColors.active,
    this.inactiveColor = AppColors.textMuted,
  });

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  // Initialized eagerly in initState (not as lazy field declarations) so that
  // dispose() never triggers the initializer on an already-deactivated element.
  late final AnimationController _controller;
  late final Animation<double>   _scale;
  late final Animation<double>   _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _scale = Tween<double>(begin: 1.0, end: 2.6)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _opacity = Tween<double>(begin: 0.65, end: 0.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    if (widget.isActive) _controller.repeat();
  }

  @override
  void didUpdateWidget(PulseDot old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _controller.repeat();
    } else if (!widget.isActive && old.isActive) {
      _controller
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.inactiveColor,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) => SizedBox(
        width: widget.size * 3,
        height: widget.size * 3,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: _scale.value,
              child: Opacity(
                opacity: _opacity.value,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.activeColor,
                  ),
                ),
              ),
            ),
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.activeColor,
                boxShadow: [
                  BoxShadow(
                    color: widget.activeColor.withValues(alpha: 0.55),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
