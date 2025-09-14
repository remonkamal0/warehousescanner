import 'package:flutter/material.dart';

class FontManager {
  static const String cairo = 'Cairo';
}

class TextStyles {
  static const TextStyle extraLight = TextStyle(
    fontFamily: FontManager.cairo,
    fontWeight: FontWeight.w200,
    fontSize: 16,
  );

  static const TextStyle light = TextStyle(
    fontFamily: FontManager.cairo,
    fontWeight: FontWeight.w300,
    fontSize: 16,
  );

  static const TextStyle regular = TextStyle(
    fontFamily: FontManager.cairo,
    fontWeight: FontWeight.w400,
    fontSize: 16,
  );

  static const TextStyle medium = TextStyle(
    fontFamily: FontManager.cairo,
    fontWeight: FontWeight.w500,
    fontSize: 16,
  );

  static const TextStyle semiBold = TextStyle(
    fontFamily: FontManager.cairo,
    fontWeight: FontWeight.w600,
    fontSize: 16,
  );

  static const TextStyle bold = TextStyle(
    fontFamily: FontManager.cairo,
    fontWeight: FontWeight.w700,
    fontSize: 16,
  );

  static const TextStyle extraBold = TextStyle(
    fontFamily: FontManager.cairo,
    fontWeight: FontWeight.w800,
    fontSize: 16,
  );

  static const TextStyle black = TextStyle(
    fontFamily: FontManager.cairo,
    fontWeight: FontWeight.w900,
    fontSize: 16,
  );
}


