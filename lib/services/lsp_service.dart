// lib/services/lsp_service.dart
// Static LSP engine — provides diagnostics, hover tooltips, and completions
// without requiring a language server process (mobile-compatible).
//
// The API mirrors the Language Server Protocol so it can be replaced with
// a real LSP client in the future with minimal changes.

import 'dart:math' as math;
import '../models/models.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  MODELS
// ══════════════════════════════════════════════════════════════════════════════

enum DiagnosticSeverity { error, warning, info, hint }

class LspPosition {
  final int line;   // 0-based
  final int column; // 0-based
  const LspPosition(this.line, this.column);
}

class LspRange {
  final LspPosition start, end;
  const LspRange(this.start, this.end);
}

class LspDiagnostic {
  final LspRange           range;
  final DiagnosticSeverity severity;
  final String             message;
  final String             source; // e.g. 'html', 'css', 'js'
  const LspDiagnostic({
    required this.range,
    required this.severity,
    required this.message,
    required this.source,
  });

  // 1-based line for display
  int get line1 => range.start.line + 1;
}

class LspHover {
  final String content;    // markdown-like text
  final LspRange? range;   // word range that triggered hover
  const LspHover(this.content, [this.range]);
}

// ══════════════════════════════════════════════════════════════════════════════
//  LSP SERVICE
// ══════════════════════════════════════════════════════════════════════════════

class LspService {
  // Cached diagnostics per file id
  final Map<String, List<LspDiagnostic>> _cache = {};

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Analyse [content] for [lang] and return diagnostics.
  /// Results are cached by [fileId] and cleared when content changes.
  List<LspDiagnostic> diagnose(String fileId, String content, Language lang) {
    final diags = _runAnalysis(content, lang);
    _cache[fileId] = diags;
    return diags;
  }

  List<LspDiagnostic> cached(String fileId) => _cache[fileId] ?? [];

  void clearCache(String fileId) => _cache.remove(fileId);

  /// Hover tooltip for the word at [offset] in [content].
  LspHover? hover(String content, int offset, Language lang) {
    if (offset < 0 || offset >= content.length) return null;
    final word = _wordAt(content, offset);
    if (word.isEmpty) return null;
    final doc = _hoverDocs[lang]?[word];
    if (doc == null) return null;
    return LspHover('**$word**\n\n$doc');
  }

  // ── Analysis dispatcher ───────────────────────────────────────────────────

