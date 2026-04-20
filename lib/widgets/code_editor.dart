// lib/widgets/code_editor.dart
// DevPad Pro v2 — Virtual Rendering Engine
//
// Architecture:
//   CodeEditor
//     ├── _VirtualGutter   (CustomPainter — draws only visible line numbers)
//     └── _VirtualEditorBody
//           ├── SingleChildScrollView  (owns the scroll physics)
//           │     └── _VirtualLinePainterWidget  (RenderBox — draws visible lines only)
//           └── _InvisibleInput  (1×1 px TextField — owns the IME/keyboard)
//
// Only lines currently in the viewport ± kOverscan are painted.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:highlight/highlight.dart' show highlight, Node;
import '../utils/theme.dart';
import '../models/models.dart';
import '../services/editor_controller.dart';
import '../services/lsp_service.dart';

// ── tunables ─────────────────────────────────────────────────────────────────
const int    _kOverscan   = 6;     // extra lines above/below viewport
const double _kGutterW    = 48.0;
const double _kHPad       = 16.0;
const double _kTopPad     = 8.0;

// ══════════════════════════════════════════════════════════════════════════════
//  CodeEditor  (public entry point)
// ══════════════════════════════════════════════════════════════════════════════
class CodeEditor extends StatefulWidget {
  final EditorController ctrl;
  final void Function(Offset) onContextMenu;
  const CodeEditor({super.key, required this.ctrl, required this.onContextMenu});
  @override
  State<CodeEditor> createState() => _CodeEditorState();
}

class _CodeEditorState extends State<CodeEditor> {
  final ScrollController _gutterScroll = ScrollController();
  int    _lineCount = 1;
  int    _curLine   = 1;
  TextScaler _textScaler = TextScaler.noScaling;

  EditorController get ctrl => widget.ctrl;
  double get fontSize   => ctrl.settings.fontSize;
  double get lineHeight => fontSize * ctrl.settings.lineHeight;

  @override
  void initState() {
    super.initState();
    ctrl.activeCtrl.addListener(_onTextChanged);
    ctrl.activeScroll.addListener(_syncGutter);
    _syncLineCount();
    _updateCurLine();
  }

  @override
  void didUpdateWidget(CodeEditor old) {
    super.didUpdateWidget(old);
    if (old.ctrl.activeCtrl != ctrl.activeCtrl) {
      old.ctrl.activeCtrl.removeListener(_onTextChanged);
      ctrl.activeCtrl.addListener(_onTextChanged);
      _syncLineCount();
      _updateCurLine();
    }
    if (old.ctrl.activeScroll != ctrl.activeScroll) {
      old.ctrl.activeScroll.removeListener(_syncGutter);
      ctrl.activeScroll.addListener(_syncGutter);
    }
  }

  @override
  void dispose() {
    ctrl.activeCtrl.removeListener(_onTextChanged);
    ctrl.activeScroll.removeListener(_syncGutter);
    _gutterScroll.dispose();
    super.dispose();
  }

  void _syncLineCount() =>
      _lineCount = math.max(1, ctrl.activeCtrl.text.split('\n').length);

  void _updateCurLine() {
    final text = ctrl.activeCtrl.text;
    final sel  = ctrl.activeCtrl.selection;
    if (sel.isValid && sel.isCollapsed) {
      _curLine = text.substring(0, sel.start.clamp(0, text.length))
          .split('\n').length;
    }
  }

  void _onTextChanged() {
    final text     = ctrl.activeCtrl.text;
    final origLines = text.split('\n');
    // Line count shown = display lines (after folding), not original
    final dispLines = ctrl.folding.foldedStarts.isEmpty
        ? origLines.length
        : ctrl.folding.buildDisplay(origLines).displayLines.length;
    final nc = math.max(1, dispLines);
    _updateCurLine();
    final sel = ctrl.activeCtrl.selection;
    if (sel.isValid && sel.isCollapsed) {
      _updateCursorOffset(text, sel.start);
      ctrl.updateBracketMatchAt(sel.start);
    }
    if (nc != _lineCount) {
      setState(() => _lineCount = nc);
    } else {
      setState(() {});
    }
  }

