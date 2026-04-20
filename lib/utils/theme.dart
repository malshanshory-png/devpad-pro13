// lib/utils/theme.dart
// Dynamic theme bridge.
// All widgets use T.xxx exactly as before — zero call-site changes needed.
// The active theme is changed by calling T.use(theme) which is called from
// EditorController whenever settings.themeId changes.

import 'package:flutter/material.dart';
import '../models/models.dart';

class T {
  T._(); // non-instantiable

  // ── Active theme (defaults to DevPad Dark) ──────────────────────────────
  static EditorTheme _active = EditorTheme.devpadDark;

  /// Switch the active theme. Call this from EditorController.
  static void use(EditorTheme theme) => _active = theme;

  /// Switch by id. Silently falls back to devpadDark for unknown ids.
  static void useId(String id) => _active = EditorTheme.byId(id);

  static EditorTheme get current => _active;

  // ── Colour accessors (same names as before → zero widget changes) ───────
  static Color get bg           => _active.bg;
  static Color get bg2          => _active.bg2;
  static Color get surface      => _active.surface;
  static Color get surface2     => _active.surface2;
  static Color get surface3     => _active.surface3;
  static Color get surface4     => _active.surface4;
  static Color get border       => _active.border;
  static Color get border2      => _active.border2;
  static Color get border3      => _active.border3;
  static Color get accent       => _active.accent;
  static Color get accentDim    => _active.accentDim;
  static Color get accentGlow   => _active.accentGlow;
  static Color get accentHover  => _active.accentHover;
  static Color get green        => _active.green;
  static Color get red          => _active.red;
  static Color get yellow       => _active.yellow;
  static Color get orange       => _active.orange;
  static Color get purple       => _active.purple;
  static Color get cyan         => _active.cyan;
  static Color get pink         => _active.pink;
  static Color get teal         => _active.teal;
  static Color get text         => _active.text;
  static Color get textMid      => _active.textMid;
  static Color get textDim      => _active.textDim;
  static Color get textFaint    => _active.textFaint;
  static Color get lineNum      => _active.lineNum;
  static Color get curLine      => _active.curLine;
  static Color get selection    => _active.selection;

  // Syntax convenience
  static Color get sKw   => _active.sKw;
  static Color get sStr  => _active.sStr;
  static Color get sNum  => _active.sNum;
  static Color get sCmt  => _active.sCmt;
  static Color get sTag  => _active.sTag;
  static Color get sAtr  => _active.sAtr;
  static Color get sVal  => _active.sVal;
  static Color get sProp => _active.sProp;
  static Color get sFn   => _active.sFn;
  static Color get sCls  => _active.sCls;
  static Color get sOp   => _active.sOp;
  static Color get sBool => _active.sBool;
  static Color get sRx   => _active.sRx;

  /// Full syntax theme map for flutter_highlight.
  static Map<String, TextStyle> get syntaxTheme => _active.syntaxTheme;

  /// Flutter ThemeData built from the active EditorTheme.
  static ThemeData get theme => ThemeData(
    brightness: _active.dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: _active.bg,
    colorScheme: ColorScheme(
      brightness:  _active.dark ? Brightness.dark : Brightness.light,
      primary:     _active.accent,
      onPrimary:   Colors.white,
      secondary:   _active.accent,
      onSecondary: Colors.white,
      error:       _active.red,
      onError:     Colors.white,
      surface:     _active.bg2,
      onSurface:   _active.text,
      // ignore: deprecated_member_use
      background:  _active.bg,
      // ignore: deprecated_member_use
      onBackground: _active.text,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor:          _active.text,
      selectionColor:       _active.selection,
      selectionHandleColor: _active.accent,
    ),
    dividerColor: _active.border,
    popupMenuTheme: PopupMenuThemeData(
      color: _active.surface3,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: _active.border2),
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: MaterialStateProperty.all(_active.border2),
      trackColor: MaterialStateProperty.all(Colors.transparent),
      thickness:  MaterialStateProperty.all(4),
      radius: const Radius.circular(2),
    ),
  );
}