  List<LspDiagnostic> _runAnalysis(String content, Language lang) {
    return switch (lang) {
      Language.html => _analyseHtml(content),
      Language.css  => _analyseCss(content),
      Language.js   => _analyseJs(content),
      Language.dart => _analyseDart(content),
      _             => [],
    };
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HTML ANALYSIS
  // ══════════════════════════════════════════════════════════════════════════
  List<LspDiagnostic> _analyseHtml(String content) {
    final diags = <LspDiagnostic>[];
    final lines = content.split('\n');

    // Track open tags for unmatched detection
    final stack = <({String tag, int line, int col})>[];
    final voidTags = {'area','base','br','col','embed','hr','img','input',
        'link','meta','param','source','track','wbr'};

    for (int li = 0; li < lines.length; li++) {
      final line = lines[li];

      // ── Find all tags on this line ──────────────────────────────────────
      final tagRe = RegExp('<(/?)([a-zA-Z][a-zA-Z0-9.-]*)([^>]*)(/?)>');
      for (final m in tagRe.allMatches(line)) {
        final isClose = m.group(1) == '/';
        final tag     = m.group(2)!.toLowerCase();
        final selfClose = m.group(4) == '/' || voidTags.contains(tag);
        final col     = m.start;

        if (!isClose && !selfClose) {
          stack.add((tag: tag, line: li, col: col));
        } else if (isClose) {
          if (stack.isNotEmpty && stack.last.tag == tag) {
            stack.removeLast();
          } else if (stack.any((e) => e.tag == tag)) {
            // Improperly nested
            diags.add(_diag(li, col, li, col + m.group(0)!.length,
                DiagnosticSeverity.warning,
                'Improperly nested closing tag </$tag>', 'html'));
          } else {
            diags.add(_diag(li, col, li, col + m.group(0)!.length,
                DiagnosticSeverity.error,
                'Unexpected closing tag </$tag> — no matching opening tag', 'html'));
          }
        }

        // ── img without alt ──────────────────────────────────────────────
        if (tag == 'img' && !m.group(3)!.contains('alt')) {
          diags.add(_diag(li, col, li, col + m.group(0)!.length,
              DiagnosticSeverity.warning,
              'img element is missing alt attribute (accessibility)', 'html'));
        }

        // ── Deprecated tags ──────────────────────────────────────────────
        const deprecated = {'font', 'center', 'marquee', 'blink', 'strike'};
        if (deprecated.contains(tag)) {
          diags.add(_diag(li, col, li, col + m.group(0)!.length,
              DiagnosticSeverity.warning,
              '<$tag> is deprecated — use CSS instead', 'html'));
        }
      }

      // ── Inline style / onclick warning ──────────────────────────────────
      if (line.contains('style="') || line.contains("style='")) {
        final col = line.indexOf('style=');
        diags.add(_diag(li, col, li, col + 6,
            DiagnosticSeverity.info,
            'Avoid inline styles — use external CSS', 'html'));
      }
    }

    // Report unclosed tags (last 5 only to avoid noise)
    for (final open in stack.reversed.take(5)) {
      diags.add(_diag(open.line, open.col, open.line, open.col + open.tag.length + 1,
          DiagnosticSeverity.error,
          'Unclosed tag <${open.tag}>', 'html'));
    }

    return diags;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CSS ANALYSIS
  // ══════════════════════════════════════════════════════════════════════════
  List<LspDiagnostic> _analyseCss(String content) {
    final diags = <LspDiagnostic>[];
    final lines = content.split('\n');

    int braceDepth = 0;
    for (int li = 0; li < lines.length; li++) {
      final line   = lines[li];
      final trimmed = line.trimLeft();

      // Count braces
      braceDepth += '{'.allMatches(line).length;
      braceDepth -= '}'.allMatches(line).length;
      braceDepth  = math.max(0, braceDepth);

      // ── Property without value ─────────────────────────────────────────
      if (trimmed.contains(':') && !trimmed.contains('//')) {
        final colonIdx = trimmed.indexOf(':');
        final value    = trimmed.substring(colonIdx + 1).trim().replaceAll(';', '').trim();
        if (value.isEmpty && !trimmed.trimRight().endsWith('{')) {
          diags.add(_diag(li, 0, li, line.length,
              DiagnosticSeverity.error,
              'CSS property has no value', 'css'));
        }
      }

      // ── Missing semicolon after value (inside a rule block) ───────────
      if (braceDepth > 0 && trimmed.contains(':') && !trimmed.contains('{')) {
        if (!trimmed.trimRight().endsWith(';') &&
            !trimmed.trimRight().endsWith(',') &&
            !trimmed.trimRight().endsWith('{') &&
            !trimmed.trimRight().endsWith('}')) {
          diags.add(_diag(li, 0, li, line.length,
              DiagnosticSeverity.warning,
              'Missing semicolon at end of CSS declaration', 'css'));
        }
      }

      // ── Vendor prefix without standard ────────────────────────────────
      if (trimmed.startsWith('-webkit-') || trimmed.startsWith('-moz-')) {
        diags.add(_diag(li, 0, li, math.min(20, line.length),
            DiagnosticSeverity.hint,
            'Vendor-prefixed property — ensure standard property is also present', 'css'));
      }
    }

    // Unmatched braces
    if (braceDepth != 0) {
      diags.add(_diag(lines.length - 1, 0, lines.length - 1, 1,
          DiagnosticSeverity.error,
          'Unmatched braces — $braceDepth unclosed block(s)', 'css'));
    }

    return diags;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  JAVASCRIPT ANALYSIS
  // ══════════════════════════════════════════════════════════════════════════
  List<LspDiagnostic> _analyseJs(String content) {
    final diags = <LspDiagnostic>[];
    final lines = content.split('\n');

    for (int li = 0; li < lines.length; li++) {
      final line    = lines[li];
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('//')) continue;

      // ── var usage (prefer const/let) ───────────────────────────────────
      if (RegExp(r'\bvar\s+').hasMatch(trimmed)) {
        final col = line.indexOf('var');
        diags.add(_diag(li, col, li, col + 3,
            DiagnosticSeverity.warning,
            "Use 'const' or 'let' instead of 'var'", 'js'));
      }

      // ── == instead of === ─────────────────────────────────────────────
      if (RegExp(r'[^=!<>]==[^=]').hasMatch(trimmed)) {
        final col = trimmed.indexOf('==');
        diags.add(_diag(li, col, li, col + 2,
            DiagnosticSeverity.warning,
            "Use '===' (strict equality) instead of '=='", 'js'));
      }

      // ── console.log in production ─────────────────────────────────────
      if (trimmed.contains('console.log')) {
        final col = line.indexOf('console.log');
        diags.add(_diag(li, col, li, col + 11,
            DiagnosticSeverity.info,
            'Remove console.log before production', 'js'));
      }

      // ── eval() usage ──────────────────────────────────────────────────
      if (RegExp(r'\beval\s*\(').hasMatch(trimmed)) {
        final col = line.indexOf('eval');
        diags.add(_diag(li, col, li, col + 4,
            DiagnosticSeverity.error,
            "eval() is dangerous and should not be used", 'js'));
      }

      // ── Unused await (await without async function check) ─────────────
      if (trimmed.startsWith('await ') &&
          !content.substring(0, math.max(0, content.indexOf('\n' * li)))
              .contains('async')) {
        final col = line.indexOf('await');
        diags.add(_diag(li, col, li, col + 5,
            DiagnosticSeverity.error,
            "'await' used outside of an async function", 'js'));
      }
    }

    // ── Bracket balance ────────────────────────────────────────────────────
    int p = 0, b = 0, c = 0;
    bool inStr = false; String strCh = '';
    for (int i = 0; i < content.length; i++) {
      final ch = content[i];
      if (!inStr && (ch == '"' || ch == "'" || ch == '`')) { inStr = true; strCh = ch; continue; }
      if (inStr) { if (ch == strCh && (i == 0 || content[i-1] != '\\')) inStr = false; continue; }
      if (ch == '(') p++; else if (ch == ')') p--;
      if (ch == '[') b++; else if (ch == ']') b--;
      if (ch == '{') c++; else if (ch == '}') c--;
    }
    if (p != 0 || b != 0 || c != 0) {
      diags.add(_diag(0, 0, 0, 1, DiagnosticSeverity.error,
          'Unmatched brackets: '
          '${p != 0 ? "parentheses ($p)" : ""}'
          '${b != 0 ? " brackets [$b]" : ""}'
          '${c != 0 ? " braces {$c}" : ""}', 'js'));
    }

    return diags;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DART ANALYSIS
  // ══════════════════════════════════════════════════════════════════════════
  List<LspDiagnostic> _analyseDart(String content) {
    final diags = <LspDiagnostic>[];
    final lines = content.split('\n');

    for (int li = 0; li < lines.length; li++) {
      final line    = lines[li];
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('//')) continue;

      // ── print() in production ─────────────────────────────────────────
      if (RegExp(r'\bprint\s*\(').hasMatch(trimmed)) {
        final col = line.indexOf('print');
        diags.add(_diag(li, col, li, col + 5,
            DiagnosticSeverity.info,
            'Avoid print() in production code — use a logger', 'dart'));
      }

      // ── dynamic usage ─────────────────────────────────────────────────
      if (RegExp(r'\bdynamic\b').hasMatch(trimmed)) {
        final col = line.indexOf('dynamic');
        diags.add(_diag(li, col, li, col + 7,
            DiagnosticSeverity.warning,
            "Prefer explicit types over 'dynamic'", 'dart'));
      }

      // ── TODO/FIXME comments ───────────────────────────────────────────
      if (trimmed.contains('TODO:') || trimmed.contains('FIXME:')) {
        diags.add(_diag(li, 0, li, line.length,
            DiagnosticSeverity.info,
            trimmed.contains('FIXME') ? 'FIXME — needs attention' : 'TODO item', 'dart'));
      }

      // ── Missing return type ───────────────────────────────────────────
      if (RegExp(r'^\s+(void|int|String|bool|double|List|Map|Set|Future)\s+\w+\s*\(').hasMatch(line) ||
          RegExp(r'^\s+\w+\s+\w+\s*\(').hasMatch(line)) {
        // OK — has a type
      } else if (RegExp(r'^\s+\w+\s*\([^)]*\)\s*(async\s*)?\{').hasMatch(line) &&
                 !trimmed.startsWith('if') && !trimmed.startsWith('for') &&
                 !trimmed.startsWith('while') && !trimmed.startsWith('switch')) {
        final col = line.indexOf(RegExp(r'\w'));
        diags.add(_diag(li, col, li, line.length,
            DiagnosticSeverity.hint,
            'Method is missing explicit return type annotation', 'dart'));
      }
    }

    return diags;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  LspDiagnostic _diag(int sl, int sc, int el, int ec,
      DiagnosticSeverity severity, String message, String source) =>
      LspDiagnostic(
        range:    LspRange(LspPosition(sl, sc), LspPosition(el, ec)),
        severity: severity,
        message:  message,
        source:   source,
      );

  String _wordAt(String content, int offset) {
    int start = offset, end = offset;
    while (start > 0 && _isWordChar(content[start - 1])) start--;
    while (end < content.length && _isWordChar(content[end])) end++;
    return content.substring(start, end);
  }

  bool _isWordChar(String ch) => RegExp(r'[\w-]').hasMatch(ch);

  // ══════════════════════════════════════════════════════════════════════════
  //  HOVER DOCS
  // ══════════════════════════════════════════════════════════════════════════
  static final Map<Language, Map<String, String>> _hoverDocs = {
    Language.html: {
      'div':    'Generic block-level container. No semantic meaning.',
      'span':   'Generic inline container. No semantic meaning.',
      'p':      'Paragraph element. Represents a block of text.',
      'a':      'Anchor element. Creates a hyperlink.',
      'img':    'Image element. Requires alt attribute for accessibility.',
      'input':  'Form input element. Use type attribute to specify kind.',
      'button': 'Clickable button element.',
      'form':   'Form element. Groups input controls.',
      'table':  'Table element. Use for tabular data only.',
      'header': 'Semantic header — typically contains navigation/logo.',
      'footer': 'Semantic footer — typically contains copyright/links.',
      'main':   'Main content area — only one per page.',
      'nav':    'Navigation links.',
      'section':'Thematic grouping of content.',
      'article':'Self-contained content (blog post, news, etc.).',
      'aside':  'Secondary/sidebar content.',
      'h1':     'Top-level heading. One per page recommended.',
      'h2':     'Second-level heading.',
      'ul':     'Unordered (bulleted) list.',
      'ol':     'Ordered (numbered) list.',
      'li':     'List item — child of ul or ol.',
      'link':   'Links external resources (stylesheets, icons).',
      'script': 'Embeds or references JavaScript.',
      'style':  'Embeds CSS. Prefer external stylesheets.',
      'meta':   'Document metadata (charset, viewport, description, etc.).',
      'title':  'Document title — shown in browser tab.',
    },
    Language.css: {
      'display':         'Controls box model: block, inline, flex, grid, none.',
      'position':        'Positioning: static, relative, absolute, fixed, sticky.',
      'flex':            'Shorthand for flex-grow, flex-shrink, flex-basis.',
      'grid':            'Shorthand for CSS Grid layout.',
      'margin':          'Outer spacing. Values: top right bottom left.',
      'padding':         'Inner spacing. Values: top right bottom left.',
      'color':           'Text color. Values: hex, rgb, hsl, named colors.',
      'background':      'Background shorthand (color, image, position, size).',
      'font-size':       'Text size. Use rem for accessibility.',
      'font-weight':     '100–900 or bold/normal.',
      'border-radius':   'Rounds corners. Single value or per-corner.',
      'transition':      'Animates property changes: property duration timing.',
      'transform':       'Applies 2D/3D transforms: rotate, scale, translate.',
      'z-index':         'Stacking order. Higher = in front.',
      'opacity':         '0 (transparent) to 1 (opaque).',
      'overflow':        'visible, hidden, scroll, auto.',
      'box-shadow':      'Drop shadow: x y blur spread color.',
      'media':           '@media query for responsive breakpoints.',
      'var':             'CSS custom property: --name: value; usage: var(--name).',
      'animation':       'Keyframe animation shorthand.',
      'justify-content': 'Flexbox/Grid main-axis alignment.',
      'align-items':     'Flexbox/Grid cross-axis alignment.',
    },
    Language.js: {
      'const':      'Block-scoped constant. Cannot be reassigned.',
      'let':        'Block-scoped variable. Can be reassigned.',
      'var':        'Function-scoped variable. Avoid in modern JS.',
      'async':      'Marks a function as asynchronous. Returns a Promise.',
      'await':      'Pauses async function until Promise resolves.',
      'fetch':      'fetch(url, options) → Promise<Response>. Makes HTTP requests.',
      'Promise':    'Represents an async operation. States: pending, fulfilled, rejected.',
      'map':        'Array.map(fn) → new array with each element transformed.',
      'filter':     'Array.filter(fn) → new array with elements that pass the test.',
      'reduce':     'Array.reduce(fn, init) → accumulates to a single value.',
      'forEach':    'Array.forEach(fn) → iterates without returning a new array.',
      'JSON':       'JSON.parse(str) / JSON.stringify(obj) for JSON conversion.',
      'localStorage':'Browser key-value storage. Persists across sessions.',
      'setTimeout': 'setTimeout(fn, ms) → runs fn after delay.',
      'console':    'Debugging output. Remove before production.',
      'document':   'DOM entry point. document.querySelector/getElementById etc.',
      'window':     'Global browser object. Contains location, history, etc.',
      'typeof':     'Returns type as string: "string", "number", "boolean", etc.',
      'Array':      'Array.isArray(), Array.from(), Array.of() static methods.',
      'Object':     'Object.keys(), Object.values(), Object.entries(), Object.assign().',
    },
    Language.dart: {
      'final':    'Runtime constant. Can only be set once.',
      'const':    'Compile-time constant. Deeply immutable.',
      'var':      'Type-inferred variable.',
      'late':     'Non-nullable variable initialized after declaration.',
      'async':    'Marks function as asynchronous. Returns Future.',
      'await':    'Suspends execution until Future completes.',
      'Future':   'Represents an async computation. Use with await.',
      'Stream':   'Sequence of async events. Use StreamBuilder in Flutter.',
      'setState': 'Marks a StatefulWidget for rebuild.',
      'build':    'Returns the widget tree for this widget.',
      'context':  'BuildContext — location in the widget tree.',
      'Widget':   'Base class for all Flutter UI elements.',
      'StatelessWidget': 'Immutable widget — no internal state.',
      'StatefulWidget':  'Widget with mutable state via State<T>.',
      'Navigator':'Manages a stack of Route objects.',
      'Scaffold': 'Basic Material page structure.',
      'Column':   'Arranges children vertically.',
      'Row':      'Arranges children horizontally.',
      'Container':'Box model widget with decoration, padding, margin.',
      'Text':     'Displays a string of text.',
      'GestureDetector': 'Detects tap, drag, and other gestures.',
      'ListView': 'Scrollable list of widgets.',
      'FutureBuilder': 'Builds UI based on Future state.',
      'StreamBuilder':  'Builds UI based on Stream events.',
    },
  };
}
