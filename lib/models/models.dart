// lib/models/models.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════
//  LANGUAGE
// ═══════════════════════════════════════════
enum Language { html, css, js, ts, dart, json, md, text }

extension LanguageX on Language {
  String get displayName {
    switch (this) {
      case Language.html: return 'HTML';
      case Language.css:  return 'CSS';
      case Language.js:   return 'JavaScript';
      case Language.ts:   return 'TypeScript';
      case Language.dart: return 'Dart';
      case Language.json: return 'JSON';
      case Language.md:   return 'Markdown';
      case Language.text: return 'Plain Text';
    }
  }
  String get extension {
    switch (this) {
      case Language.html: return 'html';
      case Language.css:  return 'css';
      case Language.js:   return 'js';
      case Language.ts:   return 'ts';
      case Language.dart: return 'dart';
      case Language.json: return 'json';
      case Language.md:   return 'md';
      case Language.text: return 'txt';
    }
  }
  Color get color {
    switch (this) {
      case Language.html: return const Color(0xFFF97316);
      case Language.css:  return const Color(0xFF3B82F6);
      case Language.js:   return const Color(0xFFEAB308);
      case Language.ts:   return const Color(0xFF60A5FA);
      case Language.dart: return const Color(0xFF54C5F8);
      case Language.json: return const Color(0xFF34D399);
      case Language.md:   return const Color(0xFFA78BFA);
      case Language.text: return const Color(0xFF94A3B8);
    }
  }
  String get hlLang {
    switch (this) {
      case Language.html: return 'xml';
      case Language.css:  return 'css';
      case Language.js:   return 'javascript';
      case Language.ts:   return 'typescript';
      case Language.dart: return 'dart';
      case Language.json: return 'json';
      case Language.md:   return 'markdown';
      case Language.text: return 'plaintext';
    }
  }
  String get commentStart {
    switch (this) {
      case Language.html: return '<!-- ';
      case Language.css:  return '/* ';
      case Language.js:
      case Language.ts:
      case Language.dart:
      case Language.json: return '// ';
      default:            return '# ';
    }
  }
  String get commentEnd {
    switch (this) {
      case Language.html: return ' -->';
      case Language.css:  return ' */';
      default:            return '';
    }
  }

}

/// Returns the [Language] that matches a file extension string (e.g. 'html', 'js').
/// Defined as a top-level function because Dart extensions cannot expose
/// callable static members via the extension name.
Language languageFromExtension(String ext) {
  switch (ext.toLowerCase()) {
    case 'html': case 'htm':     return Language.html;
    case 'css':                  return Language.css;
    case 'js':  case 'jsx':      return Language.js;
    case 'ts':  case 'tsx':      return Language.ts;
    case 'dart':                 return Language.dart;
    case 'json':                 return Language.json;
    case 'md': case 'markdown':  return Language.md;
    default:                     return Language.text;
  }
}

// ═══════════════════════════════════════════
//  SNIPPET
// ═══════════════════════════════════════════
class Snippet {
  final String trigger;
  final String label;
  final String body;       // Use \$0 for cursor position, \$1, \$2 for tab stops
  final String description;
  final String type;       // keyword | tag | prop | fn | snippet | method

  const Snippet({
    required this.trigger,
    required this.label,
    required this.body,
    this.description = '',
    this.type = 'snippet',
  });
}

// ═══════════════════════════════════════════
//  OPERATION-BASED UNDO/REDO
// ═══════════════════════════════════════════

/// A single reversible edit on a text document.
///
/// Two concrete subtypes:
///   [InsertOp]  — text was inserted at [offset]
///   [DeleteOp]  — text was deleted starting at [offset]
///
/// Each op records:
///   • the cursor position *before* the edit  → used when undoing
///   • the cursor position *after*  the edit  → used when redoing
sealed class EditorOp {
  final int offset;
  final String text;        // inserted/deleted chars
  final int cursorBefore;   // cursor position before this op
  final int cursorAfter;    // cursor position after  this op
  final DateTime timestamp;

  const EditorOp({
    required this.offset,
    required this.text,
    required this.cursorBefore,
    required this.cursorAfter,
    required this.timestamp,
  });

  /// Apply the *inverse* of this op to [content] and return the result.
  String applyUndo(String content);

  /// Apply this op to [content] and return the result.
  String applyRedo(String content);

  /// Whether this op can be merged with [next] for a single undo step.
  /// Rules:
  ///   • Same type
  ///   • Less than 300 ms apart
  ///   • Contiguous (the cursor is still at the end of the previous op)
  ///   • Neither op spans a newline (word-boundary merge stops at newlines)
  bool canMergeWith(EditorOp next);
}

final class InsertOp extends EditorOp {
  const InsertOp({
    required super.offset,
    required super.text,
    required super.cursorBefore,
    required super.cursorAfter,
    required super.timestamp,
  });

  @override
  String applyUndo(String content) {
    // Remove the inserted text: content[offset..offset+text.length]
    final end = (offset + text.length).clamp(0, content.length);
    return content.substring(0, offset) + content.substring(end);
  }

  @override
  String applyRedo(String content) {
    // Re-insert the text at offset
    final o = offset.clamp(0, content.length);
    return content.substring(0, o) + text + content.substring(o);
  }

  @override
  bool canMergeWith(EditorOp next) {
    if (next is! InsertOp) return false;
    if (next.timestamp.difference(timestamp).inMilliseconds > 300) return false;
    // Must be contiguous (next char goes right after this one)
    if (next.offset != offset + text.length) return false;
    // Don't merge across newlines (each line is its own undo step)
    if (text.contains('\n') || next.text.contains('\n')) return false;
    // Don't merge across word boundaries (space/punct breaks the chain)
    if (text.isNotEmpty && _isWordBoundary(text[text.length - 1])) return false;
    return true;
  }

