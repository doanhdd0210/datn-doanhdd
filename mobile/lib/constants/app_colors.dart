import 'package:flutter/material.dart';

class AppColors {
  // Primary — Deep Indigo
  static const primary = Color(0xFF304FFE);
  static const primaryDark = Color(0xFF2438CC);
  static const primaryLight = Color(0xFF6B7FFF);

  // Secondary — Purple
  static const secondary = Color(0xFF6949FF);
  static const secondaryLight = Color(0xFFC3B6FF);

  // Accent Blue
  static const accentBlue = Color(0xFF50B0FF);
  static const blue = Color(0xFF50B0FF);
  static const blueDark = Color(0xFF2A8FD4);

  // Gamification
  static const accentGold = Color(0xFFFFC107);
  static const xpGold = Color(0xFFFFC107);
  static const streakYellow = Color(0xFFFFC107);
  static const streakOrange = Color(0xFFFF9800);
  static const heartRed = Color(0xFFF44336);

  // Semantic — Quiz feedback
  static const correct = Color(0xFF4CAF50);
  static const correctDark = Color(0xFF388E3C);
  static const correctBg = Color(0xFF1B5E20);
  static const wrong = Color(0xFFF44336);
  static const wrongDark = Color(0xFFD32F2F);
  static const wrongBg = Color(0xFF7F1D1D);

  // Additional accents
  static const red = Color(0xFFF44336);
  static const orange = Color(0xFFFF9800);
  static const teal = Color(0xFF00BCD4);
  static const pink = Color(0xFFE91E63);
  static const purple = Color(0xFF6949FF);

  // Dark backgrounds
  static const background = Color(0xFF181A20);
  static const surface = Color(0xFF1F222A);
  static const surfaceLight = Color(0xFF1F222A);
  static const surfaceElevated = Color(0xFF35383F);
  static const surfaceBorder = Color(0xFF262A35);
  static const cardBg = Color(0xFF1F222A);
  static const darkNavy = Color(0xFF181A20);

  // Text — light on dark
  static const textDark = Color(0xFFFAFAFA);
  static const textGray = Color(0xFF9E9E9E);
  static const textLight = Color(0xFF757575);
  static const textMuted = Color(0xFF616161);
  static const textHint = Color(0xFFBDBDBD);

  // Borders
  static const border = Color(0xFF262A35);
  static const borderDark = Color(0xFF35383F);

  // Bottom nav
  static const navBackground = Color(0xFF1F222A);
  static const navBorder = Color(0xFF262A35);
  static const navActive = Color(0xFF304FFE);
  static const navInactive = Color(0xFF757575);

  // Skill path node states
  static const nodeCompleted = Color(0xFF304FFE);
  static const nodeCurrent = Color(0xFF304FFE);
  static const nodeLocked = Color(0xFF35383F);
  static const nodeShadowCompleted = Color(0xFF2438CC);
  static const nodeShadowLocked = Color(0xFF262A35);

  // Topic colors
  static const List<Color> topicColors = [
    Color(0xFF304FFE), // indigo
    Color(0xFF6949FF), // purple
    Color(0xFF50B0FF), // blue
    Color(0xFFFFC107), // gold
    Color(0xFF4CAF50), // green
    Color(0xFFFF9800), // orange
    Color(0xFFE91E63), // pink
    Color(0xFF00BCD4), // teal
  ];

  static const List<Color> topicShadowColors = [
    Color(0xFF2438CC),
    Color(0xFF4A2FDD),
    Color(0xFF2A8FD4),
    Color(0xFFCC9600),
    Color(0xFF388E3C),
    Color(0xFFCC6600),
    Color(0xFFAD1457),
    Color(0xFF00838F),
  ];
}
