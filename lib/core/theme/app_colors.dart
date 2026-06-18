import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Backgrounds ────────────────────────────────────────────────────────────
  static const Color bgPrimary   = Color(0xFF090E1A);
  static const Color bgSecondary = Color(0xFF0D1424);
  static const Color bgCard      = Color(0xFF131929);

  // ── Brand ─────────────────────────────────────────────────────────────────
  static const Color brand       = Color(0xFF4F8EF7);
  static const Color brandLight  = Color(0xFF7AAEFF);
  static const Color accent      = Color(0xFF00D4FF);
  static const Color purple      = Color(0xFF7B61FF);

  // ── Status ────────────────────────────────────────────────────────────────
  static const Color active      = Color(0xFF00E5A0);
  static const Color activeGlow  = Color(0x3300E5A0);
  static const Color warning     = Color(0xFFFFB347);
  static const Color error       = Color(0xFFFF4757);
  static const Color errorGlow   = Color(0x33FF4757);

  // ── Glass / Overlay ────────────────────────────────────────────────────────
  static const Color glassWhite  = Color(0x0DFFFFFF);
  static const Color glassBorder = Color(0x1AFFFFFF);
  static const Color overlay     = Color(0xB3000000);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFEEF2FF);
  static const Color textSecondary = Color(0xFF8892B0);
  static const Color textMuted     = Color(0xFF4A5568);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgPrimary, bgSecondary],
  );

  static const LinearGradient startGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00E5A0), Color(0xFF00B4D8)],
  );

  static const LinearGradient stopGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF4757), Color(0xFFFF6B9D)],
  );

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4F8EF7), Color(0xFF7B61FF)],
  );

  static const LinearGradient purpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7B61FF), Color(0xFFAB83FF)],
  );
}