  bool _isWordBoundary(String ch) =>
      ch == ' ' || ch == '\t' || '.,;:!?()[]{}\'\"'.contains(ch);

  /// Merge [next] into this op (both are InsertOps, contiguous).
  InsertOp mergedWith(InsertOp next) => InsertOp(
    offset:       offset,
    text:         text + next.text,
    cursorBefore: cursorBefore,   // keep original "before" cursor
    cursorAfter:  next.cursorAfter,
    timestamp:    timestamp,      // keep original timestamp for future merges
  );
}

final class DeleteOp extends EditorOp {
  const DeleteOp({
    required super.offset,
    required super.text,
    required super.cursorBefore,
    required super.cursorAfter,
    required super.timestamp,
  });

  @override
  String applyUndo(String content) {
    // Re-insert the deleted text at offset
    final o = offset.clamp(0, content.length);
    return content.substring(0, o) + text + content.substring(o);
  }

  @override
  String applyRedo(String content) {
    // Re-delete text at offset
    final end = (offset + text.length).clamp(0, content.length);
    return content.substring(0, offset) + content.substring(end);
  }

  @override
  bool canMergeWith(EditorOp next) {
    if (next is! DeleteOp) return false;
    if (next.timestamp.difference(timestamp).inMilliseconds > 300) return false;
    // Backspace: each deletion is one char before the previous
    if (next.offset != offset - next.text.length) return false;
    if (text.contains('\n') || next.text.contains('\n')) return false;
    return true;
  }

  DeleteOp mergedWith(DeleteOp next) => DeleteOp(
    offset:       next.offset,             // backspace moves offset backwards
    text:         next.text + text,        // prepend (newest deletion is leftmost)
    cursorBefore: cursorBefore,
    cursorAfter:  next.cursorAfter,
    timestamp:    timestamp,
  );
}

/// A compound op groups several ops into one undo step.
/// Used for programmatic edits (format, find-replace, etc.) that should
/// be reversed in a single Ctrl+Z.
final class CompoundOp extends EditorOp {
  final List<EditorOp> ops; // ordered: first applied → last

  CompoundOp({
    required this.ops,
    required super.cursorBefore,
    required super.cursorAfter,
  })  : assert(ops.isNotEmpty),
        super(
          offset:    ops.first.offset,
          text:      ops.map((o) => o.text).join(),
          timestamp: ops.first.timestamp,
        );

  @override
  String applyUndo(String content) {
    // Reverse order
    var s = content;
    for (final op in ops.reversed) s = op.applyUndo(s);
    return s;
  }

  @override
  String applyRedo(String content) {
    var s = content;
    for (final op in ops) s = op.applyRedo(s);
    return s;
  }

  @override
  bool canMergeWith(EditorOp next) => false; // compounds never merge
}

// ═══════════════════════════════════════════
//  UNDO HISTORY
// ═══════════════════════════════════════════

/// Manages the undo/redo stacks for one file using operation-based history.
///
/// Memory usage:
///   Snapshot approach: O(stackSize × avgFileSize)   e.g. 500 × 10 KB = 5 MB
///   Operation approach: O(stackSize × avgOpSize)    e.g. 1000 × 10 B  = 10 KB
class UndoHistory {
  static const int _maxOps = 2000;

  final List<EditorOp> _undoStack = [];
  final List<EditorOp> _redoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  /// Record a new op. Attempts to merge with the top of the undo stack.
  /// Clears the redo stack (new edit invalidates redo future).
  void record(EditorOp op) {
    _redoStack.clear();
    if (_undoStack.isNotEmpty) {
      final top = _undoStack.last;
      if (top is InsertOp && op is InsertOp && top.canMergeWith(op)) {
        _undoStack[_undoStack.length - 1] = top.mergedWith(op);
        return;
      }
      if (top is DeleteOp && op is DeleteOp && top.canMergeWith(op)) {
        _undoStack[_undoStack.length - 1] = top.mergedWith(op);
        return;
      }
    }
    if (_undoStack.length >= _maxOps) _undoStack.removeAt(0);
    _undoStack.add(op);
  }

  /// Record a compound op (used for programmatic multi-char edits).
  void recordCompound(CompoundOp op) {
    _redoStack.clear();
    if (_undoStack.length >= _maxOps) _undoStack.removeAt(0);
    _undoStack.add(op);
  }

  /// Undo the top op.
  /// Returns the result of applying the undo to [currentContent],
  /// plus the cursor position to restore.
  ({String content, int cursor})? undo(String currentContent) {
    if (_undoStack.isEmpty) return null;
    final op = _undoStack.removeLast();
    _redoStack.add(op);
    return (content: op.applyUndo(currentContent), cursor: op.cursorBefore);
  }

  /// Redo the top op.
  ({String content, int cursor})? redo(String currentContent) {
    if (_redoStack.isEmpty) return null;
    final op = _redoStack.removeLast();
    _undoStack.add(op);
    return (content: op.applyRedo(currentContent), cursor: op.cursorAfter);
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}

// ═══════════════════════════════════════════
//  CODE FILE
// ═══════════════════════════════════════════
class CodeFile {
  String id;
  String name;
  Language lang;
  String content;
  bool dirty;
  String lastSaved;
  DateTime modified;
  int cursorOffset = 0;
  double scrollPos = 0;

