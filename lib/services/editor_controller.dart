// lib/services/editor_controller.dart
// DevPad Pro v2 — Central state

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../utils/theme.dart';
import '../services/completions.dart';
import '../services/lsp_service.dart';
import '../services/sample_projects.dart';

enum PanelTab { console, preview, git, lsp }
enum AppStatus { idle, running, error }

// Top-level helper so no naming conflicts
List<FindMatch> _computeFind(String code, String q, FindOptions opts) {
  if (q.isEmpty) return [];
  final results = <FindMatch>[];
  try {
    String pattern = opts.useRegex ? q : RegExp.escape(q);
    if (opts.wholeWord) pattern = r'\b' + pattern + r'\b';
    final re = RegExp(pattern, caseSensitive: opts.caseSensitive, multiLine: true);
    for (final m in re.allMatches(code)) {
      results.add(FindMatch(m.start, m.end - m.start));
    }
  } catch (_) {}
  return results;
}

class EditorController extends ChangeNotifier {
  // ── Files ──
  List<CodeFile> files = [];
  String _activeId = '';
  String get activeId => _activeId;
  CodeFile get activeFile {
    if (files.isEmpty) return CodeFile(id: '', name: 'untitled', lang: Language.html, content: '');
    return files.firstWhere((f) => f.id == _activeId, orElse: () => files.first);
  }

  // ── Per-file controllers (keyed by file id) ──
  final Map<String, TextEditingController> _ctrl   = {};
  final Map<String, ScrollController>      _scroll = {};
  final Map<String, FocusNode>             _focus  = {};

  TextEditingController ctrlFor(String id) {
    return _ctrl.putIfAbsent(id, TextEditingController.new);
  }

  ScrollController scrollFor(String id) {
    return _scroll.putIfAbsent(id, ScrollController.new);
  }

  FocusNode focusFor(String id) {
    return _focus.putIfAbsent(id, FocusNode.new);
  }

  TextEditingController get activeCtrl   => ctrlFor(_activeId);
  ScrollController      get activeScroll => scrollFor(_activeId);
  FocusNode             get activeFocus  => focusFor(_activeId);

  // ── UI ──
  bool sidebarOpen       = false;
  bool panelOpen         = false;
  bool panelTall         = false;
  PanelTab panelTab      = PanelTab.console;
  bool findOpen          = false;
  bool previewScreenOpen = false;
  AppStatus status  = AppStatus.idle;
  String statusMsg  = 'Ready';
  double quickKeysHeight = 44.0;

  // ── Split View ──
  // When splitMode is true the screen shows two CodeEditor panels side-by-side.
  // The left panel shows the primary active file; the right panel shows splitFileId.
  bool   splitMode   = false;
  String splitFileId = ''; // id of the file shown in the right panel
  bool   splitSync   = false; // when true, both panels share the same scroll position

  // ── Bracket matching ──
  ({int open, int close, bool matched})? bracketMatch;

  // ── Multi-cursor ──
  List<int> extraCursorOffsets = [];

  // ── Git diff ──
  FileDiff gitDiff = FileDiff.empty;

  // ── LSP ──
  final LspService _lsp = LspService();
  List<LspDiagnostic> lspDiagnostics = [];
  int get lspErrorCount   =>
      lspDiagnostics.where((d) => d.severity == DiagnosticSeverity.error).length;
  int get lspWarningCount =>
      lspDiagnostics.where((d) => d.severity == DiagnosticSeverity.warning).length;
  LspHover? hoverAt(int offset) =>
      _lsp.hover(activeCtrl.text, offset, activeFile.lang);

  // ── Find ──
  List<FindMatch> findResults  = [];
  int             findIdx      = 0;
  FindOptions     findOpts     = FindOptions();
  // Results for "find in all files" — grouped by file
  List<FileMatch> allFileResults = [];

  // ── Autocomplete ──
  bool acVisible = false;
  List<CompletionItem> acItems = [];
  int acIdx = 0;
  String _acWord = '';
  Offset acCursorOffset = Offset.zero;

  // ── Console ──
  List<LogEntry> logs = [];
  int errorCount = 0;

  // ── Outline ──
  List<OutlineItem> outlineItems = [];

  // ── Settings ──
  EditorSettings settings = EditorSettings();

  // ── Preview ──
  String previewHtml = '';

  // ── Toast ──
  String toastMsg = '';
  bool toastVisible = false;
  Timer? _toastTimer;
  Timer? _autorunTimer;
  Timer? _undoTimer;
  Timer? _lspTimer;
  bool _suppressHistory = false;

  // ════════════════════════════════════════════
  //  UI STATE METHODS
  // ════════════════════════════════════════════
  void toggleSidebar()   { sidebarOpen = !sidebarOpen; notifyListeners(); }
  void closeSidebar()    { if (!sidebarOpen) return; sidebarOpen = false; notifyListeners(); }

  void toggleFind()      { findOpen = !findOpen; if (!findOpen) findResults = []; notifyListeners(); }

  // ── Split View ──────────────────────────────────────────────────────────
  void openSplit([String? fileId]) {
    // Default: show the second file in the list (or same file if only one)
    final targetId = fileId ??
        (files.length > 1
            ? files.firstWhere((f) => f.id != _activeId, orElse: () => files.first).id
            : _activeId);
    splitFileId = targetId;
    splitMode   = true;
    notifyListeners();
  }

  void closeSplit() {
    splitMode = false;
    notifyListeners();
  }

  void toggleSplit() => splitMode ? closeSplit() : openSplit();

  void setSplitFile(String id) {
    splitFileId = id;
    notifyListeners();
  }

  void toggleSplitSync() {
    splitSync = !splitSync;
    notifyListeners();
  }

  // Convenience: controller + scroll + focus for the split panel
  TextEditingController get splitCtrl   => ctrlFor(splitFileId);
  ScrollController      get splitScroll => scrollFor(splitFileId);
  FocusNode             get splitFocus  => focusFor(splitFileId);
  CodeFile get splitFile =>
      files.firstWhere((f) => f.id == splitFileId, orElse: () => activeFile);
  void closeFind()       { if (!findOpen) return; findOpen = false; findResults = []; notifyListeners(); }

  void togglePanel()     { panelOpen = !panelOpen; notifyListeners(); }
  void closePanel()      { if (!panelOpen) return; panelOpen = false; notifyListeners(); }
  void togglePanelTall() { panelTall = !panelTall; notifyListeners(); }

  void switchPanelTab(PanelTab tab) {
    if (panelTab == tab) return;
    panelTab = tab;
    notifyListeners();
  }

  void openPreviewScreen({ PanelTab tab = PanelTab.preview }) {
    panelTab          = tab;
    previewScreenOpen = true;
    notifyListeners();
  }

  void closePreviewScreen() {
    previewScreenOpen = false;
    notifyListeners();
  }

  // ═══════════════════════════════════════════
  //  INIT
  // ════════════════════════════════════════════
  Future<void> init() async {
    await _loadSettings();
    final restored = await _loadProject();
    if (!restored) _createDefaultProject();
    _initFileTree();
    _updateOutline();
    notifyListeners();
  }

  void _createDefaultProject() {
    files = [
      _makeFile('index.html', Language.html, _defaultHtml),
      _makeFile('style.css',  Language.css,  _defaultCss),
      _makeFile('app.js',     Language.js,   _defaultJs),
    ];
    _activeId = files.isNotEmpty ? files.first.id : '';
    for (final f in files) _attachControllers(f);
  }

  CodeFile _makeFile(String name, Language lang, String content) {
    final id = '${lang.name}_${DateTime.now().microsecondsSinceEpoch}';
    return CodeFile(id: id, name: name, lang: lang, content: content);
  }

