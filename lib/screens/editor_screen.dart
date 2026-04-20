// lib/screens/editor_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/theme.dart';
import '../services/editor_controller.dart';
import '../services/sample_projects.dart';
import '../widgets/title_bar.dart';
import '../widgets/tabs_row.dart';
import '../widgets/sidebar.dart';
import '../widgets/code_editor.dart';
import '../widgets/quick_keys.dart';
import '../widgets/status_bar.dart';
import '../widgets/find_bar.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/samples_sheet.dart';
import '../widgets/ac_overlay.dart';
import '../widgets/context_menu.dart';
import '../widgets/toast.dart';
import '../models/models.dart';
import 'preview_screen.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});
  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  Offset? _ctxPos;
  bool _navInProgress = false;

  // FIX: Keep a reference to avoid re-registering the listener on every
  // didChangeDependencies call (which fires on every ancestor rebuild).
  EditorController? _ctrl;
  final FocusNode _keyFocus = FocusNode(); // FIX: properly disposed

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ctrl = context.read<EditorController>();
    if (_ctrl != ctrl) {
      _ctrl?.removeListener(_onCtrlChanged);
      _ctrl = ctrl;
      _ctrl!.addListener(_onCtrlChanged);
    }
  }

  @override
  void dispose() {
    _ctrl?.removeListener(_onCtrlChanged);
    _keyFocus.dispose();
    super.dispose();
  }

  void _onCtrlChanged() {
    if (!mounted) return;
    if (_ctrl!.previewScreenOpen && !_navInProgress) {
      _navInProgress = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context)
            .push(MaterialPageRoute(
              builder: (_) => PreviewScreen(ctrl: _ctrl!),
            ))
            .then((_) {
          _navInProgress = false;
          _ctrl!.closePreviewScreen();
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EditorController>(
      builder: (ctx, ctrl, _) => Scaffold(
        backgroundColor: T.bg,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: KeyboardListener(
            focusNode: _keyFocus,
            autofocus: false,
            onKeyEvent: (e) => _handleKey(e, ctrl),
            child: Stack(
              children: [
                Column(
                  children: [
                    TitleBar(
                      ctrl: ctrl,
                      onPickFile: _pickFile,
                      onShowSamples: _showSamples,
                      onShowSettings: _showSettings,
                      onShowPreview: () => _openPreview(ctrl),
                    ),
                    TabsRow(ctrl: ctrl),
                    Expanded(
                      child: Column(
                        children: [
                          if (ctrl.findOpen) FindBar(ctrl: ctrl),
                          Expanded(
                            child: ctrl.splitMode
                                ? _SplitEditorLayout(
                                    ctrl:  ctrl,
                                    onCtx: (pos) =>
                                        setState(() => _ctxPos = pos),
                                  )
                                : CodeEditor(
                                    key: ValueKey(ctrl.activeId),
                                    ctrl: ctrl,
                                    onContextMenu: (pos) =>
                                        setState(() => _ctxPos = pos),
                                  ),
                          ),
                          _QuickKeysWithHeight(ctrl: ctrl),
                        ],
                      ),
                    ),
                    StatusBar(ctrl: ctrl),
                  ],
                ),

                if (ctrl.sidebarOpen)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: ctrl.closeSidebar,
                      child: const SizedBox.expand(),
                    ),
                  ),

                Positioned(
                  top: 0, left: 0, bottom: 0,
                  child: SidebarWidget(ctrl: ctrl),
                ),

                if (ctrl.acVisible && ctrl.acItems.isNotEmpty)
                  AcOverlay(ctrl: ctrl),

                if (_ctxPos != null)
                  ContextMenu(
                    position: _ctxPos!,
                    ctrl: ctrl,
                    onDismiss: () => setState(() => _ctxPos = null),
                  ),

                if (ctrl.toastVisible)
                  Positioned(
                    bottom: 72, left: 0, right: 0,
                    child: ToastWidget(msg: ctrl.toastMsg),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleKey(KeyEvent e, EditorController ctrl) {
    if (e is! KeyDownEvent) return;
    final c = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final s = HardwareKeyboard.instance.isShiftPressed;

    if (c) {
      switch (e.logicalKey) {
        case LogicalKeyboardKey.keyS:         ctrl.saveCurrentFile(); break;
        case LogicalKeyboardKey.keyZ:         s ? ctrl.redo() : ctrl.undo(); break;
        case LogicalKeyboardKey.keyY:         ctrl.redo(); break;
        case LogicalKeyboardKey.keyF:         ctrl.toggleFind(); break;
        case LogicalKeyboardKey.keyB:         ctrl.toggleSidebar(); break;
        case LogicalKeyboardKey.enter:        ctrl.runCode(); break;
        case LogicalKeyboardKey.slash:        ctrl.commentLine(); break;
        case LogicalKeyboardKey.keyD:         ctrl.duplicateLine(); break;
        case LogicalKeyboardKey.arrowUp:      ctrl.moveLine(-1); break;
        case LogicalKeyboardKey.arrowDown:    ctrl.moveLine(1); break;
        case LogicalKeyboardKey.keyC:         ctrl.copySelection(); break;
        case LogicalKeyboardKey.keyX:         ctrl.cutSelection(); break;
        case LogicalKeyboardKey.keyV:         ctrl.pasteClipboard(); break;
        case LogicalKeyboardKey.keyA:         ctrl.selectAll(); break;
        case LogicalKeyboardKey.bracketLeft:  ctrl.indentLine(-1); break;
        case LogicalKeyboardKey.bracketRight: ctrl.indentLine(1); break;
        default: break;
      }
    }

    if (e.logicalKey == LogicalKeyboardKey.escape) {
      if (ctrl.acVisible)   { ctrl.hideAC(); return; }
      if (ctrl.findOpen)    { ctrl.closeFind(); return; }
      if (ctrl.sidebarOpen) { ctrl.closeSidebar(); return; }
      setState(() => _ctxPos = null);
    }

    if (ctrl.acVisible) {
      if (e.logicalKey == LogicalKeyboardKey.arrowDown) { ctrl.acMoveDown(); }
      if (e.logicalKey == LogicalKeyboardKey.arrowUp)   { ctrl.acMoveUp(); }
      if (e.logicalKey == LogicalKeyboardKey.enter ||
          e.logicalKey == LogicalKeyboardKey.tab)        { ctrl.acAccept(); }
    }
  }

  void _openPreview(EditorController ctrl) {
    if (_navInProgress) return;
    _navInProgress = true;
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => PreviewScreen(ctrl: ctrl),
        ))
        .then((_) {
      _navInProgress = false;
      ctrl.closePreviewScreen();
    });
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'html', 'htm', 'css', 'js', 'ts', 'jsx', 'tsx',
          'json', 'md', 'txt',
        ],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      String content = '';
      if (file.bytes != null) {
        content = String.fromCharCodes(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      }
      if (!mounted) return;
      context.read<EditorController>().openExternalFile(file.name, content);
    } catch (e) {
      if (mounted) {
        context.read<EditorController>().showToast('❌ Failed to open file');
      }
    }
  }

  void _showSamples() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SamplesSheet(
        onSelect: (project) {
          Navigator.pop(context);
          context.read<EditorController>().loadSampleProject(project);
        },
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          SettingsSheet(ctrl: context.read<EditorController>()),
    );
  }
}

// Wraps QuickKeys in a LayoutBuilder so we can report its rendered height
// back to the controller. CodeEditor uses this to set the correct bottom
// padding on the TextField, ensuring the cursor is never hidden behind the bar.
class _QuickKeysWithHeight extends StatefulWidget {
  final EditorController ctrl;
  const _QuickKeysWithHeight({required this.ctrl});

  @override
  State<_QuickKeysWithHeight> createState() => _QuickKeysWithHeightState();
}

class _QuickKeysWithHeightState extends State<_QuickKeysWithHeight> {
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportHeight());
  }

  void _reportHeight() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final h = box.size.height;
      if (widget.ctrl.quickKeysHeight != h) {
        widget.ctrl.quickKeysHeight = h;
        // No notifyListeners needed — CodeEditor reads this during its own
        // build which is already triggered by the keyboard inset change.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-measure after layout in case the keyboard changed the inset.
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportHeight());
    return KeyedSubtree(
      key: _key,
      child: QuickKeys(ctrl: widget.ctrl),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SPLIT EDITOR LAYOUT
// ══════════════════════════════════════════════════════════════════════════════
/// Shows two CodeEditor panels side-by-side with a draggable divider.
/// Left panel = primary active file. Right panel = splitFileId.
class _SplitEditorLayout extends StatefulWidget {
  final EditorController ctrl;
  final void Function(Offset) onCtx;
  const _SplitEditorLayout({required this.ctrl, required this.onCtx});
  @override
  State<_SplitEditorLayout> createState() => _SplitEditorLayoutState();
}

class _SplitEditorLayoutState extends State<_SplitEditorLayout> {
  // Split ratio: 0.0 = all left, 1.0 = all right. Default = 50/50.
  double _ratio = 0.5;
  // Track drag
  double? _dragStart;
  double? _ratioAtDragStart;

  EditorController get ctrl => widget.ctrl;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, box) {
      final totalW   = box.maxWidth;
      final dividerW = 4.0;
      final leftW    = ((totalW - dividerW) * _ratio).clamp(80.0, totalW - 80.0 - dividerW);
      final rightW   = totalW - dividerW - leftW;

      return Row(children: [
        // ── Left panel (primary file) ─────────────────────────────────
        SizedBox(
          width: leftW,
          child: Column(children: [
            _PanelHeader(
              ctrl:     ctrl,
              fileId:   ctrl.activeId,
              isPrimary: true,
              onClose:  ctrl.closeSplit,
            ),
            Expanded(
              child: CodeEditor(
                key: ValueKey('left_${ctrl.activeId}'),
                ctrl: ctrl,
                onContextMenu: widget.onCtx,
              ),
            ),
          ]),
        ),

        // ── Draggable divider ─────────────────────────────────────────
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) {
            _dragStart       = d.globalPosition.dx;
            _ratioAtDragStart = _ratio;
          },
          onHorizontalDragUpdate: (d) {
            if (_dragStart == null) return;
            final delta = d.globalPosition.dx - _dragStart!;
            setState(() {
              _ratio = (_ratioAtDragStart! + delta / totalW)
                  .clamp(0.15, 0.85);
            });
          },
          onHorizontalDragEnd: (_) {
            _dragStart        = null;
            _ratioAtDragStart = null;
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: Container(
              width: dividerW,
              color: T.border2,
              child: Center(
                child: Container(
                  width: 2, height: 32,
                  decoration: BoxDecoration(
                    color: T.border3,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Right panel (split file) ──────────────────────────────────
        SizedBox(
          width: rightW,
          child: _SplitRightPanel(
            ctrl:    ctrl,
            rightW:  rightW,
            onCtx:   widget.onCtx,
            onClose: ctrl.closeSplit,
          ),
        ),
      ]);
    });
  }
}

/// Right panel header — allows picking which file to show.
class _SplitRightPanel extends StatelessWidget {
  final EditorController ctrl;
  final double rightW;
  final void Function(Offset) onCtx;
  final VoidCallback onClose;
  const _SplitRightPanel({
    required this.ctrl, required this.rightW,
    required this.onCtx, required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    // Ensure splitFileId is valid; fall back to first available
    final validId = ctrl.files.any((f) => f.id == ctrl.splitFileId)
        ? ctrl.splitFileId
        : ctrl.files.first.id;
    if (validId != ctrl.splitFileId) ctrl.splitFileId = validId;

    return Column(children: [
      _PanelHeader(
        ctrl:      ctrl,
        fileId:    validId,
        isPrimary: false,
        onClose:   onClose,
      ),
      Expanded(
        child: _SplitEditorProxy(
          ctrl:   ctrl,
          fileId: validId,
          onCtx:  onCtx,
        ),
      ),
    ]);
  }
}

/// Panel header with file name + file picker + close button.
class _PanelHeader extends StatelessWidget {
  final EditorController ctrl;
  final String fileId;
  final bool isPrimary;
  final VoidCallback onClose;
  const _PanelHeader({
    required this.ctrl, required this.fileId,
    required this.isPrimary, required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final file  = ctrl.files.firstWhere((f) => f.id == fileId,
        orElse: () => ctrl.activeFile);
    final files = ctrl.files;

    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: T.bg2,
        border: Border(bottom: BorderSide(color: T.border)),
      ),
      child: Row(children: [
        Icon(Icons.insert_drive_file_outlined, size: 12, color: T.textDim),
        const SizedBox(width: 4),
        // File name / picker (right panel only)
        if (!isPrimary)
          Expanded(
            child: PopupMenuButton<String>(
              initialValue: fileId,
              onSelected:   ctrl.setSplitFile,
              itemBuilder:  (_) => files
                  .map((f) => PopupMenuItem(
                        value: f.id,
                        child: Text(f.name,
                            style: TextStyle(
                                color: T.text,
                                fontSize: 12,
                                fontFamily: 'monospace')),
                      ))
                  .toList(),
              child: Row(children: [
                Expanded(
                  child: Text(
                    file.name,
                    style: TextStyle(
                        color: T.text, fontSize: 11, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.arrow_drop_down, size: 14, color: T.textDim),
              ]),
            ),
          )
        else
          Expanded(
            child: Text(
              file.name,
              style: TextStyle(
                  color: T.text, fontSize: 11, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        // Close split button
        GestureDetector(
          onTap: onClose,
          child: Icon(Icons.close, size: 14, color: T.textDim),
        ),
      ]),
    );
  }
}

/// Adapts CodeEditor for the right split panel without changing activeId.
/// Uses a temporary EditorController facade that swaps the active file.
class _SplitEditorProxy extends StatefulWidget {
  final EditorController ctrl;
  final String fileId;
  final void Function(Offset) onCtx;
  const _SplitEditorProxy({
    required this.ctrl, required this.fileId, required this.onCtx});
  @override
  State<_SplitEditorProxy> createState() => _SplitEditorProxyState();
}

class _SplitEditorProxyState extends State<_SplitEditorProxy> {
  late _SplitProxy _proxy;

  @override
  void initState() {
    super.initState();
    _proxy = _SplitProxy(widget.ctrl, widget.fileId);
    widget.ctrl.addListener(_onCtrlChanged);
  }

  @override
  void didUpdateWidget(_SplitEditorProxy old) {
    super.didUpdateWidget(old);
    if (old.fileId != widget.fileId || old.ctrl != widget.ctrl) {
      widget.ctrl.removeListener(_onCtrlChanged);
      _proxy = _SplitProxy(widget.ctrl, widget.fileId);
      widget.ctrl.addListener(_onCtrlChanged);
    }
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_onCtrlChanged);
    super.dispose();
  }

  void _onCtrlChanged() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) => CodeEditor(
    key: ValueKey('right_${widget.fileId}'),
    ctrl: _proxy,
    onContextMenu: widget.onCtx,
  );
}

/// A thin proxy over EditorController that overrides activeId-based accessors
/// to point to [splitFileId] instead of the primary active file.
/// All other operations (undo, find, settings) delegate to the real controller.
class _SplitProxy extends EditorController {
  final EditorController _real;
  final String _splitId;

  _SplitProxy(this._real, this._splitId);

  // ── Delegate everything to _real ──────────────────────────────────────────
  @override String              get activeId     => _splitId;
  @override TextEditingController get activeCtrl => _real.ctrlFor(_splitId);
  @override ScrollController    get activeScroll => _real.scrollFor(_splitId);
  @override FocusNode           get activeFocus  => _real.focusFor(_splitId);
  @override CodeFile            get activeFile   =>
      _real.files.firstWhere((f) => f.id == _splitId, orElse: () => _real.activeFile);

  @override EditorSettings get settings  => _real.settings;
  @override List<CodeFile> get files     => _real.files;
  @override FoldingManager get folding   => activeFile.folding;
  @override bool get hasExtraCursors     => false; // no multi-cursor in split
  @override List<int> get extraCursorOffsets => [];
  @override ({int open, int close, bool matched})? get bracketMatch => _real.bracketMatch;
  @override double get quickKeysHeight   => _real.quickKeysHeight;
  @override Offset get acCursorOffset    => _real.acCursorOffset;
  @override bool get splitMode          => false; // no nested splits

  // Forward ctrlFor/scrollFor/focusFor to real controller
  @override TextEditingController ctrlFor(String id)   => _real.ctrlFor(id);
  @override ScrollController      scrollFor(String id) => _real.scrollFor(id);
  @override FocusNode             focusFor(String id)  => _real.focusFor(id);

  // Mutations that write back to _real
  @override set acCursorOffset(Offset v) { _real.acCursorOffset = v; }
  @override set quickKeysHeight(double v){ _real.quickKeysHeight = v; }
  @override void updateBracketMatchAt(int cursor) =>
      _real.updateBracketMatchAt(cursor);
  @override void notifyListeners() => _real.notifyListeners();
  @override void addListener(VoidCallback l)    => _real.addListener(l);
  @override void removeListener(VoidCallback l) => _real.removeListener(l);

  // No-op overrides to prevent double-firing
  @override void dispose() {}
}