  /// Operation-based undo/redo history for this file.
  final UndoHistory history = UndoHistory();

  /// Code folding state for this file.
  final FoldingManager folding = FoldingManager();

  CodeFile({
    required this.id,
    required this.name,
    required this.lang,
    required this.content,
    this.dirty = false,
  })  : lastSaved = content,
        modified  = DateTime.now();

  bool get canUndo => history.canUndo;
  bool get canRedo => history.canRedo;

  // ── Compatibility shim ────────────────────────────────────────────────────
  // Some call-sites still call pushUndo(oldText, cursor) for programmatic edits
  // (format, find-replace, etc.). We convert these to CompoundOps so they're
  // correctly handled by the operation-based history.
  void pushUndo(String prevContent, int cursorBefore) {
    recordDiff(prevContent, content, cursorBefore, cursorOffset);
  }

  /// Compute the diff between [from] and [to] and record it as a CompoundOp
  /// (or a simple InsertOp/DeleteOp for single-region changes).
  void recordDiff(String from, String to, int cursorBefore, int cursorAfter) {
    if (from == to) return;

    // Find common prefix and suffix
    int pfx = 0;
    while (pfx < from.length && pfx < to.length && from[pfx] == to[pfx]) pfx++;
    int sfx = 0;
    while (sfx < from.length - pfx && sfx < to.length - pfx &&
           from[from.length - 1 - sfx] == to[to.length - 1 - sfx]) sfx++;

    final deletedText  = from.substring(pfx, from.length - sfx);
    final insertedText = to.substring(pfx, to.length - sfx);
    final now = DateTime.now();

    if (deletedText.isEmpty && insertedText.isNotEmpty) {
      history.record(InsertOp(
        offset: pfx, text: insertedText,
        cursorBefore: cursorBefore, cursorAfter: cursorAfter,
        timestamp: now,
      ));
    } else if (insertedText.isEmpty && deletedText.isNotEmpty) {
      history.record(DeleteOp(
        offset: pfx, text: deletedText,
        cursorBefore: cursorBefore, cursorAfter: cursorAfter,
        timestamp: now,
      ));
    } else {
      // Replace = delete then insert
      history.recordCompound(CompoundOp(
        ops: [
          DeleteOp(offset: pfx, text: deletedText,
              cursorBefore: cursorBefore, cursorAfter: pfx, timestamp: now),
          InsertOp(offset: pfx, text: insertedText,
              cursorBefore: pfx, cursorAfter: cursorAfter, timestamp: now),
        ],
        cursorBefore: cursorBefore,
        cursorAfter:  cursorAfter,
      ));
    }
  }

  void markSaved() {
    lastSaved = content;
    dirty = false;
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'lang': lang.index,
    'content': content, 'lastSaved': lastSaved,
  };

  factory CodeFile.fromJson(Map<String, dynamic> j) => CodeFile(
    id:      j['id']    as String,
    name:    j['name']  as String,
    lang:    Language.values[j['lang'] as int],
    content: j['content'] as String,
  )..lastSaved = j['lastSaved'] as String;
}

// ═══════════════════════════════════════════
//  PROJECT
// ═══════════════════════════════════════════
class Project {
  String id;
  String name;
  List<CodeFile> files;
  String activeFileId;
  DateTime created;
  DateTime modified;

  Project({
    required this.id,
    required this.name,
    required this.files,
    required this.activeFileId,
  })  : created  = DateTime.now(),
        modified = DateTime.now();

  CodeFile get activeFile => files.isEmpty
      ? throw StateError("No files")
      : files.firstWhere((f) => f.id == activeFileId, orElse: () => files.first);
}

// ═══════════════════════════════════════════
//  SETTINGS
// ═══════════════════════════════════════════
class EditorSettings {
  bool autorun;
  bool curlineHighlight;
  bool autocomplete;
  bool autopairs;
  bool wordwrap;
  bool showWhitespace;
  bool smoothScroll;
  double fontSize;
  int tabSize;
  bool useTabs;
  String fontFamily;
  double lineHeight;
  int autorunDelay;
  String themeId; // ID of the active EditorTheme

  EditorSettings({
    this.autorun          = false,
    this.curlineHighlight = true,
    this.autocomplete     = true,
    this.autopairs        = true,
    this.wordwrap         = false,
    this.showWhitespace   = false,
    this.smoothScroll     = true,
    this.fontSize         = 13.5,
    this.tabSize          = 2,
    this.useTabs          = false,
    this.fontFamily       = 'monospace',
    this.lineHeight       = 1.6,
    this.autorunDelay     = 1200,
    this.themeId          = 'devpad',
  });

  Map<String, dynamic> toJson() => {
    'autorun': autorun, 'curlineHighlight': curlineHighlight,
    'autocomplete': autocomplete, 'autopairs': autopairs,
    'wordwrap': wordwrap, 'showWhitespace': showWhitespace,
    'smoothScroll': smoothScroll, 'fontSize': fontSize,
    'tabSize': tabSize, 'useTabs': useTabs,
    'fontFamily': fontFamily, 'lineHeight': lineHeight,
    'autorunDelay': autorunDelay, 'themeId': themeId,
  };