  void _attachControllers(CodeFile f) {
    _ctrl[f.id]   = TextEditingController(text: f.content);
    _scroll[f.id] = ScrollController();
    _focus[f.id]  = FocusNode();
    _ctrl[f.id]!.addListener(() => _onTextChanged(f.id));
  }

  void _detachControllers(String id) {
    _ctrl[id]?.dispose();
    _scroll[id]?.dispose();
    _focus[id]?.dispose();
    _ctrl.remove(id);
    _scroll.remove(id);
    _focus.remove(id);
  }

  // ════════════════════════════════════════════
  //  TEXT CHANGED
  // ════════════════════════════════════════════
  void _onTextChanged(String id) {
    if (id != _activeId) return;
    if (_suppressHistory) return;
    final fileIdx = files.indexWhere((f) => f.id == id);
    if (fileIdx < 0) return;
    final file       = files[fileIdx];
    final newContent = _ctrl[id]!.text;
    if (newContent == file.content) return;

    final oldContent   = file.content;
    final cursorBefore = file.cursorOffset;
    final cursorAfter  = _ctrl[id]?.selection.baseOffset ?? newContent.length;

    file.recordDiff(oldContent, newContent, cursorBefore, cursorAfter);

    file.content       = newContent;
    file.cursorOffset  = cursorAfter;
    file.dirty         = newContent != file.lastSaved;
    file.modified      = DateTime.now();
    _updateOutline();
    _recomputeFolding();
    _computeGitDiff();
    // Run LSP diagnostics with a short debounce so we don't analyse on
    // every single keystroke — wait 600ms after the user stops typing.
    _lspTimer?.cancel();
    _lspTimer = Timer(const Duration(milliseconds: 600), () {
      _runLsp();
      notifyListeners();
    });
    _scheduleAutoSave();
    _updateBracketMatch(newContent, cursorAfter);

    final sel = _ctrl[id]!.selection;
    if (sel.isValid && sel.isCollapsed) {
      _triggerAC(newContent, sel.start);
    }

    if (settings.autorun) {
      _autorunTimer?.cancel();
      _autorunTimer = Timer(
        Duration(milliseconds: settings.autorunDelay), runCode);
    }

    notifyListeners();
  }

  // ════════════════════════════════════════════
  //  MULTI-CURSOR
  // ════════════════════════════════════════════

  bool get hasExtraCursors => extraCursorOffsets.isNotEmpty;

  /// Add an extra cursor at [offset]. Deduplicates and keeps sorted desc.
  void addExtraCursor(int offset) {
    final primary = activeCtrl.selection.baseOffset;
    if (offset == primary) return;        // don't duplicate the primary
    if (extraCursorOffsets.contains(offset)) {
      // Tapping an existing extra cursor removes it
      extraCursorOffsets.remove(offset);
    } else {
      extraCursorOffsets.add(offset);
    }
    // Sort descending so replication applies from end→start (no offset drift)
    extraCursorOffsets.sort((a, b) => b.compareTo(a));
    notifyListeners();
  }

  /// Clear all extra cursors (e.g. single tap, Escape).
  void clearExtraCursors() {
    if (extraCursorOffsets.isEmpty) return;
    extraCursorOffsets.clear();
    notifyListeners();
  }

  /// Called by _SmartIndentFormatter after each edit.
  /// Replicates the same insert/delete delta to all extra cursor positions.
  void replicateDelta(TextEditingValue oldVal, TextEditingValue newVal) {
    if (extraCursorOffsets.isEmpty) return;

    // Find the common prefix (start of change)
    int pfx = 0;
    while (pfx < oldVal.text.length &&
           pfx < newVal.text.length &&
           oldVal.text[pfx] == newVal.text[pfx]) {
      pfx++;
    }
    // Find the common suffix (end of change)
    int oSfx = oldVal.text.length, nSfx = newVal.text.length;
    while (oSfx > pfx && nSfx > pfx &&
           oldVal.text[oSfx - 1] == newVal.text[nSfx - 1]) {
      oSfx--;
      nSfx--;
    }

    final deleted  = oSfx - pfx;    // chars removed
    final inserted = nSfx - pfx;    // chars added

    if (deleted == 0 && inserted == 0) return;

    // Build updated text by applying the same delta at each extra offset.
    // Process from highest offset to lowest to avoid offset drift.
    String text = newVal.text;
    final newExtras = <int>[];

    for (final offset in extraCursorOffsets) {
      // Skip if this extra is inside the region already changed by the main edit
      if (offset >= pfx && offset <= pfx + deleted) {
        newExtras.add(pfx + inserted); // land at end of insertion
        continue;
      }
      // Adjust for the main edit's offset shift
      int adj = offset;
      if (offset > pfx) adj = offset - deleted + inserted;
      adj = adj.clamp(0, text.length);

      if (inserted > 0 && deleted == 0) {
        // Pure insert: insert same chars at extra cursor
        final ins = newVal.text.substring(pfx, pfx + inserted);
        if (adj <= text.length) {
          text = text.substring(0, adj) + ins + text.substring(adj);
          newExtras.add(adj + inserted);
        } else {
          newExtras.add(adj);
        }
      } else if (deleted > 0 && inserted == 0) {
        // Pure delete: delete same number of chars before extra cursor
        final delStart = (adj - deleted).clamp(0, text.length);
        final delEnd   = adj.clamp(0, text.length);
        if (delEnd > delStart) {
          text = text.substring(0, delStart) + text.substring(delEnd);
          newExtras.add(delStart);
        } else {
          newExtras.add(adj);
        }
      } else {
        // Replace: delete then insert
        final delStart = adj.clamp(0, text.length);
        final delEnd   = (adj + deleted).clamp(0, text.length);
        final ins      = newVal.text.substring(pfx, pfx + inserted);
        text = text.substring(0, delStart) + ins + text.substring(delEnd);
        newExtras.add(delStart + inserted);
      }
    }

    // Apply the combined text update without recording a new undo op
    _suppressHistory = true;
    try {
      final primary = newVal.selection.baseOffset.clamp(0, text.length);
      activeCtrl.value = TextEditingValue(
        text:      text,
        selection: TextSelection.collapsed(offset: primary),
      );
      activeFile.content      = text;
      activeFile.cursorOffset = primary;
    } finally {
      _suppressHistory = false;
    }

    extraCursorOffsets = newExtras..sort((a, b) => b.compareTo(a));
    notifyListeners();
  }

  FoldingManager get folding => activeFile.folding;

  void toggleFold(int displayLine) {
    final origLine = _displayToOriginalLine(displayLine);
    activeFile.folding.toggle(origLine);
    notifyListeners();
  }

  void unfoldAll() {
    activeFile.folding.unfoldAll();
    notifyListeners();
  }

  void _recomputeFolding() {
    activeFile.folding.recompute(activeCtrl.text);
  }

  /// Compute diff between saved and current content and store in [gitDiff].
  void _computeGitDiff() {
    gitDiff = DiffEngine.diff(activeFile.lastSaved, activeCtrl.text);
  }

  /// Run static analysis and update [lspDiagnostics].
  void _runLsp() {
    lspDiagnostics = _lsp.diagnose(
        activeFile.id, activeCtrl.text, activeFile.lang);
  }

  int _displayToOriginalLine(int displayLine) {
    final lines = activeCtrl.text.split('\n');
    final d     = activeFile.folding.buildDisplay(lines);
    final idx   = (displayLine - 1).clamp(0, d.origIndex.length - 1);
    return d.origIndex[idx] + 1;
  }

  /// Called by CodeEditor whenever the cursor moves without a text change
  /// (e.g. tap to reposition cursor, arrow keys).
  void updateBracketMatchAt(int cursor) {
    _updateBracketMatch(activeCtrl.text, cursor);
    notifyListeners();
  }
  static const _opens  = {'(', '[', '{'};
  static const _closes = {')', ']', '}'};
  static const _pairs  = {'(': ')', '[': ']', '{': '}'};
  static const _rpairs = {')': '(', ']': '[', '}': '{'};

