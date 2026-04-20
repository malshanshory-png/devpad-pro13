// lib/widgets/context_menu.dart
import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../services/editor_controller.dart';

class ContextMenu extends StatelessWidget {
  final Offset position;
  final EditorController ctrl;
  final VoidCallback onDismiss;
  const ContextMenu({
    super.key,
    required this.position,
    required this.ctrl,
    required this.onDismiss,
  });

  static const _items = [
    _MI('📋', 'Copy',            'copy',   'Ctrl+C'),
    _MI('✂️',  'Cut',             'cut',    'Ctrl+X'),
    _MI('📌', 'Paste',           'paste',  'Ctrl+V'),
    _MI('⬛', 'Select All',      'selAll', 'Ctrl+A'),
    _MI.sep(),
    _MI('💬', 'Toggle Comment',  'cmt',    'Ctrl+/'),
    _MI('⧉',  'Duplicate Line',  'dup',    'Ctrl+D'),
    _MI('🗑',  'Delete Line',    'del',    ''),
    _MI.sep(),
    _MI('↑',  'Move Line Up',    'mvup',   ''),
    _MI('↓',  'Move Line Down',  'mvdn',   ''),
    _MI.sep(),
    _MI('✨', 'Format Code',     'fmt',    ''),
    _MI('→',  'Indent',          'indin',  ''),
    _MI('←',  'Unindent',        'indout', ''),
    _MI.sep(),
    _MI('↩',  'Undo',            'undo',   'Ctrl+Z'),
    _MI('↪',  'Redo',            'redo',   'Ctrl+Y'),
    _MI.sep(),
    _MI('💾', 'Save / Copy',     'save',   'Ctrl+S'),
    _MI('📤', 'Export to Device','export', ''),
    _MI('▶',  'Run',             'run',    'Ctrl+↩'),
  ];

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    const menuW  = 210.0;
    const menuH  = 430.0;
    final left   = (position.dx + menuW > screen.width)  ? screen.width  - menuW - 8 : position.dx;
    final top    = (position.dy + menuH > screen.height) ? screen.height - menuH - 8 : position.dy;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onDismiss,
      child: SizedBox.expand(
        child: Stack(children: [
          Positioned(
            left: left, top: top,
            child: GestureDetector(
              onTap: () {}, // absorb taps so they don't reach the dismiss handler
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: menuW,
                  decoration: BoxDecoration(
                    color: T.surface3,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: T.border2),
                    boxShadow: const [
                      BoxShadow(color: Color(0x80000000), blurRadius: 24, offset: Offset(0, 8)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _items.map((mi) {
                        if (mi.sep) {
                          return Container(
                            height: 1,
                            color: T.border,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                          );
                        }
                        return _CtxItem(mi, () { onDismiss(); _handle(mi.action); });
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  void _handle(String action) {
    switch (action) {
      case 'copy':   ctrl.copySelection(); break;
      case 'cut':    ctrl.cutSelection(); break;
      case 'paste':  ctrl.pasteClipboard(); break;
      case 'selAll': ctrl.selectAll(); break;
      case 'cmt':    ctrl.commentLine(); break;
      case 'dup':    ctrl.duplicateLine(); break;
      case 'del':    ctrl.deleteLine(); break;
      case 'mvup':   ctrl.moveLine(-1); break;
      case 'mvdn':   ctrl.moveLine(1); break;
      case 'fmt':    ctrl.formatCode(); break;
      case 'indin':  ctrl.indentLine(1); break;
      case 'indout': ctrl.indentLine(-1); break;
      case 'undo':   ctrl.undo(); break;
      case 'redo':   ctrl.redo(); break;
      case 'save':   ctrl.saveCurrentFile(copyToClipboard: true); break;
      case 'export': ctrl.exportCurrentFile(); break;
      case 'run':    ctrl.runCode(); break;
    }
  }
}

class _MI {
  final String icon, label, action, shortcut;
  final bool sep;
  const _MI(this.icon, this.label, this.action, this.shortcut) : sep = false;
  const _MI.sep() : icon = '', label = '', action = '', shortcut = '', sep = true;
}

class _CtxItem extends StatefulWidget {
  final _MI mi;
  final VoidCallback onTap;
  const _CtxItem(this.mi, this.onTap);
  @override
  State<_CtxItem> createState() => _CtxItemState();
}

class _CtxItemState extends State<_CtxItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap:       widget.onTap,
    onTapDown:   (_) => setState(() => _pressed = true),
    onTapUp:     (_) => setState(() => _pressed = false),
    onTapCancel: () => setState(() => _pressed = false),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      color: _pressed ? T.accentDim : Colors.transparent,
      child: Row(children: [
        SizedBox(width: 20, child: Text(widget.mi.icon, style: const TextStyle(fontSize: 13))),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.mi.label,
            style: TextStyle(color: T.textMid, fontSize: 12.5),
          ),
        ),
        if (widget.mi.shortcut.isNotEmpty)
          Text(
            widget.mi.shortcut,
            style: TextStyle(color: T.textDim, fontSize: 10),
          ),
      ]),
    ),
  );
}