  factory EditorSettings.fromJson(Map<String, dynamic> j) => EditorSettings(
    autorun:          j['autorun']          as bool?   ?? false,
    curlineHighlight: j['curlineHighlight']  as bool?   ?? true,
    autocomplete:     j['autocomplete']     as bool?   ?? true,
    autopairs:        j['autopairs']        as bool?   ?? true,
    wordwrap:         j['wordwrap']         as bool?   ?? false,
    showWhitespace:   j['showWhitespace']   as bool?   ?? false,
    smoothScroll:     j['smoothScroll']     as bool?   ?? true,
    fontSize:         (j['fontSize']        as num?    ?? 13.5).toDouble(),
    tabSize:          j['tabSize']          as int?    ?? 2,
    useTabs:          j['useTabs']          as bool?   ?? false,
    fontFamily:       j['fontFamily']       as String? ?? 'monospace',
    lineHeight:       (j['lineHeight']      as num?    ?? 1.6).toDouble(),
    autorunDelay:     j['autorunDelay']     as int?    ?? 1200,
    themeId:          j['themeId']          as String? ?? 'devpad',
  );

  EditorSettings copy() => EditorSettings.fromJson(toJson());
}

// ═══════════════════════════════════════════
//  EDITOR THEMES
// ═══════════════════════════════════════════

class EditorTheme {
  final String id;
  final String name;
  final bool   dark;

  // Backgrounds
  final Color bg, bg2, surface, surface2, surface3, surface4;
  // Borders
  final Color border, border2, border3;
  // Accent
  final Color accent, accentDim, accentGlow, accentHover;
  // Semantic
  final Color green, red, yellow, orange, purple, cyan, pink, teal;
  // Text
  final Color text, textMid, textDim, textFaint, lineNum, curLine, selection;
  // Syntax
  final Color sKw, sStr, sNum, sCmt, sTag, sAtr, sVal, sProp, sFn, sCls, sOp, sBool, sRx;

  const EditorTheme({
    required this.id,       required this.name,     required this.dark,
    required this.bg,       required this.bg2,      required this.surface,
    required this.surface2, required this.surface3, required this.surface4,
    required this.border,   required this.border2,  required this.border3,
    required this.accent,   required this.accentDim,required this.accentGlow,
    required this.accentHover,
    required this.green,    required this.red,      required this.yellow,
    required this.orange,   required this.purple,   required this.cyan,
    required this.pink,     required this.teal,
    required this.text,     required this.textMid,  required this.textDim,
    required this.textFaint,required this.lineNum,  required this.curLine,
    required this.selection,
    required this.sKw,  required this.sStr, required this.sNum,
    required this.sCmt, required this.sTag, required this.sAtr,
    required this.sVal, required this.sProp,required this.sFn,
    required this.sCls, required this.sOp,  required this.sBool,
    required this.sRx,
  });

  Map<String, TextStyle> get syntaxTheme => {
    'root':            TextStyle(color: text, backgroundColor: const Color(0x00000000)),
    'keyword':         TextStyle(color: sKw),
    'built_in':        TextStyle(color: sFn),
    'type':            TextStyle(color: sCls),
    'literal':         TextStyle(color: sBool),
    'number':          TextStyle(color: sNum),
    'regexp':          TextStyle(color: sRx),
    'string':          TextStyle(color: sStr),
    'subst':           TextStyle(color: sStr),
    'symbol':          TextStyle(color: sStr),
    'class':           TextStyle(color: sCls),
    'function':        TextStyle(color: sFn),
    'title':           TextStyle(color: sFn),
    'params':          TextStyle(color: text),
    'comment':         TextStyle(color: sCmt, fontStyle: FontStyle.italic),
    'doctag':          TextStyle(color: sCmt),
    'meta':            TextStyle(color: textMid),
    'meta-keyword':    TextStyle(color: sKw),
    'meta-string':     TextStyle(color: sStr),
    'attr':            TextStyle(color: sAtr),
    'attribute':       TextStyle(color: sAtr),
    'variable':        TextStyle(color: text),
    'tag':             TextStyle(color: sTag),
    'name':            TextStyle(color: sTag),
    'property':        TextStyle(color: sProp),
    'selector-tag':    TextStyle(color: sTag),
    'selector-id':     TextStyle(color: cyan),
    'selector-class':  TextStyle(color: sCls),
    'selector-attr':   TextStyle(color: sAtr),
    'selector-pseudo': TextStyle(color: sKw),
    'operator':        TextStyle(color: sOp),
    'punctuation':     TextStyle(color: sOp),
    'link':            TextStyle(color: cyan),
    'addition':        TextStyle(color: green),
    'deletion':        TextStyle(color: red),
    'emphasis':        const TextStyle(fontStyle: FontStyle.italic),
    'strong':          const TextStyle(fontWeight: FontWeight.bold),
    'section':         TextStyle(color: sFn, fontWeight: FontWeight.bold),
    'bullet':          TextStyle(color: sStr),
    'code':            TextStyle(color: sStr),
    'formula':         TextStyle(color: sStr),
    'quote':           TextStyle(color: sCmt),
  };

  // ── Built-in themes ────────────────────────────────────────────────────────

