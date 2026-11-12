// Define reusable design colors for backgrounds, category paths, favorites and pins

import 'package:flutter/material.dart';

// Reference palette shared by all presentation widgets
abstract final class AppColors {
  static const accent = Color(0xFF272C30);
  static const canvas = Color(0xFFF5F6F8);
  static const darkCanvas = Color(0xFF191C20);
  static const border = Color(0xFFD9DDE3);
  static const muted = Color(0xFF8A929D);
  // Keep category, favorite and pin meanings stable even when the accent changes
  static const category = Color(0xFF6289CC);
  static const favorite = Color(0xFFF2B400);
  static const pin = Color(0xFFE74B4B);
}