  /// Finds the matching bracket for the character at or before [cursor].
  /// Sets [bracketMatch] — called after every text/cursor change.
  void _updateBracketMatch(String text, int cursor) {
    if (text.isEmpty) { bracketMatch = null; return; }

    // Check the character immediately before cursor (most common) then after.
    final candidates = <int>[];
    if (cursor > 0)           candidates.add(cursor - 1);
    if (cursor < text.length) candidates.add(cursor);

    for (final pos in candidates) {
      final ch = text[pos];
      if (_opens.contains(ch)) {
        final match = _findClose(text, pos, ch, _pairs[ch]!);
        bracketMatch = (open: pos, close: match ?? pos, matched: match != null);
        return;
      }
      if (_closes.contains(ch)) {
        final open  = _rpairs[ch]!;
        final match = _findOpen(text, pos, ch, open);
        bracketMatch = (open: match ?? pos, close: pos, matched: match != null);
        return;
      }
    }
    bracketMatch = null;
  }

  /// Scan forward from [startPos+1] to find the matching close bracket.
  int? _findClose(String text, int startPos, String open, String close) {
    int depth = 1;
    bool inStr = false;
    String strChar = '';
    for (int i = startPos + 1; i < text.length; i++) {
      final c = text[i];
      // Skip string literals to avoid false matches inside strings
      if (!inStr && (c == '"' || c == "'" || c == '`')) {
        inStr = true; strChar = c; continue;
      }
      if (inStr) { if (c == strChar && (i == 0 || text[i-1] != '\\')) inStr = false; continue; }
      if (c == open)  { depth++; continue; }
      if (c == close) { depth--; if (depth == 0) return i; }
    }
    return null;
  }

  /// Scan backward from [startPos-1] to find the matching open bracket.
  int? _findOpen(String text, int startPos, String close, String open) {
    int depth = 1;
    for (int i = startPos - 1; i >= 0; i--) {
      final c = text[i];
      if (c == close) { depth++; continue; }
      if (c == open)  { depth--; if (depth == 0) return i; }
    }
    return null;
  }

  // ════════════════════════════════════════════
  //  SWITCH FILE
  // ════════════════════════════════════════════
  void switchFile(String id) {
    if (!files.any((f) => f.id == id)) return;
    final oldSel = activeCtrl.selection;
    if (oldSel.isValid) activeFile.cursorOffset = oldSel.baseOffset;

    _activeId          = id;
    acVisible          = false;
    findResults        = [];
    allFileResults     = [];
    extraCursorOffsets = [];
    if (sidebarOpen) sidebarOpen = false;
    _updateOutline();
    _computeGitDiff(); // compute diff for newly switched file
    notifyListeners();

    Future.microtask(() {
      final f   = activeFile;
      final c   = activeCtrl;
      final off = f.cursorOffset.clamp(0, c.text.length);
      c.selection = TextSelection.collapsed(offset: off);
      activeFocus.requestFocus();
    });
  }

  // ════════════════════════════════════════════
  //  ADD / REMOVE FILE
  // ════════════════════════════════════════════
  // ═══════════════════════════════════════════
  //  FILE TREE
  // ═══════════════════════════════════════════

  // Root node of the file tree.  Children of _root ARE the top-level items.
  TreeNode _root = TreeNode(
    id: '__root__', name: 'root', type: TreeNodeType.folder);

  /// The root's children — what the sidebar renders.
  List<TreeNode> get treeNodes => _root.children;