  // 1. DevPad Dark (original)
  static const devpadDark = EditorTheme(
    id: 'devpad_dark', name: 'DevPad Dark', dark: true,
    bg: Color(0xFF080B14), bg2: Color(0xFF0D1120),
    surface: Color(0xFF111827), surface2: Color(0xFF161D2E),
    surface3: Color(0xFF1C2438), surface4: Color(0xFF222D40),
    border: Color(0xFF1E2A42), border2: Color(0xFF243050), border3: Color(0xFF2D3A55),
    accent: Color(0xFF3B82F6), accentDim: Color(0x203B82F6),
    accentGlow: Color(0x403B82F6), accentHover: Color(0xFF2563EB),
    green: Color(0xFF22D3A0), red: Color(0xFFF87171), yellow: Color(0xFFFBBF24),
    orange: Color(0xFFFB923C), purple: Color(0xFFA78BFA), cyan: Color(0xFF67E8F9),
    pink: Color(0xFFF472B6), teal: Color(0xFF2DD4BF),
    text: Color(0xFFE2E8F4), textMid: Color(0xFF94A3B8), textDim: Color(0xFF4A5568),
    textFaint: Color(0xFF2D3748), lineNum: Color(0xFF2D3748),
    curLine: Color(0x08FFFFFF), selection: Color(0x303B82F6),
    sKw: Color(0xFFC084FC), sStr: Color(0xFF86EFAC), sNum: Color(0xFFFDBA74),
    sCmt: Color(0xFF4A6080), sTag: Color(0xFFF87171), sAtr: Color(0xFFFCD34D),
    sVal: Color(0xFF86EFAC), sProp: Color(0xFF67E8F9), sFn: Color(0xFF93C5FD),
    sCls: Color(0xFFFDE68A), sOp: Color(0xFF94A3B8), sBool: Color(0xFFFB923C),
    sRx: Color(0xFFF9A8D4),
  );

  // 2. One Dark
  static const oneDark = EditorTheme(
    id: 'one_dark', name: 'One Dark', dark: true,
    bg: Color(0xFF282C34), bg2: Color(0xFF21252B),
    surface: Color(0xFF2C313A), surface2: Color(0xFF333842),
    surface3: Color(0xFF3B4048), surface4: Color(0xFF404859),
    border: Color(0xFF3E4451), border2: Color(0xFF4B5263), border3: Color(0xFF5C6370),
    accent: Color(0xFF61AFEF), accentDim: Color(0x2061AFEF),
    accentGlow: Color(0x4061AFEF), accentHover: Color(0xFF528BCC),
    green: Color(0xFF98C379), red: Color(0xFFE06C75), yellow: Color(0xFFE5C07B),
    orange: Color(0xFFD19A66), purple: Color(0xFFC678DD), cyan: Color(0xFF56B6C2),
    pink: Color(0xFFFF6AC1), teal: Color(0xFF56B6C2),
    text: Color(0xFFABB2BF), textMid: Color(0xFF848D9A), textDim: Color(0xFF5C6370),
    textFaint: Color(0xFF3E4451), lineNum: Color(0xFF495162),
    curLine: Color(0x0CFFFFFF), selection: Color(0x3061AFEF),
    sKw: Color(0xFFC678DD), sStr: Color(0xFF98C379), sNum: Color(0xFFD19A66),
    sCmt: Color(0xFF5C6370), sTag: Color(0xFFE06C75), sAtr: Color(0xFFD19A66),
    sVal: Color(0xFF98C379), sProp: Color(0xFF56B6C2), sFn: Color(0xFF61AFEF),
    sCls: Color(0xFFE5C07B), sOp: Color(0xFF848D9A), sBool: Color(0xFFD19A66),
    sRx: Color(0xFF56B6C2),
  );

  // 3. Dracula
  static const dracula = EditorTheme(
    id: 'dracula', name: 'Dracula', dark: true,
    bg: Color(0xFF282A36), bg2: Color(0xFF21222C),
    surface: Color(0xFF2D2F3F), surface2: Color(0xFF343646),
    surface3: Color(0xFF3C3F50), surface4: Color(0xFF44475A),
    border: Color(0xFF44475A), border2: Color(0xFF4F526A), border3: Color(0xFF6272A4),
    accent: Color(0xFFBD93F9), accentDim: Color(0x20BD93F9),
    accentGlow: Color(0x40BD93F9), accentHover: Color(0xFFA57AF5),
    green: Color(0xFF50FA7B), red: Color(0xFFFF5555), yellow: Color(0xFFF1FA8C),
    orange: Color(0xFFFFB86C), purple: Color(0xFFBD93F9), cyan: Color(0xFF8BE9FD),
    pink: Color(0xFFFF79C6), teal: Color(0xFF50FA7B),
    text: Color(0xFFF8F8F2), textMid: Color(0xFFCBCCC6), textDim: Color(0xFF6272A4),
    textFaint: Color(0xFF44475A), lineNum: Color(0xFF44475A),
    curLine: Color(0x0EFFFFFF), selection: Color(0x30BD93F9),
    sKw: Color(0xFFFF79C6), sStr: Color(0xFFF1FA8C), sNum: Color(0xFFBD93F9),
    sCmt: Color(0xFF6272A4), sTag: Color(0xFFFF79C6), sAtr: Color(0xFF50FA7B),
    sVal: Color(0xFFF1FA8C), sProp: Color(0xFF8BE9FD), sFn: Color(0xFF50FA7B),
    sCls: Color(0xFF8BE9FD), sOp: Color(0xFFCBCCC6), sBool: Color(0xFFBD93F9),
    sRx: Color(0xFF8BE9FD),
  );

