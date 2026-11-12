// Curated palettes provide coordinated colors in both brightness modes.

import 'package:flutter/material.dart';

class AppPalette {
  const AppPalette(
    this.id,
    this.name,
    this.primary,
    this.secondary,
    this.darkPrimary,
    this.darkSecondary, {
    this.isPremium = true,
  });

  final bool isPremium;
  final String id;
  final String name;
  final Color primary;
  final Color secondary;
  final Color darkPrimary;
  final Color darkSecondary;

  String get backgroundStyle => id == 'graphite' ? 'plain' : id;

  static const graphite = AppPalette(
    'graphite',
    'Graphite',
    Color(0xFF343E4B),
    Color(0xFF596779),
    Color(0xFFBCC9DA),
    Color(0xFFA5B5CB),
    isPremium: false,
  );

  static const presets = [
    graphite,
    AppPalette(
      'blue',
      'Blue',
      Color(0xFF6289CC),
      Color(0xFF526C98),
      Color(0xFFAFC8F2),
      Color(0xFF91ADDB),
      isPremium: false,
    ),
    AppPalette(
      'green',
      'Green',
      Color(0xFF66A58C),
      Color(0xFF4D806C),
      Color(0xFFA6D0B6),
      Color(0xFF99BEAF),
      isPremium: false,
    ),
    AppPalette(
      'purple',
      'Purple',
      Color(0xFFB38BC5),
      Color(0xFF836799),
      Color(0xFFD2B7E7),
      Color(0xFFB6A7DC),
      isPremium: false,
    ),
    AppPalette(
      'slate',
      'Slate',
      Color(0xFF43566B),
      Color(0xFF647B8D),
      Color(0xFFAFC7DF),
      Color(0xFF96B6C4),
      isPremium: false,
    ),
    AppPalette(
      'sage',
      'Sage',
      Color(0xFF3C6956),
      Color(0xFF77704C),
      Color(0xFFA6D0B6),
      Color(0xFFD0C69A),
      isPremium: false,
    ),
    AppPalette(
      'linen',
      'Linen',
      Color(0xFF795A43),
      Color(0xFF8A6B5A),
      Color(0xFFE6BE9B),
      Color(0xFFD5B4A2),
      isPremium: false,
    ),

    AppPalette(
      'ocean',
      'Ocean',
      Color(0xFF256B83),
      Color(0xFF536BAD),
      Color(0xFF80CEDA),
      Color(0xFFA7B8EF),
    ),
    AppPalette(
      'forest',
      'Forest',
      Color(0xFF3C7059),
      Color(0xFF926936),
      Color(0xFF93CFAC),
      Color(0xFFE0BC82),
    ),
    AppPalette(
      'geometry',
      'Geometry',
      Color(0xFF68598C),
      Color(0xFF8C7196),
      Color(0xFFC7B8EB),
      Color(0xFFD5B8DF),
    ),
    AppPalette(
      'dusk',
      'Dusk',
      Color(0xFF705596),
      Color(0xFF456F92),
      Color(0xFFC5ADE9),
      Color(0xFF96C4E7),
    ),
    AppPalette(
      'rose',
      'Rose',
      Color(0xFF98576A),
      Color(0xFF81674A),
      Color(0xFFE5ACBD),
      Color(0xFFD8BE9C),
    ),
  ];
}
