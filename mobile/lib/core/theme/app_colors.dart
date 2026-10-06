import 'package:flutter/material.dart';

/// Semantic Design Tokens from UI/UX Pro Max for Valtera Note
/// Swiss Minimalism & Dark-mode first palette
class AppColors {
  AppColors._();

  // Primary & Accent Brand Tokens
  static const Color primary = Color(0xFF0D9488); // Teal 600
  static const Color emeraldAccent = Color(0xFF10B981); // Emerald 500
  static const Color secondary = Color(0xFF14B8A6); // Teal 500
  static const Color accentOrange = Color(0xFFEA580C); // Action Orange

  // Light Mode Surfaces & Text
  static const Color lightBackground = Color(0xFFF8FAFC); // Slate 50
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0); // Slate 200
  static const Color lightTextPrimary = Color(0xFF0F172A); // Slate 900
  static const Color lightTextSecondary = Color(0xFF64748B); // Slate 500
  static const Color lightMuted = Color(0xFFF1F5F9); // Slate 100

  // Dark Mode Surfaces & Text
  static const Color darkBackground = Color(0xFF020617); // Slate 950
  static const Color darkSurface = Color(0xFF0F172A); // Slate 900
  static const Color darkSurfaceVariant = Color(0xFF1E293B); // Slate 800
  static const Color darkBorder = Color(0xFF334155); // Slate 700
  static const Color darkTextPrimary = Color(0xFFF8FAFC); // Slate 50
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color darkMuted = Color(0xFF1E293B);

  // Status & Feedback Tokens
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color destructive = Color(0xFFDC2626); // Red 600
  static const Color errorRed = Color(0xFFEF4444); // Red 500
}