  // 4. Monokai
  static const monokai = EditorTheme(
    id: 'monokai', name: 'Monokai', dark: true,
    bg: Color(0xFF272822), bg2: Color(0xFF1E1F1C),
    surface: Color(0xFF2D2E27), surface2: Color(0xFF333428),
    surface3: Color(0xFF3A3B2E), surface4: Color(0xFF414235),
    border: Color(0xFF3A3B2E), border2: Color(0xFF484940), border3: Color(0xFF555650),
    accent: Color(0xFFA6E22E), accentDim: Color(0x20A6E22E),
    accentGlow: Color(0x40A6E22E), accentHover: Color(0xFF8FCB22),
    green: Color(0xFFA6E22E), red: Color(0xFFF92672), yellow: Color(0xFFE6DB74),
    orange: Color(0xFFFD971F), purple: Color(0xFFAE81FF), cyan: Color(0xFF66D9E8),
    pink: Color(0xFFF92672), teal: Color(0xFF66D9E8),
    text: Color(0xFFF8F8F2), textMid: Color(0xFFCFCFC2), textDim: Color(0xFF75715E),
    textFaint: Color(0xFF49483E), lineNum: Color(0xFF49483E),
    curLine: Color(0x0DFFFFFF), selection: Color(0x30A6E22E),
    sKw: Color(0xFFF92672), sStr: Color(0xFFE6DB74), sNum: Color(0xFFAE81FF),
    sCmt: Color(0xFF75715E), sTag: Color(0xFFF92672), sAtr: Color(0xFFA6E22E),
    sVal: Color(0xFFE6DB74), sProp: Color(0xFF66D9E8), sFn: Color(0xFFA6E22E),
    sCls: Color(0xFF66D9E8), sOp: Color(0xFFF8F8F2), sBool: Color(0xFFAE81FF),
    sRx: Color(0xFFE6DB74),
  );

  // 5. GitHub Light
  static const githubLight = EditorTheme(
    id: 'github_light', name: 'GitHub Light', dark: false,
    bg: Color(0xFFFFFFFF), bg2: Color(0xFFF6F8FA),
    surface: Color(0xFFFFFFFF), surface2: Color(0xFFF6F8FA),
    surface3: Color(0xFFEAECEF), surface4: Color(0xFFD0D7DE),
    border: Color(0xFFD0D7DE), border2: Color(0xFFBEC5CE), border3: Color(0xFF9EA7B3),
    accent: Color(0xFF0969DA), accentDim: Color(0x200969DA),
    accentGlow: Color(0x400969DA), accentHover: Color(0xFF0550AE),
    green: Color(0xFF116329), red: Color(0xFFCF222E), yellow: Color(0xFF9A6700),
    orange: Color(0xFFBC4C00), purple: Color(0xFF8250DF), cyan: Color(0xFF0969DA),
    pink: Color(0xFFBF3989), teal: Color(0xFF1B7C83),
    text: Color(0xFF1F2328), textMid: Color(0xFF636C76), textDim: Color(0xFF9EA7B3),
    textFaint: Color(0xFFD0D7DE), lineNum: Color(0xFFBEC5CE),
    curLine: Color(0x0A000000), selection: Color(0x300969DA),
    sKw: Color(0xFFCF222E), sStr: Color(0xFF0A3069), sNum: Color(0xFF0550AE),
    sCmt: Color(0xFF9EA7B3), sTag: Color(0xFF116329), sAtr: Color(0xFF0550AE),
    sVal: Color(0xFF0A3069), sProp: Color(0xFF0550AE), sFn: Color(0xFF8250DF),
    sCls: Color(0xFF953800), sOp: Color(0xFF636C76), sBool: Color(0xFF0550AE),
    sRx: Color(0xFF0A3069),
  );

  static const all = [devpadDark, oneDark, dracula, monokai, githubLight];

  static EditorTheme byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => devpadDark);
}

// ═══════════════════════════════════════════
//  CODE FOLDING
// ═══════════════════════════════════════════

/// Manages fold ranges for a single file.
///
/// foldableRanges: all detected block start→end pairs (line numbers, 1-based).
/// foldedStarts:  set of block start lines currently folded.
///
/// Folding is view-only — the underlying text is never modified.
class FoldingManager {
  /// All foldable ranges. key=startLine (1-based), value=endLine (inclusive).
  Map<int, int> foldableRanges = {};

  /// Set of start lines currently folded.
  final Set<int> foldedStarts = {};

  bool isFoldable(int line) => foldableRanges.containsKey(line);
  bool isFolded(int line)   => foldedStarts.contains(line);

  void toggle(int startLine) {
    if (!foldableRanges.containsKey(startLine)) return;
    if (foldedStarts.contains(startLine)) {
      foldedStarts.remove(startLine);
    } else {
      foldedStarts.add(startLine);
    }
  }

  void unfoldAll() => foldedStarts.clear();

  /// Recompute foldable ranges from [text].
  /// Removes any foldedStart that no longer has a valid range.
  void recompute(String text) {
    foldableRanges = _detectRanges(text);
    foldedStarts.removeWhere((s) => !foldableRanges.containsKey(s));
  }

  /// Build the display-line list from [originalLines], skipping hidden lines.
  /// Returns parallel lists:
  ///   displayLines: lines visible on screen
  ///   origIndex:    original line index (0-based) for each display line
  ///   isPlaceholder: true if this display line is the "··· N lines" stub
  ({
    List<String> displayLines,
    List<int>    origIndex,
    List<bool>   isPlaceholder,
  }) buildDisplay(List<String> originalLines) {
    final display = <String>[];
    final orig    = <int>[];
    final isPh    = <bool>[];
    int i = 0;
    while (i < originalLines.length) {
      final lineNo = i + 1; // 1-based
      if (foldedStarts.contains(lineNo) && foldableRanges.containsKey(lineNo)) {
        final endLine = foldableRanges[lineNo]!;
        final hidden  = endLine - lineNo;   // lines hidden
        // Show the start line with a placeholder suffix
        display.add('${originalLines[i]}  ··· $hidden lines');
        orig.add(i);
        isPh.add(true);
        i = endLine; // skip to end line (endLine is included in fold, shown by next iteration)
      } else {
        display.add(originalLines[i]);
        orig.add(i);
        isPh.add(false);
        i++;
      }
    }
    return (displayLines: display, origIndex: orig, isPlaceholder: isPh);
  }

