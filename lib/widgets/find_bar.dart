// lib/widgets/find_bar.dart
import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../services/editor_controller.dart';
import '../models/models.dart';

class FindBar extends StatefulWidget {
  final EditorController ctrl;
  const FindBar({super.key, required this.ctrl});
  @override
  State<FindBar> createState() => _FindBarState();
}

class _FindBarState extends State<FindBar> {
  final _fCtrl  = TextEditingController();
  final _rCtrl  = TextEditingController();
  final _fFocus = FocusNode();
  bool _showReplace = false;
  bool _allFiles    = false; // false = In File, true = In All Files

  EditorController get ctrl => widget.ctrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fFocus.requestFocus());
  }

  @override
  void dispose() {
    _fCtrl.dispose();
    _rCtrl.dispose();
    _fFocus.dispose();
    super.dispose();
  }

  void _runSearch(String query) {
    if (_allFiles) {
      ctrl.doFindInAllFiles(query);
    } else {
      ctrl.doFind(query);
    }
  }

  void _switchScope(bool allFiles) {
    setState(() => _allFiles = allFiles);
    _runSearch(_fCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final inFileCount  = ctrl.findResults.length;
    final inFileIdx    = inFileCount > 0 ? ctrl.findIdx + 1 : 0;
    final allCount     = ctrl.allFileResults.length;

    return Container(
      decoration: BoxDecoration(
        color: T.surface,
        border: Border(bottom: BorderSide(color: T.border2)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ── Tab bar: In File | In All Files ───────────────────────────
        Container(
          height: 32,
          decoration: BoxDecoration(
            color: T.bg2,
            border: Border(bottom: BorderSide(color: T.border)),
          ),
          child: Row(children: [
            _ScopeTab('In File',      !_allFiles, () => _switchScope(false)),
            _ScopeTab('In All Files', _allFiles,  () => _switchScope(true)),
          ]),
        ),

        // ── Search row ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
          child: Row(children: [
            // Expand/collapse replace
            if (!_allFiles)
              GestureDetector(
                onTap: () => setState(() => _showReplace = !_showReplace),
                child: Icon(
                  _showReplace ? Icons.expand_less : Icons.expand_more,
                  size: 16, color: T.textDim,
                ),
              ),
            if (!_allFiles) const SizedBox(width: 6),

            // Search input
            Expanded(
              child: _FrInput(
                ctrl:      _fCtrl,
                focus:     _fFocus,
                hint:      _allFiles ? 'Search all files...' : 'Find...',
                onChanged: _runSearch,
                onSubmit:  (_) => _allFiles ? null : ctrl.findNext(),
              ),
            ),
            const SizedBox(width: 6),

            // Options
            _FrOpt('Aa', ctrl.findOpts.caseSensitive, () {
              ctrl.findOpts.caseSensitive = !ctrl.findOpts.caseSensitive;
              _runSearch(_fCtrl.text);
            }),
            _FrOpt('W', ctrl.findOpts.wholeWord, () {
              ctrl.findOpts.wholeWord = !ctrl.findOpts.wholeWord;
              _runSearch(_fCtrl.text);
            }),
            _FrOpt('.*', ctrl.findOpts.useRegex, () {
              ctrl.findOpts.useRegex = !ctrl.findOpts.useRegex;
              _runSearch(_fCtrl.text);
            }),
            const SizedBox(width: 6),

            // Match count / navigation
            if (!_allFiles) ...[
              SizedBox(
                width: 46,
                child: Text(
                  '$inFileIdx/$inFileCount',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: T.textDim, fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
              _FrBtn(Icons.keyboard_arrow_up,   ctrl.findPrev),
              _FrBtn(Icons.keyboard_arrow_down, ctrl.findNext),
            ] else ...[
              SizedBox(
                width: 52,
                child: Text(
                  '$allCount hits',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: T.textDim, fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
            ],

            _FrBtn(Icons.close, ctrl.closeFind),
          ]),
        ),

        // ── Replace row (in-file only) ────────────────────────────────
        if (!_allFiles && _showReplace)
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 6, 8, 0),
            child: Row(children: [
              Expanded(
                child: _FrInput(
                  ctrl:      _rCtrl,
                  hint:      'Replace...',
                  onChanged: (_) {},
                  onSubmit:  (_) => ctrl.doReplace(_fCtrl.text, _rCtrl.text),
                ),
              ),
              const SizedBox(width: 6),
              _FrBtn(Icons.check, () => ctrl.doReplace(_fCtrl.text, _rCtrl.text)),
              GestureDetector(
                onTap: () => ctrl.doReplaceAll(_fCtrl.text, _rCtrl.text),
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  margin: const EdgeInsets.only(left: 2),
                  decoration: BoxDecoration(
                    color: T.surface3,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: T.border2),
                  ),
                  child: Center(
                    child: Text('All',
                        style: TextStyle(color: T.textMid, fontSize: 10.5)),
                  ),
                ),
              ),
            ]),
          ),

        // ── All-files replace row ─────────────────────────────────────
        if (_allFiles)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Row(children: [
              Expanded(
                child: _FrInput(
                  ctrl:      _rCtrl,
                  hint:      'Replace in all files...',
                  onChanged: (_) {},
                  onSubmit:  (_) =>
                      ctrl.replaceAllInAllFiles(_fCtrl.text, _rCtrl.text),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () =>
                    ctrl.replaceAllInAllFiles(_fCtrl.text, _rCtrl.text),
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  margin: const EdgeInsets.only(left: 2),
                  decoration: BoxDecoration(
                    color: T.accentDim,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: T.accent),
                  ),
                  child: Center(
                    child: Text('Replace All',
                        style: TextStyle(
                            color: T.accent,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ]),
          ),

        // ── All-files results list ────────────────────────────────────
        if (_allFiles && ctrl.allFileResults.isNotEmpty)
          _AllFilesResults(
            results: ctrl.allFileResults,
            onTap:   ctrl.jumpToFileMatch,
            query:   _fCtrl.text,
          ),

        const SizedBox(height: 6),
      ]),
    );
  }
}

// ── All Files Results ─────────────────────────────────────────────────────────
class _AllFilesResults extends StatelessWidget {
  final List<FileMatch> results;
  final void Function(FileMatch) onTap;
  final String query;
  const _AllFilesResults({
    required this.results, required this.onTap, required this.query});

  @override
  Widget build(BuildContext context) {
    // Group by file
    final Map<String, List<FileMatch>> byFile = {};
    for (final r in results) {
      byFile.putIfAbsent(r.fileId, () => []).add(r);
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: T.border)),
      ),
      child: ListView(
        shrinkWrap: true,
        children: byFile.entries.map((entry) {
          final fileMatches = entry.value;
          final fileName    = fileMatches.first.fileName;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // File header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                color: T.bg2,
                child: Row(children: [
                  Icon(Icons.insert_drive_file_outlined, size: 12, color: T.accent),
                  const SizedBox(width: 6),
                  Text(
                    fileName,
                    style: TextStyle(
                      color: T.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${fileMatches.length} match${fileMatches.length == 1 ? '' : 'es'}',
                    style: TextStyle(color: T.textDim, fontSize: 10),
                  ),
                ]),
              ),
              // Match rows
              ...fileMatches.map((m) => GestureDetector(
                onTap: () => onTap(m),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 5, 12, 5),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: T.border, width: 0.3)),
                  ),
                  child: Row(children: [
                    // Line number
                    SizedBox(
                      width: 36,
                      child: Text(
                        '${m.lineNumber}',
                        style: TextStyle(
                          color: T.lineNum,
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    // Line content with match highlighted
                    Expanded(
                      child: _HighlightedLine(
                        line:        m.lineText.trimLeft(),
                        matchStart:  m.matchStart - (m.lineText.length - m.lineText.trimLeft().length),
                        matchLength: m.matchLength,
                      ),
                    ),
                  ]),
                ),
              )),
            ],
          );
        }).toList(),
      ),
    );
  }
}