  /// Build initial tree from the existing files list.
  void _initFileTree() {
    _root = TreeNode(id: '__root__', name: 'root', type: TreeNodeType.folder);
    for (final f in files) {
      _root.children.add(TreeNode(
        id:       'node_${f.id}',
        name:     f.name,
        type:     TreeNodeType.file,
        fileId:   f.id,
        parentId: '__root__',
      ));
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Create a new file and add it to the tree under [parentNodeId].
  void createFileInTree(String name, {String? parentNodeId}) {
    final lang = languageFromExtension(name.split('.').last);
    final f    = _makeFile(name, lang, '');
    files.add(f);
    _attachControllers(f);

    final node = TreeNode(
      id:       'node_${f.id}',
      name:     name,
      type:     TreeNodeType.file,
      fileId:   f.id,
      parentId: parentNodeId ?? '__root__',
    );
    if (parentNodeId != null) {
      _root.insertInto(parentNodeId, node);
    } else {
      _root.children.add(node);
    }

    switchFile(f.id);
    showToast('Created: $name');
  }

  /// Create a new folder node (no CodeFile — folders are UI only).
  void createFolder(String name, {String? parentNodeId}) {
    final node = TreeNode(
      id:       'folder_${DateTime.now().millisecondsSinceEpoch}',
      name:     name,
      type:     TreeNodeType.folder,
      parentId: parentNodeId ?? '__root__',
    );
    if (parentNodeId != null) {
      _root.insertInto(parentNodeId, node);
    } else {
      _root.children.add(node);
      _root.children.sort((a, b) {
        if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    }
    notifyListeners();
    showToast('Folder created: $name');
  }

  /// Rename a tree node (and its linked CodeFile if applicable).
  void renameNode(String nodeId, String newName) {
    final node = _root.findById(nodeId);
    if (node == null) return;
    node.name = newName;
    if (node.fileId != null) {
      final f = files.firstWhere((f) => f.id == node.fileId!, orElse: () => files.first);
      if (f.id == node.fileId) {
        f.name = newName;
        f.lang = languageFromExtension(newName.split('.').last);
      }
    }
    notifyListeners();
  }

  /// Delete a tree node. If it's a file node, removes the CodeFile too.
  void deleteNode(String nodeId) {
    final node = _root.findById(nodeId);
    if (node == null) return;

    // Recursively collect all file IDs to delete
    void collectFileIds(TreeNode n, List<String> ids) {
      if (n.fileId != null) ids.add(n.fileId!);
      for (final c in n.children) collectFileIds(c, ids);
    }
    final fileIds = <String>[];
    collectFileIds(node, fileIds);

    // Remove files
    for (final fid in fileIds) {
      files.removeWhere((f) => f.id == fid);
      _detachControllers(fid);
    }

    // Remove from tree
    _root.removeChild(nodeId);

    // If active file was deleted, switch to first remaining
    if (!files.any((f) => f.id == _activeId)) {
      if (files.isNotEmpty) {
        _activeId = files.first.id;
      }
    }
    notifyListeners();
  }

  /// Toggle folder expand/collapse.
  void toggleFolder(String nodeId) {
    final node = _root.findById(nodeId);
    if (node?.isFolder == true) {
      node!.expanded = !node.expanded;
      notifyListeners();
    }
  }

  /// Move [nodeId] to be a child of [newParentId].
  void moveNode(String nodeId, String newParentId) {
    final node = _root.findById(nodeId);
    if (node == null) return;
    _root.removeChild(nodeId);
    _root.insertInto(newParentId, node.clone());
    notifyListeners();
  }

  void addNewFile(String name, Language lang) {
    createFileInTree(name);
  }

  void openExternalFile(String filename, String content) {
    final lang     = languageFromExtension(filename.split('.').last);
    final existing = files.where((f) => f.name == filename).firstOrNull;
    if (existing != null) {
      final cursorBefore = ctrlFor(existing.id).selection.baseOffset;
      existing.recordDiff(existing.content, content, cursorBefore, 0);
      _suppressHistory = true;
      try {
        existing.content = content;
        existing.dirty   = true;
        ctrlFor(existing.id).text = content;
      } finally {
        _suppressHistory = false;
      }
      switchFile(existing.id);
    } else {
      final f = _makeFile(filename, lang, content);
      files.add(f);
      _attachControllers(f);
      switchFile(f.id);
    }
    addLog(LogLevel.info, '✓ Opened: $filename');
    showToast('✓ Opened: $filename');
  }

  void closeFile(String id) {
    if (files.length <= 1) { showToast('Cannot close last file'); return; }
    final idx = files.indexWhere((f) => f.id == id);
    if (idx == -1) return;
    files.removeAt(idx);
    _detachControllers(id);
    _activeId = files[idx < files.length ? idx : idx - 1].id;
    _updateOutline();
    notifyListeners();
  }

  // ════════════════════════════════════════════
  //  LOAD SAMPLE PROJECT
  // ════════════════════════════════════════════
  void loadSampleProject(SampleProject project) {
    for (final f in files) _detachControllers(f.id);
    files.clear();

    final html = _makeFile('index.html', Language.html, project.htmlCode);
    final css  = _makeFile('style.css',  Language.css,  project.cssCode);
    final js   = _makeFile('app.js',     Language.js,   project.jsCode);
    files = [html, css, js];
    for (final f in files) _attachControllers(f);
    _activeId = html.id;
    logs.clear(); errorCount = 0;
    _updateOutline();
    showToast('Loaded: ${project.name}');
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 300), runCode);
    saveProject();
  }

  // ════════════════════════════════════════════
  //  UNDO / REDO
  // ════════════════════════════════════════════
  void undo() {
    _undoTimer?.cancel();
    final f      = activeFile;
    final result = f.history.undo(f.content);
    if (result == null) return;

    final restoredContent = result.content;
    final restoredCursor  = result.cursor.clamp(0, restoredContent.length);

    _suppressHistory = true;
    try {
      f.content      = restoredContent;
      f.cursorOffset = restoredCursor;
      f.dirty        = restoredContent != f.lastSaved;
      activeCtrl.value = TextEditingValue(
        text:      restoredContent,
        selection: TextSelection.collapsed(offset: restoredCursor),
      );
    } finally {
      _suppressHistory = false;
    }
    _updateBracketMatch(restoredContent, restoredCursor);
    _recomputeFolding();
    _updateOutline();
    extraCursorOffsets = []; // extra cursors invalid after undo
    notifyListeners();
  }

  void redo() {
    final f      = activeFile;
    final result = f.history.redo(f.content);
    if (result == null) return;

    final restoredContent = result.content;
    final restoredCursor  = result.cursor.clamp(0, restoredContent.length);

    _suppressHistory = true;
    try {
      f.content      = restoredContent;
      f.cursorOffset = restoredCursor;
      f.dirty        = restoredContent != f.lastSaved;
      activeCtrl.value = TextEditingValue(
        text:      restoredContent,
        selection: TextSelection.collapsed(offset: restoredCursor),
      );
    } finally {
      _suppressHistory = false;
    }
    _updateBracketMatch(restoredContent, restoredCursor);
    _recomputeFolding();
    _updateOutline();
    extraCursorOffsets = []; // extra cursors invalid after redo
    notifyListeners();
  }

  // ════════════════════════════════════════════
  //  TEXT OPERATIONS
  // ════════════════════════════════════════════
  void _applyEdit(String newText, TextSelection sel) {
    final f = activeFile;
    f.recordDiff(
      f.content, newText,
      activeCtrl.selection.baseOffset,
      sel.baseOffset,
    );
    _suppressHistory = true;
    try {
      f.content      = newText;
      f.cursorOffset = sel.baseOffset;
      activeCtrl.value = TextEditingValue(text: newText, selection: sel);
    } finally {
      _suppressHistory = false;
    }
  }

  void insertAtCursor(String text) {
    final ctrl = activeCtrl;
    final sel  = ctrl.selection;
    if (!sel.isValid) { ctrl.text = ctrl.text + text; return; }
    final before = ctrl.text.substring(0, sel.start);
    final after  = ctrl.text.substring(sel.end);
    final newPos = sel.start + text.length;
    _applyEdit(before + text + after, TextSelection.collapsed(offset: newPos));
  }

  void wrapSelection(String open, String close) {
    final ctrl = activeCtrl;
    final sel  = ctrl.selection;
    if (!sel.isValid || sel.isCollapsed) { insertAtCursor(open + close); return; }
    final selected = ctrl.text.substring(sel.start, sel.end);
    final before   = ctrl.text.substring(0, sel.start);
    final after    = ctrl.text.substring(sel.end);
    _applyEdit(
      before + open + selected + close + after,
      TextSelection(
        baseOffset:   sel.start + open.length,
        extentOffset: sel.start + open.length + selected.length,
      ),
    );
  }

  void commentLine() {
    final ctrl  = activeCtrl;
    final text  = ctrl.text;
    final sel   = ctrl.selection;
    if (!sel.isValid) return;
    final lines   = text.split('\n');
    final lineIdx = _lineIndexAt(text, sel.start);
    final line    = lines[lineIdx];
    final cs      = activeFile.lang.commentStart.trim();
    final ce      = activeFile.lang.commentEnd.trim();
    String newLine;
    if (ce.isNotEmpty) {
      newLine = line.trimLeft().startsWith(cs)
          ? line
              .replaceFirst(RegExp('\\s*${RegExp.escape(cs)}\\s?'), '')
              .replaceFirst(RegExp('\\s*${RegExp.escape(ce)}\\s?\$'), '')
          : '$cs$line$ce';
    } else {
      newLine = line.trimLeft().startsWith(cs)
          ? line.replaceFirst(RegExp('\\s*${RegExp.escape(cs)}\\s?'), '')
          : '$cs $line';
    }
    lines[lineIdx] = newLine;
    final newText = lines.join('\n');
    final delta   = newLine.length - line.length;
    _applyEdit(newText, TextSelection.collapsed(
        offset: (sel.start + delta).clamp(0, newText.length)));
  }

  void duplicateLine() {
    final ctrl = activeCtrl;
    final text = ctrl.text;
    final sel  = ctrl.selection;
    if (!sel.isValid) return;
    final ls  = text.lastIndexOf('\n', sel.start - 1) + 1;
    int le    = text.indexOf('\n', sel.start);
    if (le == -1) le = text.length;
    final line = text.substring(ls, le);
    _applyEdit(
      text.substring(0, le) + '\n' + line + text.substring(le),
      TextSelection.collapsed(offset: sel.start + line.length + 1),
    );
  }

  void deleteLine() {
    final ctrl = activeCtrl;
    final text = ctrl.text;
    final sel  = ctrl.selection;
    if (!sel.isValid) return;
    final ls = text.lastIndexOf('\n', sel.start - 1) + 1;
    int le   = text.indexOf('\n', sel.start);
    String nt; int np;
    if (le == -1) {
      nt = ls > 0 ? text.substring(0, ls - 1) : '';
      np = (ls - 1).clamp(0, nt.length);
    } else {
      nt = text.substring(0, ls) + text.substring(le + 1);
      np = ls.clamp(0, nt.length);
    }
    _applyEdit(nt, TextSelection.collapsed(offset: np));
  }

  void moveLine(int dir) {
    final ctrl  = activeCtrl;
    final lines = ctrl.text.split('\n');
    final sel   = ctrl.selection;
    if (!sel.isValid) return;
    final idx    = _lineIndexAt(ctrl.text, sel.start);
    final target = idx + dir;
    if (target < 0 || target >= lines.length) return;
    final tmp     = lines[idx]; lines[idx] = lines[target]; lines[target] = tmp;
    final newText = lines.join('\n');
    int pos = 0;
    for (int i = 0; i < target; i++) pos += lines[i].length + 1;
    _applyEdit(newText, TextSelection.collapsed(offset: pos));
  }

  void indentLine(int dir) {
    final ctrl = activeCtrl;
    final text = ctrl.text;
    final sel  = ctrl.selection;
    if (!sel.isValid) return;
    final tab = settings.useTabs ? '\t' : (' ' * settings.tabSize);
    final ls  = text.lastIndexOf('\n', sel.start - 1) + 1;
    int le    = text.indexOf('\n', sel.start);
    if (le == -1) le = text.length;
    final line    = text.substring(ls, le);
    final newLine = dir > 0
        ? tab + line
        : (line.startsWith(tab)
            ? line.substring(tab.length)
            : line.replaceFirst(RegExp(r'^ +'), ''));
    final delta = newLine.length - line.length;
    _applyEdit(
      text.substring(0, ls) + newLine + text.substring(le),
      TextSelection.collapsed(
          offset: (sel.start + delta).clamp(ls, ls + newLine.length)),
    );
  }

  void formatCode() {
    final ctrl    = activeCtrl;
    final oldText = ctrl.text;
    final tab     = ' ' * settings.tabSize;
    final lang    = activeFile.lang;

    final formatted = lang == Language.html
        ? _formatHtml(oldText, tab)
        : _formatBracket(oldText, tab);

    if (formatted == oldText) { showToast('Already formatted'); return; }

    final f = activeFile;
    f.recordDiff(oldText, formatted, ctrl.selection.baseOffset, 0);
    _suppressHistory = true;
    try {
      ctrl.text = formatted;
      f.content = formatted;
    } finally {
      _suppressHistory = false;
    }
    showToast('✨ Code formatted');
  }

  String _formatBracket(String text, String tab) {
    int indent = 0;
    final lines  = text.split('\n');
    final result = <String>[];
    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) { result.add(''); continue; }
      if (t.startsWith('}') || t.startsWith(']') || t.startsWith(')')) {
        indent = (indent - 1).clamp(0, 99);
      }
      result.add(tab * indent + t);
      final (opens, closes) = _countBrackets(t);
      if (opens > closes) indent++;
    }
    return result.join('\n');
  }