  /// Convert a display-line cursor offset back to the original text offset.
  int displayOffsetToOriginal(int displayOffset, List<String> originalLines) {
    if (foldedStarts.isEmpty) return displayOffset;
    final disp = buildDisplay(originalLines);
    // Find which display line the offset falls on
    int remaining = displayOffset;
    for (int d = 0; d < disp.displayLines.length; d++) {
      final lineLen = disp.displayLines[d].length + 1; // +1 for \n
      if (remaining < lineLen || d == disp.displayLines.length - 1) {
        // Map to original
        final origLine  = disp.origIndex[d];
        int origOffset  = 0;
        for (int l = 0; l < origLine; l++) {
          origOffset += originalLines[l].length + 1;
        }
        return origOffset + math.min(remaining, originalLines[origLine].length);
      }
      remaining -= lineLen;
    }
    return displayOffset;
  }

  // ── Detection algorithm ──────────────────────────────────────────────────
  // Finds matching bracket pairs across lines.
  // Also handles indentation-based folding for languages without brackets.
  static Map<int, int> _detectRanges(String text) {
    final lines   = text.split('\n');
    final ranges  = <int, int>{};
    final stack   = <({int line, String open})>[];

    for (int i = 0; i < lines.length; i++) {
      final stripped = lines[i].trimRight();
      // Count opens and closes on this line
      int opens  = 0, closes = 0;
      bool inStr = false; String strCh = '';
      for (int c = 0; c < stripped.length; c++) {
        final ch = stripped[c];
        if (!inStr && (ch == '"' || ch == "'" || ch == '`')) {
          inStr = true; strCh = ch; continue;
        }
        if (inStr) { if (ch == strCh && (c == 0 || stripped[c-1] != '\\')) inStr = false; continue; }
        if (ch == '{' || ch == '[' || ch == '(') {
          opens++;
          stack.add((line: i + 1, open: ch));
        }
        if (ch == '}' || ch == ']' || ch == ')') {
          closes++;
          if (stack.isNotEmpty) {
            final top = stack.last;
            // Only record if the block spans at least 2 lines
            if (i + 1 > top.line) {
              ranges[top.line] = i + 1;
            }
            stack.removeLast();
          }
        }
      }
    }
    return ranges;
  }
}

// ═══════════════════════════════════════════
//  FILE TREE
// ═══════════════════════════════════════════

enum TreeNodeType { file, folder }

class TreeNode {
  final String id;
  String       name;
  TreeNodeType type;
  String?      fileId;      // non-null when type == file, links to CodeFile.id
  bool         expanded;
  List<TreeNode> children;
  String?      parentId;

  TreeNode({
    required this.id,
    required this.name,
    required this.type,
    this.fileId,
    this.expanded   = true,
    List<TreeNode>? children,
    this.parentId,
  }) : children = children ?? [];

  bool get isFile   => type == TreeNodeType.file;
  bool get isFolder => type == TreeNodeType.folder;