  void _syncGutter() {
    if (!_gutterScroll.hasClients || !ctrl.activeScroll.hasClients) return;
    final t = ctrl.activeScroll.offset;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_gutterScroll.hasClients) {
        _gutterScroll.jumpTo(t.clamp(0.0, _gutterScroll.position.maxScrollExtent));
      }
    });
  }

  void _updateCursorOffset(String text, int pos) {
    final before    = text.substring(0, pos);
    final lineStart = before.lastIndexOf('\n') + 1;
    final tp = TextPainter(
      text: TextSpan(
        text: before.substring(lineStart),
        style: TextStyle(fontFamily: ctrl.settings.fontFamily,
            fontSize: fontSize, color: T.text),
      ),
      textDirection: TextDirection.ltr,
      textScaler: _textScaler,
    )..layout();
    final vOff = ctrl.activeScroll.hasClients ? ctrl.activeScroll.offset : 0.0;
    ctrl.acCursorOffset = Offset(
      _kGutterW + _kHPad + tp.width,
      _kTopPad + (_curLine - 1) * lineHeight - vOff,
    );
  }

  @override
  Widget build(BuildContext context) {
    _textScaler = MediaQuery.textScalerOf(context);
    return GestureDetector(
      onLongPressStart: (d) => widget.onContextMenu(d.globalPosition),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Gutter ──────────────────────────────────────────────────────
        _VirtualGutter(
          gutterScroll: _gutterScroll,
          lineCount:    _lineCount,
          curLine:      _curLine,
          lineHeight:   lineHeight,
          fontSize:     fontSize,
          ctrl:         ctrl,
        ),
        // ── Editor body ──────────────────────────────────────────────────
        Expanded(
          child: _VirtualEditorBody(
            ctrl:       ctrl,
            lineHeight: lineHeight,
            fontSize:   fontSize,
            lineCount:  _lineCount,
            curLine:    _curLine,
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  VIRTUAL GUTTER
// ══════════════════════════════════════════════════════════════════════════════
class _VirtualGutter extends StatelessWidget {
  final ScrollController gutterScroll;
  final int lineCount, curLine;
  final double lineHeight, fontSize;
  final EditorController ctrl;

  const _VirtualGutter({
    required this.gutterScroll, required this.lineCount,
    required this.curLine,      required this.lineHeight,
    required this.fontSize,     required this.ctrl,
  });

  /// Build a map of 1-based line number → worst severity for fast gutter lookup.
  static Map<int, DiagnosticSeverity> _buildLspByLine(
      List<LspDiagnostic> diags) {
    final m = <int, DiagnosticSeverity>{};
    for (final d in diags) {
      final ln = d.line1;
      final existing = m[ln];
      if (existing == null || d.severity.index < existing.index) {
        m[ln] = d.severity;
      }
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final totalH = _kTopPad + lineCount * lineHeight + 64;
    return Container(
      width: _kGutterW, color: T.bg2,
      child: LayoutBuilder(builder: (ctx, box) {
        return NotificationListener<ScrollNotification>(
          onNotification: (_) => true,
          child: SingleChildScrollView(
            controller: gutterScroll,
            physics: const NeverScrollableScrollPhysics(),
            child: GestureDetector(
              onTapDown: (d) {
                // Hit-test: which display line was tapped?
                final scrollOff = gutterScroll.hasClients ? gutterScroll.offset : 0.0;
                final tapY      = d.localPosition.dy + scrollOff - _kTopPad;
                final lineIdx   = (tapY / lineHeight).floor() + 1; // 1-based display line
                ctrl.toggleFold(lineIdx);
              },
              child: CustomPaint(
                size: Size(_kGutterW, totalH),
                painter: _GutterPainter(
                  lineCount:     lineCount,
                  curLine:       curLine,
                  lineHeight:    lineHeight,
                  fontSize:      fontSize,
                  viewHeight:    box.maxHeight,
                  scroll:        gutterScroll,
                  textScaler:    MediaQuery.textScalerOf(context),
                  folding:       ctrl.folding,
                  originalLines: ctrl.activeCtrl.text.split('\n'),
                  diffByLine:    ctrl.gitDiff.byLine,
                  lspByLine:     _buildLspByLine(ctrl.lspDiagnostics),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _GutterPainter extends CustomPainter {
  final int lineCount, curLine;
  final double lineHeight, fontSize, viewHeight;
  final ScrollController scroll;
  final TextScaler textScaler;
  final FoldingManager folding;
  final List<String> originalLines;
  final Map<int, DiffLineType>         diffByLine;
  final Map<int, DiagnosticSeverity>   lspByLine;

  const _GutterPainter({
    required this.lineCount,   required this.curLine,
    required this.lineHeight,  required this.fontSize,
    required this.viewHeight,  required this.scroll,
    required this.textScaler,  required this.folding,
    required this.originalLines, required this.diffByLine,
    required this.lspByLine,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scrollOff = scroll.hasClients ? scroll.offset : 0.0;
    final first = math.max(0, (scrollOff / lineHeight).floor() - _kOverscan);
    final last  = math.min(lineCount - 1,
        ((scrollOff + viewHeight) / lineHeight).ceil() + _kOverscan);

    final disp = folding.buildDisplay(originalLines);

    for (int i = first; i <= last; i++) {
      if (i >= disp.origIndex.length) break;
      final origIdx  = disp.origIndex[i];
      final origLine = origIdx + 1;         // 1-based
      final isCur    = origLine == curLine;
      final lineY    = _kTopPad + i * lineHeight;
      final dy       = lineY + (lineHeight - (fontSize - 2)) / 2;

      // ── Git diff bar (left edge, 3px wide) ───────────────────────────
      final diffType = diffByLine[origLine];
      if (diffType != null && diffType != DiffLineType.unchanged) {
        final barColor = switch (diffType) {
          DiffLineType.added    => T.green,
          DiffLineType.modified => T.accent,
          DiffLineType.removed  => T.red,
          _                     => Colors.transparent,
        };
        canvas.drawRect(
          Rect.fromLTWH(0, lineY + 1, 3, lineHeight - 2),
          Paint()..color = barColor.withOpacity(0.85),
        );
      }

      // ── Line number ──────────────────────────────────────────────────
      final tp = TextPainter(
        text: TextSpan(
          text: '$origLine',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: fontSize - 2,
            color: isCur ? T.textMid : T.lineNum,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout(maxWidth: _kGutterW - 18);
      tp.paint(canvas, Offset(_kGutterW - 18 - tp.width, dy));

      // ── Fold icon ────────────────────────────────────────────────────
      if (folding.isFoldable(origLine)) {
        final isFolded = folding.isFolded(origLine);
        final iconY    = lineY + (lineHeight - 10) / 2;
        _drawFoldIcon(canvas, Offset(_kGutterW - 12, iconY), isFolded);
      }

      // ── LSP diagnostic dot (right edge) ──────────────────────────────
      final lspSev = lspByLine[origLine];
      if (lspSev != null) {
        final dotColor = switch (lspSev) {
          DiagnosticSeverity.error   => T.red,
          DiagnosticSeverity.warning => T.orange,
          DiagnosticSeverity.info    => T.accent,
          DiagnosticSeverity.hint    => T.textDim,
        };
        canvas.drawCircle(
          Offset(_kGutterW - 4, lineY + lineHeight / 2),
          3.0,
          Paint()..color = dotColor,
        );
      }
    }
  }

  void _drawFoldIcon(Canvas canvas, Offset center, bool isFolded) {
    final paint = Paint()
      ..color      = T.textDim
      ..style      = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap  = StrokeCap.round;

    if (isFolded) {
      final path = Path()
        ..moveTo(center.dx - 3, center.dy - 4)
        ..lineTo(center.dx + 4, center.dy)
        ..lineTo(center.dx - 3, center.dy + 4)
        ..close();
      canvas.drawPath(path, paint..style = PaintingStyle.fill..color = T.textDim.withOpacity(0.5));
      canvas.drawPath(path, paint..style = PaintingStyle.stroke..color = T.textDim);
    } else {
      final path = Path()
        ..moveTo(center.dx - 4, center.dy - 2)
        ..lineTo(center.dx + 4, center.dy - 2)
        ..lineTo(center.dx,     center.dy + 4)
        ..close();
      canvas.drawPath(path, paint..style = PaintingStyle.fill..color = T.textDim.withOpacity(0.3));
      canvas.drawPath(path, paint..style = PaintingStyle.stroke..color = T.textDim);
    }
  }

  @override
  bool shouldRepaint(_GutterPainter old) =>
      old.lineCount  != lineCount  || old.curLine    != curLine  ||
      old.lineHeight != lineHeight || old.fontSize   != fontSize ||
      old.folding.foldedStarts != folding.foldedStarts ||
      old.diffByLine != diffByLine ||
      old.lspByLine  != lspByLine;
}

// ══════════════════════════════════════════════════════════════════════════════
//  VIRTUAL EDITOR BODY
// ══════════════════════════════════════════════════════════════════════════════
class _VirtualEditorBody extends StatefulWidget {
  final EditorController ctrl;
  final double lineHeight, fontSize;
  final int lineCount, curLine;
  const _VirtualEditorBody({
    required this.ctrl,      required this.lineHeight,
    required this.fontSize,  required this.lineCount,
    required this.curLine,
  });
  @override
  State<_VirtualEditorBody> createState() => _VirtualEditorBodyState();
}

class _VirtualEditorBodyState extends State<_VirtualEditorBody> {
  // ── Per-file highlight cache ───────────────────────────────────────────────
  final Map<String, List<List<TextSpan>>> _spanCache = {};
  final Map<String, String>               _codeCache = {};

  EditorController get ctrl      => widget.ctrl;
  double           get lineHeight => widget.lineHeight;
  double           get fontSize   => widget.fontSize;

  @override
  void initState() {
    super.initState();
    ctrl.activeCtrl.addListener(_onChanged);
    ctrl.activeScroll.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(_VirtualEditorBody old) {
    super.didUpdateWidget(old);
    if (old.ctrl.activeCtrl != ctrl.activeCtrl) {
      old.ctrl.activeCtrl.removeListener(_onChanged);
      ctrl.activeCtrl.addListener(_onChanged);
    }
    if (old.ctrl.activeScroll != ctrl.activeScroll) {
      old.ctrl.activeScroll.removeListener(_onScroll);
      ctrl.activeScroll.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    ctrl.activeCtrl.removeListener(_onChanged);
    ctrl.activeScroll.removeListener(_onScroll);
    _dismissHover();
    super.dispose();
  }

  void _onChanged() { if (mounted) setState(() {}); }
  void _onScroll()  { if (mounted) setState(() {}); }

  // ── Highlight (per display line) ──────────────────────────────────────────
  List<List<TextSpan>> _getLineSpans(String code, String lang, String id) {
    // Build full line spans for original code
    if (_codeCache[id] != code || !_spanCache.containsKey(id)) {
      _spanCache[id] = _buildFullSpans(code, lang, id);
      _codeCache[id] = code;
    }
    final fullSpans = _spanCache[id]!;

    // Apply folding: filter to display lines only
    final folding = ctrl.folding;
    if (folding.foldedStarts.isEmpty) return fullSpans;

    final origLines = code.split('\n');
    final disp      = folding.buildDisplay(origLines);
    final result    = <List<TextSpan>>[];
    for (int i = 0; i < disp.origIndex.length; i++) {
      final oi = disp.origIndex[i];
      if (disp.isPlaceholder[i] && oi < fullSpans.length) {
        // Add placeholder styling for folded line
        final base  = oi < fullSpans.length ? fullSpans[oi] : <TextSpan>[];
        final stub  = TextSpan(
          text: '  ··· ${ctrl.folding.foldableRanges[oi + 1]! - oi - 1} lines',
          style: TextStyle(color: T.textDim, fontStyle: FontStyle.italic),
        );
        result.add([...base, stub]);
      } else if (oi < fullSpans.length) {
        result.add(fullSpans[oi]);
      } else {
        result.add([]);
      }
    }
    return result;
  }

  List<List<TextSpan>> _buildFullSpans(String code, String lang, String id) {
    List<TextSpan> flat;
    try {
      final r = highlight.parse(
        code.isEmpty ? ' ' : code, language: lang, autoDetection: false);
      if (r.nodes != null && r.nodes!.isNotEmpty) {
        flat = [];
        _flatten(r.nodes!, flat);
        if (flat.isEmpty) flat = [TextSpan(text: code, style: TextStyle(color: T.text))];
      } else {
        flat = [TextSpan(text: code, style: TextStyle(color: T.text))];
      }
    } catch (_) {
      if (_spanCache.containsKey(id)) return _spanCache[id]!;
      flat = [TextSpan(text: code, style: TextStyle(color: T.text))];
    }

    // Split flat list into per-line buckets
    final lines = <List<TextSpan>>[];
    List<TextSpan> cur = [];
    for (final span in flat) {
      final t = span.text ?? '';
      if (!t.contains('\n')) {
        if (t.isNotEmpty) cur.add(span);
        continue;
      }
      final parts = t.split('\n');
      for (int p = 0; p < parts.length; p++) {
        if (parts[p].isNotEmpty) cur.add(TextSpan(text: parts[p], style: span.style));
        if (p < parts.length - 1) { lines.add(cur); cur = []; }
      }
    }
    lines.add(cur);
    return lines;
  }

  void _flatten(List<Node> nodes, List<TextSpan> out) {
    for (final n in nodes) {
      if (n.value != null) {
        final c = n.className != null ? T.syntaxTheme[n.className]?.color : null;
        out.add(TextSpan(text: n.value, style: TextStyle(color: c ?? T.text)));
      } else if (n.children != null) {
        final c = n.className != null ? T.syntaxTheme[n.className]?.color : null;
        final child = <TextSpan>[];
        _flatten(n.children!, child);
        for (final cs in child) {
          out.add(TextSpan(
            text: cs.text,
            style: (cs.style ?? const TextStyle())
                .copyWith(color: cs.style?.color ?? c),
            children: cs.children,
          ));
        }
      }
    }
  }

  // ── Drag selection anchor (long-press drag) ───────────────────────────────
  int? _dragAnchor;

  // ── Hover tooltip (LSP) ───────────────────────────────────────────────────
  LspHover?     _hover;
  OverlayEntry? _hoverOverlay;
  Offset?       _hoverPos;

  void _showHover(Offset globalPos, int textOffset) {
    _dismissHover();
    final hover = ctrl.hoverAt(textOffset);
    if (hover == null) return;
    _hover    = hover;
    _hoverPos = globalPos;
    _hoverOverlay = OverlayEntry(builder: (_) => _HoverTooltip(
      hover:     hover,
      position:  globalPos,
      onDismiss: _dismissHover,
    ));
    Overlay.of(context).insert(_hoverOverlay!);
  }

  void _dismissHover() {
    _hoverOverlay?.remove();
    _hoverOverlay = null;
    _hover        = null;
    _hoverPos     = null;
  }

  void _onTap(TapDownDetails d) {
    _dismissHover(); // dismiss hover on any tap
    if (ctrl.hasExtraCursors) {
      ctrl.clearExtraCursors();
      return;
    }
    _dragAnchor = null;
    final off = _offsetFromLocalPosition(d.localPosition);
    ctrl.activeCtrl.selection = TextSelection.collapsed(offset: off);
    ctrl.activeFocus.requestFocus();
  }

  // Long-press:
  //  - If editor has focus AND hover docs exist → show hover tooltip
  //  - If editor has focus AND no hover docs → add extra cursor
  //  - If editor is not focused → begin selection drag
  void _onLongPressStart(LongPressStartDetails d) {
    final off = _offsetFromLocalPosition(d.localPosition);
    if (ctrl.activeFocus.hasFocus) {
      // Try to show hover first; fall back to extra cursor if no docs
      final hover = ctrl.hoverAt(off);
      if (hover != null) {
        _showHover(d.globalPosition, off);
        _dragAnchor = null;
      } else {
        ctrl.addExtraCursor(off);
        ctrl.activeFocus.requestFocus();
        _dragAnchor = null;
      }
    } else {
      _dragAnchor = off;
      ctrl.activeCtrl.selection = TextSelection.collapsed(offset: off);
      ctrl.activeFocus.requestFocus();
    }
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails d) {
    if (_dragAnchor == null) return;
    final cur = _offsetFromLocalPosition(d.localPosition);
    ctrl.activeCtrl.selection = TextSelection(
      baseOffset:   math.min(_dragAnchor!, cur),
      extentOffset: math.max(_dragAnchor!, cur),
    );
  }

  void _onLongPressEnd(LongPressEndDetails _) => _dragAnchor = null;

  int _offsetFromLocalPosition(Offset local) {
    final scrollOff = ctrl.activeScroll.hasClients ? ctrl.activeScroll.offset : 0.0;
    final tapY  = local.dy + scrollOff - _kTopPad;
    final tapX  = local.dx - _kHPad;
    final lines = ctrl.activeCtrl.text.split('\n');
    final lineIdx = (tapY / lineHeight).floor().clamp(0, lines.length - 1);
    final line    = lines[lineIdx];
    final col     = _xToCol(line, tapX);
    int offset = 0;
    for (int i = 0; i < lineIdx; i++) offset += lines[i].length + 1;
    return (offset + col).clamp(0, ctrl.activeCtrl.text.length);
  }

  int _xToCol(String line, double tx) {
    if (line.isEmpty || tx <= 0) return 0;
    final style = TextStyle(fontFamily: ctrl.settings.fontFamily, fontSize: fontSize, color: T.text);
    double prev = 0;
    for (int i = 1; i <= line.length; i++) {
      final tp = TextPainter(
        text: TextSpan(text: line.substring(0, i), style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      if (tp.width >= tx) return (tx - prev < tp.width - tx) ? i - 1 : i;
      prev = tp.width;
    }
    return line.length;
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final code      = ctrl.activeCtrl.text;
    final lang      = ctrl.activeFile.lang.hlLang;
    final id        = ctrl.activeId;
    final lh        = lineHeight;
    final fs        = fontSize;
    final lc        = widget.lineCount;
    final cl        = widget.curLine;
    final qkH       = ctrl.quickKeysHeight;
    final kbInset   = MediaQuery.of(context).viewInsets.bottom;
    final botPad    = kbInset > 0 ? qkH + 24.0 : qkH + 16.0;
    final totalH    = _kTopPad + lc * lh + botPad;
    final lineSpans  = _getLineSpans(code, lang, id);
    final textScaler = MediaQuery.textScalerOf(context);
    final scrollOff  = ctrl.activeScroll.hasClients ? ctrl.activeScroll.offset : 0.0;

    return LayoutBuilder(builder: (ctx, box) {
      final vw = box.maxWidth;
      final vh = box.maxHeight;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown:             _onTap,
        onLongPressStart:      _onLongPressStart,
        onLongPressMoveUpdate: _onLongPressMoveUpdate,
        onLongPressEnd:        _onLongPressEnd,
        child: Stack(children: [
          // ── Scrollable virtual canvas ──────────────────────────────────
          SingleChildScrollView(
            controller: ctrl.activeScroll,
            physics: ctrl.settings.smoothScroll
                ? const BouncingScrollPhysics()
                : const ClampingScrollPhysics(),
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size(vw, totalH),
                painter: _VirtualLinePainter(
                  ctrl:         ctrl,
                  lineSpans:    lineSpans,
                  lineCount:    lc,
                  curLine:      cl,
                  lineHeight:   lh,
                  fontSize:     fs,
                  viewWidth:    vw,
                  viewHeight:   vh,
                  scroll:       ctrl.activeScroll,
                  textScaler:   textScaler,
                  scrollOffset: scrollOff,
                ),
              ),
            ),
          ),

          // ── Invisible 1×1 TextField — owns the IME ────────────────────
          Positioned(
            left: 0, top: 0, width: 1, height: 1,
            child: _InvisibleInput(ctrl: ctrl),
          ),
        ]),
      );
    });
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  VIRTUAL LINE PAINTER  (CustomPainter)
// ══════════════════════════════════════════════════════════════════════════════
class _VirtualLinePainter extends CustomPainter {
  final EditorController     ctrl;
  final List<List<TextSpan>> lineSpans;
  final int                  lineCount, curLine;
  final double               lineHeight, fontSize, viewWidth, viewHeight;
  final ScrollController     scroll;
  final TextScaler           textScaler;
  // Passed explicitly so shouldRepaint fires when the user scrolls.
  final double               scrollOffset;

  const _VirtualLinePainter({
    required this.ctrl,       required this.lineSpans,
    required this.lineCount,  required this.curLine,
    required this.lineHeight, required this.fontSize,
    required this.viewWidth,  required this.viewHeight,
    required this.scroll,     required this.textScaler,
    required this.scrollOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scrollOff = scroll.hasClients ? scroll.offset : 0.0;

    // Only paint what's visible
    final first = math.max(0, (scrollOff / lineHeight).floor() - _kOverscan);
    final last  = math.min(lineCount - 1,
        ((scrollOff + viewHeight) / lineHeight).ceil() + _kOverscan);

    final text = ctrl.activeCtrl.text;
    final sel  = ctrl.activeCtrl.selection;

    // 1 ── Current-line highlight
    if (ctrl.settings.curlineHighlight) {
      canvas.drawRect(
        Rect.fromLTWH(0, _kTopPad + (curLine - 1) * lineHeight, viewWidth, lineHeight),
        Paint()..color = T.curLine,
      );
    }

    // 2 ── Bracket match highlight
    final bm = ctrl.bracketMatch;
    if (bm != null) {
      _paintBracketHighlight(canvas, text, bm.open,  bm.matched);
      _paintBracketHighlight(canvas, text, bm.close, bm.matched);
    }

    // 3 ── Selection highlight
    if (sel.isValid && !sel.isCollapsed) {
      _paintSelection(canvas, sel, text);
    }

    // 4 ── Text (only visible lines)
    final baseStyle = TextStyle(
      fontFamily: ctrl.settings.fontFamily,
      fontSize:   fontSize,
      height:     lineHeight / fontSize,
      color:      T.text,
    );
    final maxW = ctrl.settings.wordwrap
        ? math.max(0.0, viewWidth - _kHPad * 2)
        : double.infinity;

    for (int i = first; i <= last; i++) {
      if (i >= lineSpans.length) break;
      final spans = lineSpans[i];
      if (spans.isEmpty) continue;
      final tp = TextPainter(
        text: TextSpan(style: baseStyle, children: spans),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout(maxWidth: maxW);
      tp.paint(canvas, Offset(_kHPad, _kTopPad + i * lineHeight));
    }

    // 5 ── Primary cursor
    if (ctrl.activeFocus.hasFocus && sel.isValid && sel.isCollapsed) {
      _paintCursor(canvas, text, sel.start, T.text, 1.5);
    }

    // 6 ── Extra cursors (multi-cursor)
    for (final offset in ctrl.extraCursorOffsets) {
      _paintCursor(canvas, text, offset, T.accent, 1.5);
      // Draw a small circle indicator at the cursor base
      _paintCursorDot(canvas, text, offset);
    }
  }

  /// Draws a coloured rounded rect behind the bracket at [pos].
  /// Green background when matched, red when unmatched.
  void _paintBracketHighlight(Canvas canvas, String text, int pos, bool matched) {
    if (pos < 0 || pos >= text.length) return;
    final before  = text.substring(0, pos);
    final lineIdx = before.split('\n').length - 1;
    final lines   = text.split('\n');
    final line    = lineIdx < lines.length ? lines[lineIdx] : '';
    final col     = pos - (before.lastIndexOf('\n') + 1);
    final style   = TextStyle(
        fontFamily: ctrl.settings.fontFamily, fontSize: fontSize, color: T.text);

    final x0     = col > 0 ? _measureText(line.substring(0, col), style) : 0.0;
    final charW  = _measureText(col < line.length ? line[col] : ' ', style);
    final lineY  = _kTopPad + lineIdx * lineHeight;
    final color  = matched ? T.green : T.red;
    final rect   = RRect.fromRectAndRadius(
      Rect.fromLTWH(_kHPad + x0, lineY + 2, math.max(charW, 8.0), lineHeight - 4),
      const Radius.circular(3),
    );

    canvas.drawRRect(rect, Paint()..color = color.withOpacity(0.22));
    canvas.drawRRect(rect, Paint()
      ..color = color.withOpacity(0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0);
  }

  void _paintSelection(Canvas canvas, TextSelection sel, String text) {
    final lines      = text.split('\n');
    final selPaint   = Paint()..color = T.selection;
    final baseStyle  = TextStyle(
      fontFamily: ctrl.settings.fontFamily, fontSize: fontSize, color: T.text);

    int lineStart = 0;
    for (int i = 0; i < lines.length; i++) {
      final lineEnd = lineStart + lines[i].length;
      if (lineEnd >= sel.start && lineStart <= sel.end) {
        final colStart = math.max(0, sel.start - lineStart);
        final colEnd   = math.min(lines[i].length, sel.end - lineStart);
        final lineY    = _kTopPad + i * lineHeight;

        double x0 = 0, x1 = viewWidth - _kHPad;
        if (colStart > 0) {
          x0 = _measureText(lines[i].substring(0, colStart), baseStyle);
        }
        if (colEnd < lines[i].length) {
          x1 = _measureText(lines[i].substring(0, colEnd), baseStyle);
        }
        canvas.drawRect(
          Rect.fromLTWH(_kHPad + x0, lineY, math.max(4.0, x1 - x0), lineHeight),
          selPaint,
        );
      }
      lineStart = lineEnd + 1;
    }
  }

  void _paintCursor(Canvas canvas, String text, int pos,
      [Color? color, double strokeW = 1.5]) {
    pos = pos.clamp(0, text.length);
    final before  = text.substring(0, pos);
    final lineIdx = before.split('\n').length - 1;
    final lines   = text.split('\n');
    final line    = lineIdx < lines.length ? lines[lineIdx] : '';
    final col     = pos - (before.lastIndexOf('\n') + 1);
    final style   = TextStyle(
        fontFamily: ctrl.settings.fontFamily, fontSize: fontSize, color: T.text);

    final curX = col > 0 && col <= line.length
        ? _measureText(line.substring(0, col), style)
        : 0.0;
    final curY = _kTopPad + lineIdx * lineHeight;

    canvas.drawLine(
      Offset(_kHPad + curX, curY + 2),
      Offset(_kHPad + curX, curY + lineHeight - 2),
      Paint()..color = (color ?? T.text)..strokeWidth = strokeW,
    );
  }

  /// Draws a small accent-coloured dot at the bottom of an extra cursor
  /// so it's visually distinct from the primary cursor.
  void _paintCursorDot(Canvas canvas, String text, int pos) {
    pos = pos.clamp(0, text.length);
    final before  = text.substring(0, pos);
    final lineIdx = before.split('\n').length - 1;
    final lines   = text.split('\n');
    final line    = lineIdx < lines.length ? lines[lineIdx] : '';
    final col     = pos - (before.lastIndexOf('\n') + 1);
    final style   = TextStyle(
        fontFamily: ctrl.settings.fontFamily, fontSize: fontSize, color: T.text);

    final curX = col > 0 && col <= line.length
        ? _measureText(line.substring(0, col), style)
        : 0.0;
    final curY = _kTopPad + (lineIdx + 1) * lineHeight - 3;

    canvas.drawCircle(
      Offset(_kHPad + curX, curY),
      3.0,
      Paint()..color = T.accent,
    );
  }

  double _measureText(String text, TextStyle style) {
    if (text.isEmpty) return 0;
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    return tp.width;
  }

  @override
  bool shouldRepaint(_VirtualLinePainter old) =>
      old.lineSpans              != lineSpans              ||
      old.lineCount              != lineCount              ||
      old.curLine                != curLine                ||
      old.lineHeight             != lineHeight             ||
      old.fontSize               != fontSize              ||
      old.viewWidth              != viewWidth              ||
      old.viewHeight             != viewHeight             ||
      old.scrollOffset           != scrollOffset           ||
      old.ctrl.bracketMatch      != ctrl.bracketMatch      ||
      old.ctrl.extraCursorOffsets != ctrl.extraCursorOffsets;
}

// ══════════════════════════════════════════════════════════════════════════════
//  INVISIBLE INPUT  — thin wrapper that gives the keyboard a home
// ══════════════════════════════════════════════════════════════════════════════
class _InvisibleInput extends StatelessWidget {
  final EditorController ctrl;
  const _InvisibleInput({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller:        ctrl.activeCtrl,
      focusNode:         ctrl.activeFocus,
      maxLines:          null,
      keyboardType:      TextInputType.multiline,
      textInputAction:   TextInputAction.newline,
      autocorrect:       false,
      enableSuggestions: false,
      style: const TextStyle(fontSize: 1, color: Colors.transparent, height: 1),
      cursorColor: Colors.transparent,
      cursorWidth: 0,
      decoration: const InputDecoration(
        border:             InputBorder.none,
        enabledBorder:      InputBorder.none,
        focusedBorder:      InputBorder.none,
        disabledBorder:     InputBorder.none,
        errorBorder:        InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        isDense: true,
      ),
      inputFormatters: [
        _SmartIndentFormatter(
          ctrl.settings.tabSize,
          ctrl.settings.useTabs,
          ctrl.settings.autopairs,
          ctrl,
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SMART INDENT FORMATTER
// ══════════════════════════════════════════════════════════════════════════════
class _SmartIndentFormatter extends TextInputFormatter {
  final int tabSize;
  final bool useTabs, autoPairs;
  final EditorController ctrl;

  static const _pairs = {'(':')', '[':']', '{':'}', '"':'"', "'":"'", '`':'`'};

  const _SmartIndentFormatter(
      this.tabSize, this.useTabs, this.autoPairs, this.ctrl);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue nv) {
    final result = _format(old, nv);
    // Replicate delta to extra cursors after this frame
    if (result != old && ctrl.hasExtraCursors) {
      Future.microtask(() => ctrl.replicateDelta(old, result));
    }
    return result;
  }

  TextEditingValue _format(TextEditingValue old, TextEditingValue nv) {
    if (nv.text.length != old.text.length + 1) return nv;
    final newChar = nv.text[nv.selection.start - 1];

    // ── Auto-pair ──────────────────────────────────────────────────────────
    if (autoPairs && _pairs.containsKey(newChar)) {
      final close   = _pairs[newChar]!;
      final isQuote = newChar == '"' || newChar == "'" || newChar == '`';
      final before  = nv.text.substring(0, nv.selection.start);
      final after   = nv.text.substring(nv.selection.start);
      // Skip-over
      if (after.isNotEmpty && after[0] == close) {
        final corrected = before.substring(0, before.length - 1) + after;
        return TextEditingValue(
          text: corrected,
          selection: TextSelection.collapsed(
              offset: nv.selection.start.clamp(0, corrected.length)),
        );
      }
      // Smart quote guard
      if (isQuote && before.length >= 2 &&
          RegExp(r'\w').hasMatch(before[before.length - 2])) return nv;
      // Insert closer
      return TextEditingValue(
        text: before + close + after,
        selection: TextSelection.collapsed(offset: nv.selection.start),
      );
    }

    // ── Auto-indent ────────────────────────────────────────────────────────
    if (newChar == '\n') {
      final cb     = old.selection.start;
      final ls     = old.text.lastIndexOf('\n', cb - 1) + 1;
      final curL   = old.text.substring(ls, cb);
      final indent = RegExp(r'^(\s*)').firstMatch(curL)?.group(1) ?? '';
      final tab    = useTabs ? '\t' : (' ' * tabSize);
      String extra = '';
      final trimmed = curL.trimRight();
      if (trimmed.endsWith('{') || trimmed.endsWith('(') || trimmed.endsWith('[')) {
        extra = tab;
      }
      final before = nv.text.substring(0, nv.selection.start);
      final after  = nv.text.substring(nv.selection.start);
      final newPos = nv.selection.start + indent.length + extra.length;
      if (extra.isNotEmpty) {
        final at = after.trimLeft();
        if (at.startsWith('}') || at.startsWith(')') || at.startsWith(']')) {
          return TextEditingValue(
            text: before + indent + extra + '\n' + indent + after.trimLeft(),
            selection: TextSelection.collapsed(offset: newPos),
          );
        }
      }
      return TextEditingValue(
        text: before + indent + extra + after,
        selection: TextSelection.collapsed(offset: newPos),
      );
    }

    // ── Tab → spaces ───────────────────────────────────────────────────────
    if (newChar == '\t' && !useTabs) {
      final spaces = ' ' * tabSize;
      final before = nv.text.substring(0, nv.selection.start - 1);
      final after  = nv.text.substring(nv.selection.start);
      return TextEditingValue(
        text: before + spaces + after,
        selection: TextSelection.collapsed(
            offset: nv.selection.start - 1 + spaces.length),
      );
    }

    return nv;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  LSP HOVER TOOLTIP
// ══════════════════════════════════════════════════════════════════════════════
class _HoverTooltip extends StatelessWidget {
  final LspHover   hover;
  final Offset     position;
  final VoidCallback onDismiss;
  const _HoverTooltip({
    required this.hover,
    required this.position,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    const w = 280.0;
    // Place above the tap point; clamp to screen edges
    double left = position.dx - w / 2;
    double top  = position.dy - 130;
    left = left.clamp(8.0, screen.width  - w - 8);
    top  = top.clamp(8.0, screen.height - 200);

    return Stack(children: [
      // Dismiss barrier
      Positioned.fill(child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDismiss,
        child: const SizedBox.expand(),
      )),
      // Tooltip card
      Positioned(
        left: left, top: top, width: w,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:  T.surface,
              border: Border.all(color: T.border2),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: _renderHoverContent(hover.content),
          ),
        ),
      ),
    ]);
  }

  Widget _renderHoverContent(String content) {
    final lines = content.split('\n\n');
    final widgets = <Widget>[];
    for (final line in lines) {
      if (line.startsWith('**') && line.endsWith('**')) {
        // Bold title (symbol name)
        widgets.add(Text(
          line.replaceAll('**', ''),
          style: TextStyle(
            color: T.accent,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
          ),
        ));
      } else if (line.isNotEmpty) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            line,
            style: TextStyle(color: T.textMid, fontSize: 11.5),
          ),
        ));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }
}