  static (int opens, int closes) _countBrackets(String line) {
    int opens = 0, closes = 0;
    String? inStr;
    bool escaped = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (inStr != null) {
        if (escaped) { escaped = false; continue; }
        if (ch == r'\') { escaped = true; continue; }
        if (ch == inStr) inStr = null;
        continue;
      }
      if (ch == '/' && i + 1 < line.length && line[i + 1] == '/') break;
      if (ch == '"' || ch == "'" || ch == '`') { inStr = ch; continue; }
      if (ch == '{' || ch == '(' || ch == '[') opens++;
      if (ch == '}' || ch == ')' || ch == ']') closes++;
    }
    return (opens, closes);
  }

  static const _htmlVoidTags = {
    'area','base','br','col','embed','hr','img','input',
    'link','meta','param','source','track','wbr',
  };
  static const _htmlInlineTags = {
    'a','abbr','acronym','b','bdo','big','br','button','cite',
    'code','dfn','em','i','img','input','kbd','label','map',
    'object','output','q','samp','select','small','span',
    'strong','sub','sup','textarea','time','tt','var',
  };

  static final _reOpenTag  = RegExp(r'^<([a-zA-Z][a-zA-Z0-9\-]*)[\s>\/]');
  static final _reCloseTag = RegExp(r'^<\/([a-zA-Z][a-zA-Z0-9\-]*)');

  static final _reHtmlToken = RegExp(
    r'<!--[\s\S]*?-->'
    r'|<!DOCTYPE[^>]*>'
    r'|<[^>]+>'
    r'|[^<]+',
    caseSensitive: false,
  );

  String _formatHtml(String text, String tab) {
    final raw    = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final tokens = _reHtmlToken.allMatches(raw).map((m) => m.group(0)!).toList();

    int indent = 0;
    final result = <String>[];
    const rawTags = {'script', 'style', 'pre', 'textarea'};
    String? inRawTag;

    for (final token in tokens) {
      final trimmed = token.trim();
      if (trimmed.isEmpty) continue;

      if (inRawTag != null) {
        final closeM = _reCloseTag.firstMatch(trimmed);
        if (closeM != null && closeM.group(1)!.toLowerCase() == inRawTag) {
          inRawTag = null;
          indent   = (indent - 1).clamp(0, 99);
          result.add(tab * indent + trimmed);
        } else {
          result.add(trimmed.isNotEmpty ? tab * indent + trimmed : '');
        }
        continue;
      }

      if (trimmed.startsWith('<!--') || trimmed.startsWith('<!')) {
        result.add(tab * indent + trimmed);
        continue;
      }

      final closeM = _reCloseTag.firstMatch(trimmed);
      if (closeM != null) {
        final tag = closeM.group(1)!.toLowerCase();
        if (!_htmlInlineTags.contains(tag)) {
          indent = (indent - 1).clamp(0, 99);
        }
        result.add(tab * indent + trimmed);
        continue;
      }

      final openM = _reOpenTag.firstMatch(trimmed);
      if (openM != null) {
        final tag      = openM.group(1)!.toLowerCase();
        final isVoid   = _htmlVoidTags.contains(tag);
        final isInline = _htmlInlineTags.contains(tag);
        final selfClose= trimmed.endsWith('/>');
        final hasClose = trimmed.contains('</$tag>') || trimmed.contains('</$tag ');
        result.add(tab * indent + trimmed);
        if (!isVoid && !selfClose && !hasClose && !isInline) {
          if (rawTags.contains(tag)) {
            inRawTag = tag;
          }
          indent++;
        }
        continue;
      }

      final lines = trimmed.split('\n');
      for (final ln in lines) {
        final l = ln.trim();
        if (l.isNotEmpty) result.add(tab * indent + l);
      }
    }
    return result.join('\n');
  }

  int _lineIndexAt(String text, int offset) {
    int count = 0, charCount = 0;
    for (final line in text.split('\n')) {
      if (charCount + line.length >= offset) return count;
      charCount += line.length + 1;
      count++;
    }
    return count;
  }

  // ════════════════════════════════════════════
  //  SAVE
  // ════════════════════════════════════════════
  void saveCurrentFile({bool copyToClipboard = false}) {
    final f = activeFile;
    f.markSaved();
    gitDiff = FileDiff.empty; // no changes vs saved after save
    if (copyToClipboard) {
      Clipboard.setData(ClipboardData(text: f.content));
      showToast('💾 ${f.name} saved & copied to clipboard');
    } else {
      showToast('💾 ${f.name} saved');
    }
    notifyListeners();
  }