  // ── Serialisation ─────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'id':       id,
    'name':     name,
    'type':     type.index,
    'fileId':   fileId,
    'expanded': expanded,
    'parentId': parentId,
    'children': children.map((c) => c.toJson()).toList(),
  };

  factory TreeNode.fromJson(Map<String, dynamic> j) => TreeNode(
    id:       j['id']       as String,
    name:     j['name']     as String,
    type:     TreeNodeType.values[j['type'] as int],
    fileId:   j['fileId']   as String?,
    expanded: j['expanded'] as bool? ?? true,
    parentId: j['parentId'] as String?,
    children: (j['children'] as List<dynamic>? ?? [])
        .map((c) => TreeNode.fromJson(c as Map<String, dynamic>))
        .toList(),
  );

  // ── Mutation helpers ──────────────────────────────────────────────────────
  /// Flat list of all nodes in depth-first order.
  List<TreeNode> flatten() {
    final result = <TreeNode>[this];
    if (isFolder && expanded) {
      for (final c in children) result.addAll(c.flatten());
    }
    return result;
  }

  /// Find a node by id anywhere in the subtree.
  TreeNode? findById(String nodeId) {
    if (id == nodeId) return this;
    for (final c in children) {
      final found = c.findById(nodeId);
      if (found != null) return found;
    }
    return null;
  }

  /// Remove a child by id. Returns true if removed.
  bool removeChild(String nodeId) {
    final before = children.length;
    children.removeWhere((c) => c.id == nodeId);
    if (children.length < before) return true;
    for (final c in children) {
      if (c.removeChild(nodeId)) return true;
    }
    return false;
  }

  /// Insert [node] as child of [parentId]. Root = insert at root level if parentId == null.
  bool insertInto(String? parentId, TreeNode node) {
    if (this.id == parentId) {
      node.parentId = this.id;
      children.add(node);
      _sortChildren();
      return true;
    }
    for (final c in children) {
      if (c.insertInto(parentId, node)) return true;
    }
    return false;
  }

  void _sortChildren() {
    children.sort((a, b) {
      // Folders first, then alphabetical
      if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

  /// Deep copy
  TreeNode clone() => TreeNode.fromJson(toJson());
}
class FindOptions {
  bool caseSensitive;
  bool wholeWord;
  bool useRegex;
  FindOptions({
    this.caseSensitive = false,
    this.wholeWord     = false,
    this.useRegex      = false,
  });
}

class FindMatch {
  final int start;
  final int length;
  const FindMatch(this.start, this.length);
}

/// A search hit across all files.
class FileMatch {
  final String fileId;
  final String fileName;
  final int    lineNumber;   // 1-based
  final String lineText;     // full line content
  final int    matchStart;   // column offset within lineText
  final int    matchLength;
  const FileMatch({
    required this.fileId,
    required this.fileName,
    required this.lineNumber,
    required this.lineText,
    required this.matchStart,
    required this.matchLength,
  });
}

// ═══════════════════════════════════════════
//  CONSOLE
// ═══════════════════════════════════════════
enum LogLevel { log, info, warn, error }

extension LogLevelX on LogLevel {
  Color get color {
    switch (this) {
      case LogLevel.log:   return const Color(0xFFE2E8F4);
      case LogLevel.info:  return const Color(0xFF67E8F9);
      case LogLevel.warn:  return const Color(0xFFFBBF24);
      case LogLevel.error: return const Color(0xFFF87171);
    }
  }
  String get icon {
    switch (this) {
      case LogLevel.log:   return '›';
      case LogLevel.info:  return 'ℹ';
      case LogLevel.warn:  return '⚠';
      case LogLevel.error: return '✕';
    }
  }
}

class LogEntry {
  final LogLevel level;
  final String message;
  final String time;
  LogEntry({required this.level, required this.message, required this.time});
}

// ═══════════════════════════════════════════
//  OUTLINE ITEM
// ═══════════════════════════════════════════
class OutlineItem {
  final String label;
  final String kind;
  final int line;
  final Color color;
  const OutlineItem({
    required this.label,
    required this.kind,
    required this.line,
    required this.color,
  });
}

// ═══════════════════════════════════════════
//  COMPLETION ITEM
// ═══════════════════════════════════════════
class CompletionItem {
  final String label;
  final String insertText;
  final String kind;
  final String detail;
  final String? documentation;
  const CompletionItem({
    required this.label,
    required this.insertText,
    required this.kind,
    this.detail = '',
    this.documentation,
  });
}

// ═══════════════════════════════════════════
//  GIT / DIFF
// ═══════════════════════════════════════════

enum DiffLineType { unchanged, added, removed, modified }

class DiffLine {
  final int lineNo; // 1-based line number in CURRENT file
  final DiffLineType type;
  const DiffLine(this.lineNo, this.type);
}

class FileDiff {
  final List<DiffLine> lines;
  final int added, removed, modified;
  const FileDiff(this.lines, this.added, this.removed, this.modified);
  static const empty = FileDiff([], 0, 0, 0);

  // Quick lookup: lineNo → type (1-based)
  Map<int, DiffLineType> get byLine {
    final m = <int, DiffLineType>{};
    for (final d in lines) m[d.lineNo] = d.type;
    return m;
  }
}

class DiffEngine {
  static FileDiff diff(String base, String current) {
    if (base == current) return FileDiff.empty;
    final aLines = base.split('\n');
    final bLines = current.split('\n');
    final ops    = _lcs(aLines, bLines);

    final result = <DiffLine>[];
    int added = 0, removed = 0, modified = 0;
    int ai = 0, bi = 0;

    for (final op in ops) {
      switch (op) {
        case '=':
          result.add(DiffLine(bi + 1, DiffLineType.unchanged));
          ai++; bi++;
        case '+':
          // Check if there was a preceding '-' (same block → modified)
          final prev = result.isNotEmpty ? result.last : null;
          if (prev != null &&
              prev.type == DiffLineType.removed &&
              prev.lineNo == bi) {
            result.removeLast();
            removed--;
            result.add(DiffLine(bi + 1, DiffLineType.modified));
            modified++;
          } else {
            result.add(DiffLine(bi + 1, DiffLineType.added));
            added++;
          }
          bi++;
        case '-':
          // Record a removed marker at current bi position
          result.add(DiffLine(bi + 1, DiffLineType.removed));
          removed++;
          ai++;
      }
    }

    // Remove 'removed' entries that don't map to current lines
    final clean = result.where((d) => d.type != DiffLineType.removed).toList();
    return FileDiff(clean, added, removed, modified);
  }

  static List<String> _lcs(List<String> a, List<String> b) {
    final n = a.length, m = b.length;
    if (n > 2000 || m > 2000) return _fastDiff(a, b);
    final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
    for (int i = n - 1; i >= 0; i--) {
      for (int j = m - 1; j >= 0; j--) {
        dp[i][j] = a[i] == b[j]
            ? dp[i + 1][j + 1] + 1
            : math.max(dp[i + 1][j], dp[i][j + 1]);
      }
    }
    final ops = <String>[];
    int i = 0, j = 0;
    while (i < n && j < m) {
      if (a[i] == b[j]) { ops.add('='); i++; j++; }
      else if (dp[i + 1][j] >= dp[i][j + 1]) { ops.add('-'); i++; }
      else { ops.add('+'); j++; }
    }
    while (i++ < n) ops.add('-');
    while (j++ < m) ops.add('+');
    return ops;
  }

  static List<String> _fastDiff(List<String> a, List<String> b) {
    final baseSet = <String, int>{};
    for (final l in a) baseSet[l] = (baseSet[l] ?? 0) + 1;
    final ops = <String>[];
    for (final l in b) {
      if ((baseSet[l] ?? 0) > 0) { ops.add('='); baseSet[l] = baseSet[l]! - 1; }
      else { ops.add('+'); }
    }
    return ops;
  }
}