/// Renders a line of code with the search match highlighted.
class _HighlightedLine extends StatelessWidget {
  final String line;
  final int matchStart, matchLength;
  const _HighlightedLine({
    required this.line,
    required this.matchStart,
    required this.matchLength,
  });

  @override
  Widget build(BuildContext context) {
    final safeStart  = matchStart.clamp(0, line.length);
    final safeEnd    = (matchStart + matchLength).clamp(0, line.length);
    final before     = line.substring(0, safeStart);
    final match      = line.substring(safeStart, safeEnd);
    final after      = line.substring(safeEnd);
    final baseStyle  = TextStyle(
      color: T.textMid, fontSize: 11, fontFamily: 'monospace');

    return Text.rich(
      TextSpan(children: [
        TextSpan(text: before, style: baseStyle),
        TextSpan(
          text: match,
          style: baseStyle.copyWith(
            color: T.text,
            backgroundColor: T.accentDim,
            fontWeight: FontWeight.w700,
          ),
        ),
        TextSpan(text: after, style: baseStyle),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ── Scope tab ─────────────────────────────────────────────────────────────────
class _ScopeTab extends StatelessWidget {
  final String   label;
  final bool     active;
  final VoidCallback onTap;
  const _ScopeTab(this.label, this.active, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: active ? T.accent : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color:      active ? T.accent : T.textDim,
          fontSize:   11,
          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    ),
  );
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────
class _FrInput extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode? focus;
  final String hint;
  final void Function(String) onChanged, onSubmit;
  const _FrInput({
    required this.ctrl,
    this.focus,
    required this.hint,
    required this.onChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext ctx) => Container(
    height: 30,
    decoration: BoxDecoration(
      color: T.bg2,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: T.border2),
    ),
    child: TextField(
      controller:  ctrl,
      focusNode:   focus,
      onChanged:   onChanged,
      onSubmitted: onSubmit,
      autocorrect: false,
      style: TextStyle(color: T.text, fontFamily: 'monospace', fontSize: 12),
      decoration: InputDecoration(
        hintText:        hint,
        hintStyle:       TextStyle(color: T.textDim, fontSize: 12),
        border:          InputBorder.none,
        contentPadding:  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        isDense:         true,
      ),
    ),
  );
}

class _FrBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _FrBtn(this.icon, this.onTap);

  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28, height: 28,
      margin: const EdgeInsets.only(left: 2),
      decoration: BoxDecoration(
        color: T.surface3,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: T.border2),
      ),
      child: Icon(icon, size: 14, color: T.textMid),
    ),
  );
}

class _FrOpt extends StatelessWidget {
  final String label;
  final bool   active;
  final VoidCallback onTap;
  const _FrOpt(this.label, this.active, this.onTap);

  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      margin:  const EdgeInsets.only(left: 2),
      decoration: BoxDecoration(
        color: active ? T.accentDim : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: active ? T.accent : T.border),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: active ? T.accent : T.textDim, fontSize: 10),
      ),
    ),
  );
}
