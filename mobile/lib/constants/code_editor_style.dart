import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';

/// Shared style constants for all code editor / code preview widgets.
abstract final class CodeEditorStyle {
  // ── Colours ──────────────────────────────────────────────────────────────
  static const Color bgEditor  = Color(0xFF1E1E1E);
  static const Color bgGutter  = Color(0xFF252526);
  static const Color textCode  = Color(0xFFD4D4D4);
  static const Color textGutter = Color(0xFF858585);

  // ── Font ─────────────────────────────────────────────────────────────────
  static const double fontSize = 13;
  static const double lineHeight = 1.65;
  static const String fontFamily = 'monospace';

  // ── Gutter ───────────────────────────────────────────────────────────────
  static const double gutterWidth  = 60;
  static const double gutterMargin = 4;
  static const double gutterFontSize = 10;

  // ── Shared TextStyle for code text ───────────────────────────────────────
  static const TextStyle codeTextStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize,
    height: lineHeight,
  );

  // ── GutterStyle for CodeField ─────────────────────────────────────────────
  static const GutterStyle gutterStyle = GutterStyle(
    showErrors: false,
    showFoldingHandles: false,
    width: gutterWidth,
    margin: gutterMargin,
    textStyle: TextStyle(color: textGutter),
  );

  // ── BoxDecoration for CodeField ───────────────────────────────────────────
  static const BoxDecoration fieldDecoration = BoxDecoration(color: bgEditor);
}