  // ════════════════════════════════════════════
  //  EXPORT
  // ════════════════════════════════════════════
  Future<void> exportCurrentFile() async {
    final f = activeFile;
    try {
      Directory dir;
      if (Platform.isAndroid) {
        final ext = await getExternalStorageDirectory();
        if (ext != null) {
          final root = ext.parent.parent.parent.parent;
          dir = Directory(p.join(root.path, 'Download'));
          if (!await dir.exists()) dir = ext;
        } else {
          dir = await getApplicationDocumentsDirectory();
        }
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      String fileName = f.name;
      File target     = File(p.join(dir.path, fileName));
      int counter     = 1;
      while (await target.exists()) {
        final ext  = p.extension(f.name);
        final base = p.basenameWithoutExtension(f.name);
        fileName   = '$base($counter)$ext';
        target     = File(p.join(dir.path, fileName));
        counter++;
      }

      await target.writeAsString(f.content, flush: true);
      showToast('📁 Exported: $fileName');
    } catch (e) {
      showToast('❌ Export failed: $e');
    }
  }

  // ════════════════════════════════════════════
  //  RUN CODE
  // ════════════════════════════════════════════
  void runCode() {
    if (files.isEmpty) { showToast('No files to run'); return; }
    errorCount = 0;

    final htmlFile = files.firstWhere(
        (f) => f.lang == Language.html,
        orElse: () => activeFile);
    final cssFile  = files.firstWhere(
        (f) => f.lang == Language.css,
        orElse: () => htmlFile);
    final jsFile   = files.firstWhere(
        (f) => f.lang == Language.js,
        orElse: () => htmlFile);

    final html = htmlFile.content;
    final css  = cssFile.lang  == Language.css ? cssFile.content  : '';
    final js   = jsFile.lang   == Language.js  ? jsFile.content   : '';

    final bodyM = RegExp(r'<body[^>]*>([\s\S]*?)<\/body>', caseSensitive: false).firstMatch(html);
    final body  = bodyM?.group(1) ?? html;
    final headM = RegExp(r'<head[^>]*>([\s\S]*?)<\/head>', caseSensitive: false).firstMatch(html);
    String head = headM?.group(1) ?? '';
    head = head
        .replaceAll(RegExp(r'<script[\s\S]*?<\/script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<link[^>]*>', caseSensitive: false), '');

    previewHtml = '''<!DOCTYPE html>
<html><head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
$head
<style>*{box-sizing:border-box;}$css</style>
</head><body>$body
<script>
(function(){
  const _l=console.log,_w=console.warn,_e=console.error,_i=console.info;
  const ts=()=>new Date().toLocaleTimeString('en',{hour12:false,hour:'2-digit',minute:'2-digit',second:'2-digit'});
  function send(lvl,args){
    const msg=Array.from(args).map(x=>{
      if(x===null)return'null';if(x===undefined)return'undefined';
      if(typeof x==='object'){try{return JSON.stringify(x,null,2);}catch(ex){return String(x);}}
      return String(x);}).join(' ');
    try{if(window.DevPadCh)window.DevPadCh.postMessage(JSON.stringify({level:lvl,msg,time:ts()}));}catch(_){}
  }
  console.log  =function(){send('log',  arguments);_l.apply(console,arguments);};
  console.warn =function(){send('warn', arguments);_w.apply(console,arguments);};
  console.error=function(){send('error',arguments);_e.apply(console,arguments);};
  console.info =function(){send('info', arguments);_i.apply(console,arguments);};
  window.addEventListener('error',ev=>{send('error',[ev.message+' (line '+ev.lineno+')']);});
  window.addEventListener('unhandledrejection',ev=>{send('error',['Promise: '+(ev.reason?.message||ev.reason)]);});
})();
$js
</script></body></html>''';

    previewScreenOpen = true;
    panelTab          = PanelTab.preview;
    status            = AppStatus.running;
    statusMsg         = 'Running...';
    // FIX: Only add a "success" log entry here, NOT in addLog which would
    // re-trigger previewScreenOpen and create a navigation loop.
    final n = DateTime.now();
    final t = '${n.hour.toString().padLeft(2,'0')}:${n.minute.toString().padLeft(2,'0')}:${n.second.toString().padLeft(2,'0')}';
    logs.add(LogEntry(level: LogLevel.info, message: '▶ Executed successfully', time: t));
    notifyListeners();
    Future.delayed(const Duration(seconds: 2), () {
      status    = AppStatus.idle;
      statusMsg = 'Ready';
      notifyListeners();
    });
  }

  // ════════════════════════════════════════════
  //  CONSOLE
  // ════════════════════════════════════════════
  void addLog(LogLevel level, String msg) {
    final n = DateTime.now();
    final t = '${n.hour.toString().padLeft(2,'0')}:${n.minute.toString().padLeft(2,'0')}:${n.second.toString().padLeft(2,'0')}';
    logs.add(LogEntry(level: level, message: msg, time: t));
    if (level == LogLevel.error) {
      errorCount++;
      status    = AppStatus.error;
      statusMsg = '$errorCount error${errorCount > 1 ? 's' : ''}';
    }
    // FIX: Do NOT auto-open previewScreen here — that causes the preview screen
    // to push itself every time a console.log fires from within PreviewScreen,
    // creating an infinite navigation loop. The screen is already open when
    // messages arrive.
    notifyListeners();
  }

  void handleWebViewMessage(String json) {
    try {
      final d   = jsonDecode(json) as Map<String, dynamic>;
      final lvl = {
        'log':   LogLevel.log,
        'info':  LogLevel.info,
        'warn':  LogLevel.warn,
        'error': LogLevel.error,
      }[d['level']] ?? LogLevel.log;
      addLog(lvl, d['msg'] as String? ?? '');
    } catch (_) {}
  }

  void clearConsole() {
    logs.clear(); errorCount = 0;
    status = AppStatus.idle; statusMsg = 'Ready';
    notifyListeners();
  }

  // ════════════════════════════════════════════
  //  FIND & REPLACE
  // ════════════════════════════════════════════
  void doFind(String query) {
    findResults    = _computeFind(activeFile.content, query, findOpts);
    allFileResults = []; // clear cross-file results when searching in-file
    findIdx = 0;
    if (findResults.isNotEmpty) _selectMatch();
    notifyListeners();
  }

  /// Search [query] across ALL open files.
  /// Results are stored in [allFileResults] and grouped by file.
  void doFindInAllFiles(String query) {
    if (query.isEmpty) {
      allFileResults = [];
      notifyListeners();
      return;
    }

    final hits = <FileMatch>[];
    for (final file in files) {
      final content = ctrlFor(file.id).text;
      final matches = _computeFind(content, query, findOpts);
      final lines   = content.split('\n');

      for (final m in matches) {
        // Find which line this match is on
        int charCount = 0;
        for (int li = 0; li < lines.length; li++) {
          final lineLen = lines[li].length + 1; // +1 for \n
          if (m.start < charCount + lineLen) {
            hits.add(FileMatch(
              fileId:      file.id,
              fileName:    file.name,
              lineNumber:  li + 1,
              lineText:    lines[li],
              matchStart:  m.start - charCount,
              matchLength: m.length,
            ));
            break;
          }
          charCount += lineLen;
        }
      }
    }

    allFileResults = hits;
    findResults    = []; // clear in-file results
    notifyListeners();
  }

  /// Jump to a specific [FileMatch] result — switches file and selects the match.
  void jumpToFileMatch(FileMatch match) {
    // Switch to the file containing the match
    if (match.fileId != _activeId) switchFile(match.fileId);

    // Compute absolute offset from line number + column
    final content = activeCtrl.text;
    final lines   = content.split('\n');
    int offset    = 0;
    for (int i = 0; i < match.lineNumber - 1 && i < lines.length; i++) {
      offset += lines[i].length + 1;
    }
    offset += match.matchStart;
    offset  = offset.clamp(0, content.length);

    activeCtrl.selection = TextSelection(
      baseOffset:   offset,
      extentOffset: (offset + match.matchLength).clamp(0, content.length),
    );
    activeFocus.requestFocus();
    notifyListeners();
  }

  /// Replace all occurrences in ALL open files simultaneously.
  /// Records a CompoundOp per file for correct per-file undo.
  void replaceAllInAllFiles(String query, String rep) {
    if (query.isEmpty) return;
    int totalCount = 0;
    try {
      final pattern = findOpts.useRegex ? query : RegExp.escape(query);
      final re = RegExp(pattern,
          caseSensitive: findOpts.caseSensitive, multiLine: true);

      for (final file in files) {
        final ctrl    = ctrlFor(file.id);
        final oldText = ctrl.text;
        int count     = 0;
        final newText = oldText.replaceAllMapped(re, (_) { count++; return rep; });
        if (count == 0) continue;

        file.recordDiff(oldText, newText, ctrl.selection.baseOffset, 0);
        _suppressHistory = true;
        try {
          ctrl.text    = newText;
          file.content = newText;
        } finally {
          _suppressHistory = false;
        }
        totalCount += count;
      }
    } catch (_) { return; }

    allFileResults = [];
    showToast('✓ Replaced $totalCount matches across ${files.length} files');
    notifyListeners();
  }

  void findNext() {
    if (findResults.isEmpty) return;
    findIdx = (findIdx + 1) % findResults.length;
    _selectMatch(); notifyListeners();
  }

  void findPrev() {
    if (findResults.isEmpty) return;
    findIdx = (findIdx - 1 + findResults.length) % findResults.length;
    _selectMatch(); notifyListeners();
  }

  void _selectMatch() {
    final m = findResults[findIdx];
    activeCtrl.selection = TextSelection(
        baseOffset: m.start, extentOffset: m.start + m.length);
  }

  void doReplace(String query, String rep) {
    if (findResults.isEmpty) return;
    final m       = findResults[findIdx];
    final oldText = activeCtrl.text;
    final newText = oldText.substring(0, m.start) + rep + oldText.substring(m.start + m.length);
    final f = activeFile;
    f.recordDiff(oldText, newText, activeCtrl.selection.baseOffset, m.start + rep.length);
    _suppressHistory = true;
    try {
      activeCtrl.text = newText;
      f.content = newText;
    } finally {
      _suppressHistory = false;
    }
    doFind(query);
    showToast('Replaced 1 match');
  }

  void doReplaceAll(String query, String rep) {
    if (query.isEmpty) return;
    int count = 0;
    try {
      final pattern = findOpts.useRegex ? query : RegExp.escape(query);
      final re      = RegExp(pattern, caseSensitive: findOpts.caseSensitive, multiLine: true);
      final oldText = activeCtrl.text;
      final newText = oldText.replaceAllMapped(re, (_) { count++; return rep; });
      if (count == 0) return;
      final f = activeFile;
      f.recordDiff(oldText, newText, activeCtrl.selection.baseOffset, 0);
      _suppressHistory = true;
      try {
        activeCtrl.text = newText;
        f.content = newText;
      } finally {
        _suppressHistory = false;
      }
    } catch (_) { return; }
    findResults = [];
    showToast('✓ Replaced $count matches');
    notifyListeners();
  }

  // ════════════════════════════════════════════
  //  OUTLINE
  // ════════════════════════════════════════════
  void _updateOutline() {
    final f = activeFile;
    outlineItems = _extractOutline(f.lang, f.content);
  }

  List<OutlineItem> _extractOutline(Language lang, String code) {
    final items = <OutlineItem>[];
    final lines = code.split('\n');

    switch (lang) {
      case Language.html:
        final re = RegExp(r'<(h[1-6]|section|article|nav|header|footer|main|div)', caseSensitive: false);
        for (int i = 0; i < lines.length; i++) {
          final m = re.firstMatch(lines[i]);
          if (m != null) items.add(OutlineItem(label: '<${m.group(1)!.toLowerCase()}>', kind: 'tag', line: i+1, color: const Color(0xFFF87171)));
        }
        break;
      case Language.js:
      case Language.ts:
        final patterns = [
          (RegExp(r'(?:export\s+)?(?:default\s+)?(?:async\s+)?function\s+([\w\$]+)'), 'fn',  const Color(0xFF93C5FD)),
          (RegExp(r'const\s+([\w\$]+)\s*=\s*(?:async\s*)?\(?[^)]*\)?\s*=>'),          'fn',  const Color(0xFF93C5FD)),
          (RegExp(r'(?:class|interface)\s+([\w\$]+)'),                                  'cls', const Color(0xFFFDE68A)),
        ];
        for (int i = 0; i < lines.length; i++) {
          for (final pat in patterns) {
            final m = pat.$1.firstMatch(lines[i]);
            if (m != null && m.groupCount >= 1) {
              final name = m.group(1) ?? '';
              if (name.isNotEmpty) {
                items.add(OutlineItem(
                  label: pat.$2 == 'fn' ? '$name()' : name,
                  kind: pat.$2, line: i + 1, color: pat.$3));
                break;
              }
            }
          }
        }
        items.sort((a, b) => a.line.compareTo(b.line));
        break;
      case Language.css:
        final re = RegExp(r'^([.#@]?[\w\-:, >+~\[\]=*]+?)\s*\{');
        for (int i = 0; i < lines.length; i++) {
          final m = re.firstMatch(lines[i]);
          if (m != null) items.add(OutlineItem(label: m.group(1)!.trim(), kind: 'sel', line: i+1, color: const Color(0xFF86EFAC)));
        }
        break;
      default: break;
    }
    return items.take(30).toList();
  }

  void goToLine(int line) {
    final ctrl  = activeCtrl;
    final lines = ctrl.text.split('\n');
    int pos = 0;
    for (int i = 0; i < line - 1 && i < lines.length; i++) pos += lines[i].length + 1;
    ctrl.selection = TextSelection.collapsed(offset: pos.clamp(0, ctrl.text.length));
    if (sidebarOpen) { sidebarOpen = false; notifyListeners(); }
    activeFocus.requestFocus();
  }

  // ════════════════════════════════════════════
  //  AUTOCOMPLETE
  // ════════════════════════════════════════════
  void _triggerAC(String text, int cursor) {
    if (!settings.autocomplete) { _hideAC(); return; }
    final before    = text.substring(0, cursor);
    final wordMatch = RegExp(r'[\w\-\.\:]*$').firstMatch(before);
    final word      = wordMatch?.group(0) ?? '';
    if (word.isEmpty) { _hideAC(); return; }

    final lineContent = before.substring(before.lastIndexOf('\n') + 1);
    final items = CompletionEngine.getSuggestions(
      lang: activeFile.lang, word: word,
      lineContent: lineContent, maxResults: 10,
    );

    if (items.isEmpty) { _hideAC(); return; }
    _acWord   = word;
    acItems   = items;
    acIdx     = 0;
    acVisible = true;
    notifyListeners();
  }

  void _hideAC() {
    if (!acVisible) return;
    acVisible = false; acItems = []; _acWord = '';
    notifyListeners();
  }

  void hideAC()     => _hideAC();
  void acMoveUp()   { acIdx = (acIdx - 1).clamp(0, acItems.length - 1); notifyListeners(); }
  void acMoveDown() { acIdx = (acIdx + 1).clamp(0, acItems.length - 1); notifyListeners(); }

  void acAccept() {
    if (!acVisible || acItems.isEmpty) return;
    final item   = acItems[acIdx];
    final ctrl   = activeCtrl;
    final sel    = ctrl.selection;
    if (!sel.isValid) return;
    final before  = ctrl.text.substring(0, sel.start);
    final after   = ctrl.text.substring(sel.end);
    final start   = before.length - _acWord.length;
    final newText = before.substring(0, start) + item.insertText + after;
    final newPos  = start + item.insertText.length;
    activeFile.recordDiff(ctrl.text, newText, ctrl.selection.baseOffset, newPos);
    _suppressHistory = true;
    try {
      ctrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newPos),
      );
      activeFile.content      = newText;
      activeFile.cursorOffset = newPos;
    } finally {
      _suppressHistory = false;
    }
    _hideAC();
  }

  // ════════════════════════════════════════════
  //  CLIPBOARD OPS
  // ════════════════════════════════════════════
  Future<void> copySelection() async {
    final sel = activeCtrl.selection;
    if (!sel.isValid || sel.isCollapsed) return;
    await Clipboard.setData(ClipboardData(text: activeCtrl.text.substring(sel.start, sel.end)));
    showToast('Copied');
  }

  Future<void> cutSelection() async {
    final ctrl = activeCtrl;
    final sel  = ctrl.selection;
    if (!sel.isValid || sel.isCollapsed) return;
    final selectedText = ctrl.text.substring(sel.start, sel.end);
    await Clipboard.setData(ClipboardData(text: selectedText));
    // FIX: Delete the selected range properly using _applyEdit, not insertAtCursor('').
    // insertAtCursor('') replaces selection.start..selection.end with '' correctly
    // only if the selection is collapsed; for non-collapsed selections it falls through
    // to appending to end. Use _applyEdit directly:
    _applyEdit(
      ctrl.text.substring(0, sel.start) + ctrl.text.substring(sel.end),
      TextSelection.collapsed(offset: sel.start),
    );
    showToast('Cut');
  }

  Future<void> pasteClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) insertAtCursor(data!.text!);
  }

  void selectAll() {
    final ctrl = activeCtrl;
    ctrl.selection = TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);
  }

  // ════════════════════════════════════════════
  //  PERSISTENCE  (project save / load)
  // ════════════════════════════════════════════
  static const _kProject = 'dp_project_v2';
  Timer? _autoSaveTimer;

  Future<void> saveProject() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode({
        'activeId': _activeId,
        'files': files.map((f) => f.toJson()).toList(),
      });
      await prefs.setString(_kProject, payload);
    } catch (_) {}
  }

  Future<bool> _loadProject() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_kProject);
      if (raw == null) return false;
      final data  = jsonDecode(raw) as Map<String, dynamic>;
      final list  = (data['files'] as List<dynamic>)
          .map((e) => CodeFile.fromJson(e as Map<String, dynamic>))
          .toList();
      if (list.isEmpty) return false;
      files     = list;
      _activeId = (data['activeId'] as String?) ?? list.first.id;
      if (!files.any((f) => f.id == _activeId)) _activeId = files.first.id;
      for (final f in files) _attachControllers(f);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 1500), saveProject);
  }

  // ════════════════════════════════════════════
  //  SETTINGS
  // ════════════════════════════════════════════
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final j = prefs.getString('dp_settings_v2');
      if (j != null) settings = EditorSettings.fromJson(jsonDecode(j) as Map<String, dynamic>);
    } catch (_) {}
    // Apply saved theme immediately so first paint uses correct colours.
    T.useId(settings.themeId);
  }

  Future<void> saveSettings() async {
    T.useId(settings.themeId);
    // Update system UI brightness to match new theme
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor:           Colors.transparent,
      statusBarIconBrightness:  T.current.dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: T.current.bg,
      systemNavigationBarIconBrightness: T.current.dark ? Brightness.light : Brightness.dark,
    ));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dp_settings_v2', jsonEncode(settings.toJson()));
    } catch (_) {}
    notifyListeners();
  }

  // ════════════════════════════════════════════
  //  TOAST
  // ════════════════════════════════════════════
  void showToast(String msg) {
    toastMsg = msg; toastVisible = true; notifyListeners();
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 2400), () {
      toastVisible = false; notifyListeners();
    });
  }

  // ════════════════════════════════════════════
  //  STATS
  // ════════════════════════════════════════════
  (int lines, int chars, int words) get currentStats {
    final c = activeFile.content;
    return (c.split('\n').length, c.length,
        c.trim().isEmpty ? 0 : c.trim().split(RegExp(r'\s+')).length);
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _autorunTimer?.cancel();
    _undoTimer?.cancel();
    _autoSaveTimer?.cancel();
    _lspTimer?.cancel();
    saveProject();
    for (final id in _ctrl.keys.toList()) _detachControllers(id);
    super.dispose();
  }
}

// ════════════════════════════════════════════
//  DEFAULT CONTENT
// ════════════════════════════════════════════
const _defaultHtml = r'''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>DevPad Pro</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <div class="app">
    <header class="header">
      <div class="logo">✦</div>
      <h1>DevPad Pro</h1>
      <p>Your mobile code editor</p>
    </header>

    <div class="cards">
      <div class="card">
        <h2>Counter</h2>
        <div class="counter">
          <button class="btn-dec" onclick="dec()">−</button>
          <span id="count">0</span>
          <button class="btn-inc" onclick="inc()">+</button>
        </div>
        <button class="btn-reset" onclick="reset()">Reset</button>
      </div>

      <div class="card">
        <h2>Color Picker</h2>
        <input type="color" id="colorPick" value="#3b82f6"
               oninput="applyColor(this.value)">
        <div id="colorPreview" class="color-preview"></div>
      </div>
    </div>
  </div>
  <script src="app.js"></script>
</body>
</html>''';

const _defaultCss = r'''*, *::before, *::after {
  margin: 0; padding: 0;
  box-sizing: border-box;
}
body {
  font-family: 'Inter', system-ui, sans-serif;
  background: #080b14;
  color: #e2e8f4;
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
}
.app { width: 100%; max-width: 480px; }
.header { text-align: center; margin-bottom: 32px; }
.logo { font-size: 2.5rem; margin-bottom: 8px; }
h1 {
  font-size: 2rem; font-weight: 800;
  background: linear-gradient(135deg, #3b82f6, #8b5cf6);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
  margin-bottom: 6px;
}
p { color: #4a5568; }
.cards { display: flex; flex-direction: column; gap: 16px; }
.card {
  background: #111827;
  border: 1px solid #1e2a42;
  border-radius: 16px;
  padding: 24px;
  text-align: center;
}
.card h2 {
  font-size: 0.75rem; font-weight: 600;
  color: #4a5568; text-transform: uppercase;
  letter-spacing: .1em; margin-bottom: 20px;
}
.counter {
  display: flex; align-items: center;
  justify-content: center; gap: 24px;
  margin-bottom: 16px;
}
#count {
  font-size: 4rem; font-weight: 300;
  min-width: 100px; transition: color .3s, transform .15s;
}
.btn-inc, .btn-dec {
  width: 48px; height: 48px;
  border-radius: 50%; border: 2px solid #1e2a42;
  background: transparent; color: #94a3b8;
  font-size: 1.5rem; cursor: pointer;
  transition: all .2s;
}
.btn-inc:hover { border-color: #22d3a0; color: #22d3a0; background: rgba(34,211,160,.1); }
.btn-dec:hover { border-color: #f87171; color: #f87171; background: rgba(248,113,113,.1); }
.btn-reset {
  background: transparent; border: 1px solid #1e2a42;
  color: #4a5568; padding: 6px 20px;
  border-radius: 20px; cursor: pointer;
  font-size: 0.8rem; transition: all .2s;
}
.btn-reset:hover { border-color: #3b82f6; color: #3b82f6; }
input[type="color"] {
  width: 64px; height: 64px;
  border: none; border-radius: 50%;
  cursor: pointer; background: none;
  padding: 0; margin-bottom: 16px;
}
.color-preview {
  height: 52px; border-radius: 12px;
  background: #3b82f6; transition: background .3s;
}''';

const _defaultJs = r'''// DevPad Pro — App Script
let count = 0;

function inc() { count++; update(); }
function dec() { count--; update(); }
function reset() { count = 0; update(); }

function update() {
  const el = document.getElementById('count');
  if (!el) return;
  el.textContent = count;
  el.style.color = count > 0 ? '#22d3a0' : count < 0 ? '#f87171' : '#e2e8f4';
  el.style.transform = 'scale(1.15)';
  setTimeout(() => el.style.transform = '', 150);
  console.log('Counter:', count);
}

function applyColor(val) {
  const box = document.getElementById('colorPreview');
  if (box) box.style.background = val;
  console.info('Color:', val);
}

document.addEventListener('DOMContentLoaded', () => {
  applyColor('#3b82f6');
  console.info('✓ DevPad Pro initialized');
});''';
